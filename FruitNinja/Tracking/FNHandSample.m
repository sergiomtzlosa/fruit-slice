#import "FNHandSample.h"

@implementation FNHandSample

- (instancetype)initWithPresent:(BOOL)present
                       indexTip:(CGPoint)indexTip
                      middleTip:(CGPoint)middleTip
                       velocity:(CGPoint)velocity
                     confidence:(float)confidence
                      timestamp:(NSTimeInterval)timestamp
                      videoSize:(CGSize)videoSize {
    self = [super init];
    if (self) {
        _present = present;
        _indexTip = indexTip;
        _middleTip = middleTip;
        _velocity = velocity;
        _confidence = confidence;
        _timestamp = timestamp;
        _videoSize = videoSize;
    }
    return self;
}

@end
