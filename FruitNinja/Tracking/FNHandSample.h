#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// A lightweight frame of hand data passed from Objective-C into Swift.
@interface FNHandSample : NSObject

@property (nonatomic, readonly) BOOL present;
/// Normalized Vision coordinates (origin bottom-left, unmirrored).
@property (nonatomic, readonly) CGPoint indexTip;
@property (nonatomic, readonly) CGPoint middleTip;
/// Normalized units per second.
@property (nonatomic, readonly) CGPoint velocity;
@property (nonatomic, readonly) float confidence;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) CGSize videoSize;

- (instancetype)initWithPresent:(BOOL)present
                       indexTip:(CGPoint)indexTip
                      middleTip:(CGPoint)middleTip
                       velocity:(CGPoint)velocity
                     confidence:(float)confidence
                      timestamp:(NSTimeInterval)timestamp
                      videoSize:(CGSize)videoSize NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
