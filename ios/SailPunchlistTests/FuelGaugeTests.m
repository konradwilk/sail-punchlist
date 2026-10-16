// SPDX-License-Identifier: BSD-3-Clause
#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

// Exercise the app's real control through UIKit's tracking callbacks.
@interface FuelGauge : UIControl
@property(nonatomic) CGFloat value;
@end
@interface GaugeScrollView : UIScrollView
@end
@interface GaugeTouch : UITouch
@property(nonatomic) CGPoint point;
@end
@implementation GaugeTouch
- (CGPoint)locationInView:(UIView *)view { return self.point; }
@end
@interface GaugeObserver : NSObject
@property(nonatomic) CGFloat lastValue;
@property(nonatomic) NSUInteger changes;
- (void)changed:(FuelGauge *)gauge;
@end
@implementation GaugeObserver
- (void)changed:(FuelGauge *)gauge { self.lastValue = gauge.value; self.changes++; }
@end

@interface FuelGaugeTests : XCTestCase
@end
@implementation FuelGaugeTests
- (void)testDraggingFromZeroToSeventyFiveUpdatesTheDialAndEmitsChanges {
    FuelGauge *gauge = [[NSClassFromString(@"FuelGauge") alloc] initWithFrame:CGRectMake(0,0,360,210)];
    gauge.value = -1;
    GaugeObserver *observer = [GaugeObserver new];
    [gauge addTarget:observer action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    GaugeTouch *touch = [GaugeTouch new];
    touch.point = CGPointMake(24,178); // 0% at the left end of the arc.
    XCTAssertTrue([gauge beginTrackingWithTouch:touch withEvent:nil]);
    XCTAssertEqual(gauge.value,0);
    XCTAssertEqual(observer.lastValue,0);
    XCTAssertEqual(observer.changes,1u);
    touch.point = CGPointMake(290.3,67.7); // 75% on the upper-right arc.
    XCTAssertTrue([gauge continueTrackingWithTouch:touch withEvent:nil]);
    XCTAssertEqual(gauge.value,75);
    XCTAssertEqual(observer.lastValue,75);
    XCTAssertEqualObjects(gauge.accessibilityValue,@"75 percent");
    touch.point = CGPointMake(336,178);
    [gauge endTrackingWithTouch:touch withEvent:nil];
    XCTAssertEqual(gauge.value,100);
    XCTAssertEqual(observer.lastValue,100);
    XCTAssertEqual(observer.changes,3u);
}
- (void)testHorizontalDragAcrossTheDialAndBack {
    FuelGauge *gauge = [[NSClassFromString(@"FuelGauge") alloc] initWithFrame:CGRectMake(0,0,360,210)];
    gauge.value = -1;
    GaugeTouch *touch = [GaugeTouch new]; touch.point = CGPointMake(24,110);
    XCTAssertTrue([gauge beginTrackingWithTouch:touch withEvent:nil]);
    CGFloat start = gauge.value;
    touch.point = CGPointMake(180,110);
    [gauge continueTrackingWithTouch:touch withEvent:nil];
    XCTAssertEqual(gauge.value,50);
    touch.point = CGPointMake(336,110);
    [gauge continueTrackingWithTouch:touch withEvent:nil];
    XCTAssertGreaterThan(gauge.value,75);
    touch.point = CGPointMake(24,110);
    [gauge endTrackingWithTouch:touch withEvent:nil];
    XCTAssertEqual(gauge.value,start);
}
- (void)testPageScrollingDoesNotCancelDialTracking {
    GaugeScrollView *scroll = [[NSClassFromString(@"GaugeScrollView") alloc] initWithFrame:CGRectMake(0,0,360,600)];
    FuelGauge *gauge = [[NSClassFromString(@"FuelGauge") alloc] initWithFrame:CGRectMake(0,0,360,210)];
    XCTAssertFalse([scroll touchesShouldCancelInContentView:gauge]);
    XCTAssertTrue([scroll touchesShouldCancelInContentView:[UIView new]]);
}
- (void)testAChangedReadingChangesTheRenderedGauge {
    FuelGauge *gauge = [[NSClassFromString(@"FuelGauge") alloc] initWithFrame:CGRectMake(0,0,360,210)];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:gauge.bounds.size];
    gauge.value = 0;
    NSData *empty = UIImagePNGRepresentation([renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [gauge drawRect:gauge.bounds]; }]);
    gauge.value = 75;
    NSData *filled = UIImagePNGRepresentation([renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [gauge drawRect:gauge.bounds]; }]);
    XCTAssertNotNil(empty); XCTAssertNotNil(filled);
    XCTAssertNotEqualObjects(empty,filled);
}
@end
