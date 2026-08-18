#import "FNOneEuroFilter.h"
#import <math.h>

@implementation FNOneEuroFilter {
    double _minCutoff;
    double _beta;
    double _dCutoff;
    BOOL _hasLast;
    NSTimeInterval _lastTime;
    CGPoint _lastRaw;
    CGPoint _filtered;
    CGPoint _filteredDerivative;
}

- (instancetype)initWithMinCutoff:(double)minCutoff beta:(double)beta dCutoff:(double)dCutoff {
    self = [super init];
    if (self) {
        _minCutoff = minCutoff;
        _beta = beta;
        _dCutoff = dCutoff;
    }
    return self;
}

static double FNAllphaForCutoff(double cutoff, double dt) {
    if (cutoff <= 0.0 || dt <= 0.0) {
        return 1.0;
    }
    const double tau = 1.0 / (2.0 * M_PI * cutoff);
    return 1.0 / (1.0 + tau / dt);
}

- (void)reset {
    _hasLast = NO;
    _lastTime = 0;
    _lastRaw = CGPointZero;
    _filtered = CGPointZero;
    _filteredDerivative = CGPointZero;
}

- (CGPoint)filterPoint:(CGPoint)point timestamp:(NSTimeInterval)timestamp {
    if (!_hasLast) {
        _hasLast = YES;
        _lastTime = timestamp;
        _lastRaw = point;
        _filtered = point;
        _filteredDerivative = CGPointZero;
        return point;
    }

    double dt = timestamp - _lastTime;
    if (!isfinite(dt) || dt <= 0.0) {
        dt = 1.0 / 60.0;
    }
    // A long gap means the hand disappeared or the app was interrupted.
    if (dt > 0.35) {
        [self reset];
        return [self filterPoint:point timestamp:timestamp];
    }
    dt = MIN(MAX(dt, 1.0 / 240.0), 0.1);

    const double dx = (point.x - _lastRaw.x) / dt;
    const double dy = (point.y - _lastRaw.y) / dt;
    const double dAlpha = FNAllphaForCutoff(_dCutoff, dt);
    _filteredDerivative.x += dAlpha * (dx - _filteredDerivative.x);
    _filteredDerivative.y += dAlpha * (dy - _filteredDerivative.y);

    const double speed = hypot(_filteredDerivative.x, _filteredDerivative.y);
    const double cutoff = _minCutoff + _beta * speed;
    const double alpha = FNAllphaForCutoff(cutoff, dt);

    _filtered.x += alpha * (point.x - _filtered.x);
    _filtered.y += alpha * (point.y - _filtered.y);
    _lastRaw = point;
    _lastTime = timestamp;

    return _filtered;
}

@end
