#import "FNHandTracker.h"
#import "FNHandSample.h"
#import "FNOneEuroFilter.h"

#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <Vision/Vision.h>
#import <math.h>

static NSString * const FNHandTrackerErrorDomain = @"com.sid.fruitslice.handtracker";

@interface FNHandTracker () <AVCaptureVideoDataOutputSampleBufferDelegate>
@end

@implementation FNHandTracker {
    AVCaptureSession *_session;
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _visionQueue;
    AVCaptureVideoPreviewLayer *_previewLayer;
    VNDetectHumanHandPoseRequest *_handRequest;
    FNOneEuroFilter *_tipFilter;
    FNOneEuroFilter *_middleFilter;
    BOOL _configured;
    BOOL _starting;
    BOOL _running;
    BOOL _hasFilteredPoint;
    CGPoint _lastFilteredTip;
    NSTimeInterval _lastFilteredTime;
    NSTimeInterval _lastPresentTime;
    double _lastInferenceMilliseconds;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _session = [[AVCaptureSession alloc] init];
        _sessionQueue = dispatch_queue_create("com.sid.fruitslice.camera", DISPATCH_QUEUE_SERIAL);
        _visionQueue = dispatch_queue_create("com.sid.fruitslice.vision", DISPATCH_QUEUE_SERIAL);
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _previewLayer.backgroundColor = NSColor.blackColor.CGColor;
        _handRequest = [[VNDetectHumanHandPoseRequest alloc] init];
        _handRequest.maximumHandCount = 1;
        _tipFilter = [[FNOneEuroFilter alloc] initWithMinCutoff:1.15 beta:0.55 dCutoff:1.0];
        _middleFilter = [[FNOneEuroFilter alloc] initWithMinCutoff:1.25 beta:0.45 dCutoff:1.0];
    }
    return self;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    return _previewLayer;
}

- (BOOL)isRunning {
    return _running;
}

- (double)lastInferenceMilliseconds {
    return _lastInferenceMilliseconds;
}

- (NSError *)errorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:FNHandTrackerErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (AVCaptureDevice *)cameraDevice {
    AVCaptureDeviceDiscoverySession *discovery =
        [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
            AVCaptureDeviceTypeBuiltInWideAngleCamera,
            AVCaptureDeviceTypeExternal
        ]
                                                               mediaType:AVMediaTypeVideo
                                                                position:AVCaptureDevicePositionFront];
    AVCaptureDevice *device = discovery.devices.firstObject;
    if (device != nil) {
        return device;
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

- (NSError *)configureSessionIfNeeded {
    if (_configured) {
        return nil;
    }

    AVCaptureDevice *device = [self cameraDevice];
    if (device == nil) {
        return [self errorWithMessage:@"No camera is available. You can still play in Mouse Blade mode."];
    }

    NSError *inputError = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&inputError];
    if (input == nil) {
        return inputError ?: [self errorWithMessage:@"The camera could not be opened."];
    }

    [_session beginConfiguration];
    if ([_session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        _session.sessionPreset = AVCaptureSessionPreset1280x720;
    } else {
        _session.sessionPreset = AVCaptureSessionPresetHigh;
    }

    if ([_session canAddInput:input]) {
        [_session addInput:input];
    } else {
        [_session commitConfiguration];
        return [self errorWithMessage:@"The camera input could not be connected."];
    }

    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    output.alwaysDiscardsLateVideoFrames = YES;
    [output setSampleBufferDelegate:self queue:_visionQueue];
    if ([_session canAddOutput:output]) {
        [_session addOutput:output];
    } else {
        [_session commitConfiguration];
        return [self errorWithMessage:@"The camera video output could not be connected."];
    }
    [_session commitConfiguration];

    _configured = YES;
    return nil;
}

/// The preview layer's connection only exists once the session has an input.
/// Enforce a mirror-image preview so the on-screen player motion matches the
/// mirrored fingertip coordinates used for gameplay.
- (void)applyPreviewMirroring {
    AVCaptureConnection *previewConnection = _previewLayer.connection;
    if (previewConnection == nil || !previewConnection.supportsVideoMirroring) {
        return;
    }
    @try {
        previewConnection.automaticallyAdjustsVideoMirroring = NO;
        previewConnection.videoMirrored = YES;
    } @catch (__unused NSException *exception) {
        // Some macOS camera configurations manage mirroring themselves.
    }
}

- (void)startWithCompletion:(void (^)(NSError * _Nullable))completion {
    void (^finish)(NSError *) = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyPreviewMirroring];
            if (completion) {
                completion(error);
            }
        });
    };

    if (_running) {
        finish(nil);
        return;
    }
    if (_starting) {
        finish([self errorWithMessage:@"The camera is already starting."]);
        return;
    }
    _starting = YES;

    dispatch_async(_sessionQueue, ^{
        NSError *error = [self configureSessionIfNeeded];
        if (error) {
            self->_starting = NO;
            finish(error);
            return;
        }
        if (!self->_session.isRunning) {
            [self->_session startRunning];
        }
        self->_running = self->_session.isRunning;
        self->_starting = NO;
        if (!self->_running) {
            finish([self errorWithMessage:@"The camera did not start. Check Camera permission in System Settings."]);
            return;
        }
        finish(nil);
    });
}

