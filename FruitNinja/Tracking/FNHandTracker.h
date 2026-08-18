#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class FNHandTracker, FNHandSample;

@protocol FNHandTrackerDelegate <NSObject>
- (void)handTracker:(FNHandTracker *)tracker didUpdateSample:(FNHandSample *)sample
    NS_SWIFT_NAME(handTracker(_:didUpdate:));
@optional
- (void)handTracker:(FNHandTracker *)tracker didFailWithError:(NSError *)error
    NS_SWIFT_NAME(handTracker(_:didFailWith:));
@end

/// Owns the camera session and the hardware-accelerated Vision hand-pose pipeline.
@interface FNHandTracker : NSObject

@property (nonatomic, weak, nullable) id<FNHandTrackerDelegate> delegate;
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) double lastInferenceMilliseconds;

- (void)startWithCompletion:(void (^ _Nullable)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(start(completion:));
- (void)stop;

@end

NS_ASSUME_NONNULL_END
