#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// One Euro filter for a 2D point. Low latency at speed, strong stability at rest.
@interface FNOneEuroFilter : NSObject

- (instancetype)initWithMinCutoff:(double)minCutoff
                             beta:(double)beta
                          dCutoff:(double)dCutoff NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (CGPoint)filterPoint:(CGPoint)point timestamp:(NSTimeInterval)timestamp;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