- (void)stop {
    dispatch_async(_sessionQueue, ^{
        if (self->_session.isRunning) {
            [self->_session stopRunning];
        }
        self->_running = NO;
        [self->_tipFilter reset];
        [self->_middleFilter reset];
        self->_hasFilteredPoint = NO;
    });
}

- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        if (!CMSampleBufferDataIsReady(sampleBuffer)) {
            return;
        }
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (pixelBuffer == NULL) {
            return;
        }

        const NSTimeInterval timestamp = CACurrentMediaTime();
        CFTimeInterval start = CACurrentMediaTime();
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc]
            initWithCVPixelBuffer:pixelBuffer
                       orientation:kCGImagePropertyOrientationUp
                           options:@{}];
        NSError *visionError = nil;
        [handler performRequests:@[self->_handRequest] error:&visionError];
        self->_lastInferenceMilliseconds = (CACurrentMediaTime() - start) * 1000.0;

        CGSize videoSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                                      CVPixelBufferGetHeight(pixelBuffer));
        VNHumanHandPoseObservation *observation =
            (VNHumanHandPoseObservation *)self->_handRequest.results.firstObject;

        VNRecognizedPoint *indexTip = nil;
        VNRecognizedPoint *middleTip = nil;
        if (observation != nil) {
            NSError *pointError = nil;
            indexTip = [observation recognizedPointForJointName:VNHumanHandPoseObservationJointNameIndexTip
                                                          error:&pointError];
            middleTip = [observation recognizedPointForJointName:VNHumanHandPoseObservationJointNameMiddleTip
                                                           error:&pointError];
        }

        const BOOL valid = observation != nil &&
            indexTip != nil &&
            indexTip.confidence >= 0.28f;

        if (!valid) {
            FNHandSample *sample = [[FNHandSample alloc]
                initWithPresent:NO
                       indexTip:self->_hasFilteredPoint ? self->_lastFilteredTip : CGPointMake(0.5, 0.5)
                      middleTip:self->_hasFilteredPoint ? self->_lastFilteredTip : CGPointMake(0.5, 0.5)
                       velocity:CGPointZero
                     confidence:0
                      timestamp:timestamp
                      videoSize:videoSize];
            if (timestamp - self->_lastPresentTime > 0.35) {
                [self->_tipFilter reset];
                [self->_middleFilter reset];
                self->_hasFilteredPoint = NO;
            }
            [self deliverSample:sample];
            return;
        }

        CGPoint rawTip = indexTip.location;
        CGPoint smoothedTip = [self->_tipFilter filterPoint:rawTip timestamp:timestamp];

        CGPoint rawMiddle = middleTip != nil ? middleTip.location : rawTip;
        CGPoint smoothedMiddle = [self->_middleFilter filterPoint:rawMiddle timestamp:timestamp];

        CGPoint velocity = CGPointZero;
        if (self->_hasFilteredPoint) {
            double dt = MAX(1.0 / 120.0, timestamp - self->_lastFilteredTime);
            velocity = CGPointMake((smoothedTip.x - self->_lastFilteredTip.x) / dt,
                                   (smoothedTip.y - self->_lastFilteredTip.y) / dt);
            // Avoid wild extrapolation after a detection jump.
            const double magnitude = hypot(velocity.x, velocity.y);
            if (magnitude > 5.0) {
                velocity.x *= 5.0 / magnitude;
                velocity.y *= 5.0 / magnitude;
            }
        }
        self->_lastFilteredTip = smoothedTip;
        self->_lastFilteredTime = timestamp;
        self->_lastPresentTime = timestamp;
        self->_hasFilteredPoint = YES;

        FNHandSample *sample = [[FNHandSample alloc]
            initWithPresent:YES
                   indexTip:smoothedTip
                  middleTip:smoothedMiddle
                   velocity:velocity
                 confidence:indexTip.confidence
                  timestamp:timestamp
                  videoSize:videoSize];
        [self deliverSample:sample];
    }
}

- (void)deliverSample:(FNHandSample *)sample {
    dispatch_async(dispatch_get_main_queue(), ^{
        id<FNHandTrackerDelegate> delegate = self.delegate;
        if (delegate != nil) {
            [delegate handTracker:self didUpdateSample:sample];
        }
    });
}

@end
