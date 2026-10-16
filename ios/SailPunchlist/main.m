// SPDX-License-Identifier: BSD-3-Clause
#import <UIKit/UIKit.h>
#import "SailStore.h"

static NSString *Title(NSString *phase) { return [phase isEqual:@"pre"] ? @"Pre-Sail" : @"Post-Sail"; }

// Drag the dial directly; VoiceOver adjusts the same control.
@interface FuelGauge : UIControl
@property(nonatomic) CGFloat value;
@end
@implementation FuelGauge
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitAdjustable;
        self.accessibilityLabel = @"Fuel level"; self.accessibilityHint = @"Drag around the dial to set fuel from 0 to 100 percent.";
    }
    return self;
}
- (void)setValue:(CGFloat)value {
    _value = value < 0 || !isfinite(value) ? -1 : round(MIN(100,value));
    self.accessibilityValue = _value < 0 ? @"Not set" : [NSString stringWithFormat:@"%.0f percent",_value];
    [self setNeedsDisplay];
}
- (void)adjustTo:(CGFloat)value {
    CGFloat next = round(MAX(0,MIN(100,value)));
    if (self.value == next) return;
    self.value = next;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)accessibilityIncrement { [self adjustTo:self.value < 0 ? 0 : self.value+1]; }
- (void)accessibilityDecrement { [self adjustTo:self.value < 0 ? 0 : self.value-1]; }
- (void)moveToTouch:(UITouch *)touch {
    CGPoint point = [touch locationInView:self];
    CGFloat dx = point.x-CGRectGetMidX(self.bounds), dy = self.bounds.size.height-32-point.y;
    if (hypot(dx,dy) < 12) return;
    CGFloat angle = atan2(MAX(0,dy),dx);
    [self adjustTo:(1-angle/M_PI)*100];
}
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint point = [touch locationInView:self];
    CGFloat centerY = self.bounds.size.height-32;
    CGFloat radius = MIN(self.bounds.size.width/2-24,centerY-18);
    if (point.y > centerY+20 || hypot(point.x-CGRectGetMidX(self.bounds),point.y-centerY) > radius+24) return NO;
    [self moveToTouch:touch]; return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { [self moveToTouch:touch]; return YES; }
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { if (touch) [self moveToTouch:touch]; }
- (void)drawRect:(CGRect)rect {
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), self.bounds.size.height - 32);
    CGFloat radius = MIN(self.bounds.size.width / 2 - 24, center.y - 18);
    UIBezierPath *track = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:M_PI endAngle:2*M_PI clockwise:YES];
    track.lineWidth = 12; track.lineCapStyle = kCGLineCapRound;
    [UIColor.systemGray4Color setStroke]; [track stroke];
    if (self.value >= 0) {
        CGFloat angle = M_PI + self.value / 100 * M_PI;
        UIBezierPath *level = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:M_PI endAngle:angle clockwise:YES];
        level.lineWidth = 12; level.lineCapStyle = kCGLineCapRound;
        [(self.value < 20 ? UIColor.systemRedColor : UIColor.systemGreenColor) setStroke]; [level stroke];
        UIBezierPath *needle = [UIBezierPath bezierPath]; [needle moveToPoint:center];
        [needle addLineToPoint:CGPointMake(center.x + (radius-48)*cos(angle), center.y + (radius-48)*sin(angle))];
        needle.lineWidth = 3; [UIColor.labelColor setStroke]; [needle stroke];
        [UIColor.labelColor setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x-5,center.y-5,10,10)] fill];
    }
    for (NSInteger percent=0; percent<=100; percent+=25) {
        CGFloat angle = M_PI + percent / 100.0 * M_PI;
        NSString *text = [NSString stringWithFormat:@"%ld%%",(long)percent];
        NSDictionary *attributes = @{NSFontAttributeName:[UIFont systemFontOfSize:12], NSForegroundColorAttributeName:UIColor.labelColor};
        CGSize size = [text sizeWithAttributes:attributes];
        CGPoint point = CGPointMake(center.x+(radius-28)*cos(angle)-size.width/2,center.y+(radius-28)*sin(angle)-size.height/2);
        [text drawAtPoint:point withAttributes:attributes];
    }
    NSString *reading = self.value < 0 ? @"Select fuel level" : [NSString stringWithFormat:@"%.0f%%",self.value];
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName:UIColor.labelColor};
    CGSize size = [reading sizeWithAttributes:attributes];
    [reading drawAtPoint:CGPointMake(center.x-size.width/2,center.y+10) withAttributes:attributes];
}
@end

@interface GaugeScrollView : UIScrollView
@end
@implementation GaugeScrollView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    return [view isKindOfClass:FuelGauge.class] ? NO : [super touchesShouldCancelInContentView:view];
}
@end

@interface SailController : UIViewController
@property SailStore *store;
@property UIStackView *content;
@property UIScrollView *scroll;
@property UILabel *status;
@property UISegmentedControl *navigation;
@property FuelGauge *fuelGauge;
@end

@implementation SailController
- (UILabel *)label:(NSString *)text heading:(BOOL)heading {
    UILabel *label = [UILabel new]; label.text = text; label.numberOfLines = 0;
    label.font = [UIFont preferredFontForTextStyle:heading ? UIFontTextStyleHeadline : UIFontTextStyleBody];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    b.titleLabel.adjustsFontForContentSizeCategory = YES;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [b.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Sail Punchlist";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.view.tintColor = [UIColor colorWithRed:0.07 green:0.4 blue:0.34 alpha:1];
    self.navigation = [[UISegmentedControl alloc] initWithItems:@[@"Checklist",@"History"]];
    self.navigation.selectedSegmentIndex = 0;
    [self.navigation addTarget:self action:@selector(render) forControlEvents:UIControlEventValueChanged];
    self.status = [self label:@"Saved on device" heading:NO];
    self.status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.status.accessibilityTraits |= UIAccessibilityTraitUpdatesFrequently;
    UIStackView *layout = [[UIStackView alloc] initWithArrangedSubviews:@[self.navigation,self.status]];
    layout.axis = UILayoutConstraintAxisVertical; layout.spacing = 8;
    layout.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:layout];
    self.scroll = [GaugeScrollView new]; self.scroll.delaysContentTouches = NO; self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scroll];
    self.content = [UIStackView new]; self.content.axis = UILayoutConstraintAxisVertical; self.content.spacing = 16;
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.content];
    [NSLayoutConstraint activateConstraints:@[
        [layout.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [layout.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [layout.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [self.scroll.topAnchor constraintEqualToAnchor:layout.bottomAnchor constant:8],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [self.content.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:16],
        [self.content.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [self.content.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:20],
        [self.content.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [self.content.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    NSError *error = nil;
    NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    self.store = [[SailStore alloc] initWithDirectory:directory checklist:[NSBundle.mainBundle URLForResource:@"checklists" withExtension:@"json"] error:&error];
    if (!self.store) { self.status.text = error.localizedDescription; self.navigation.enabled = NO; return; }
    [self render];
}
- (void)persist {
    NSError *error = nil;
    self.status.text = [self.store save:&error] ? @"Saved on device" : [@"Save failed: " stringByAppendingString:error.localizedDescription];
    if (error) self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Retry save" style:UIBarButtonItemStylePlain target:self action:@selector(persist)];
    else self.navigationItem.rightBarButtonItem = nil;
}
- (UITextField *)field:(NSString *)key value:(NSString *)value placeholder:(NSString *)placeholder {
    UITextField *f = [UITextField new]; f.borderStyle = UITextBorderStyleRoundedRect;
    f.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; f.adjustsFontForContentSizeCategory = YES;
    f.text = value; f.placeholder = placeholder; f.accessibilityLabel = placeholder; f.accessibilityIdentifier = key;
    f.keyboardType = [key hasPrefix:@"note:"] ? UIKeyboardTypeDefault : UIKeyboardTypeDecimalPad;
    [f addTarget:self action:@selector(edit:) forControlEvents:UIControlEventEditingChanged];
    UIToolbar *toolbar = [UIToolbar new]; [toolbar sizeToFit];
    toolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)]];
    f.inputAccessoryView = toolbar;
    [f.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return f;
}
- (void)dismissKeyboard { [self.view endEditing:YES]; }
- (void)edit:(UITextField *)field {
    NSString *key = field.accessibilityIdentifier;
    if ([key hasPrefix:@"note:"]) self.store.draft[@"answers"][[key substringFromIndex:5]][@"note"] = field.text;
    else self.store.draft[key] = field.text;
    [self persist];
}
- (void)colorResponse:(UIStackView *)choices {
    for (UIButton *button in choices.arrangedSubviews) {
        UIColor *color = button.tag == 0 ? [UIColor colorWithRed:0.07 green:0.4 blue:0.34 alpha:1] : [UIColor colorWithRed:0.7 green:0.12 blue:0.12 alpha:1];
        UIButtonConfiguration *style = [UIButtonConfiguration filledButtonConfiguration];
        style.title = button.tag == 0 ? @"✓ Done" : @"✕ Issue";
        style.baseForegroundColor = button.selected ? UIColor.whiteColor : color;
        style.baseBackgroundColor = button.selected ? color : [color colorWithAlphaComponent:0.12];
        button.configuration = style;
    }
}
- (void)fuelChanged:(FuelGauge *)gauge {
    self.store.draft[@"fuel"] = [NSString stringWithFormat:@"%.0f",gauge.value];
    [self persist];
}
- (void)answer:(UIButton *)control {
    NSString *key = control.accessibilityIdentifier;
    NSMutableDictionary *answers = self.store.draft[@"answers"];
    NSString *note = answers[key][@"note"] ?: @"";
    answers[key] = [@{@"status":control.tag == 0 ? @"done" : @"issue", @"note":note} mutableCopy];
    UIStackView *choices = (UIStackView *)control.superview;
    for (UIButton *button in choices.arrangedSubviews) button.selected = button == control;
    UIView *noteField = [(UIStackView *)choices.superview arrangedSubviews].lastObject;
    noteField.hidden = control.tag != 1;
    [self colorResponse:choices];
    [self persist];
}
- (void)phase:(UISegmentedControl *)control {
    [self dismissKeyboard];
    self.store.state[@"phase"] = control.selectedSegmentIndex == 0 ? @"pre" : @"post";
    [self persist]; [self render];
}
- (void)render {
    [self dismissKeyboard];
    for (UIView *v in self.content.arrangedSubviews) { [self.content removeArrangedSubview:v]; [v removeFromSuperview]; }
    [self.scroll setContentOffset:CGPointZero animated:NO];
    if (self.navigation.selectedSegmentIndex == 1) { [self history]; return; }
    NSString *phase = self.store.state[@"phase"];
    UISegmentedControl *phases = [[UISegmentedControl alloc] initWithItems:@[@"Pre-Sail",@"Post-Sail"]];
    phases.selectedSegmentIndex = [phase isEqual:@"pre"] ? 0 : 1;
    phases.selectedSegmentTintColor = self.view.tintColor;
    [phases setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor} forState:UIControlStateSelected];
    [phases setTitleTextAttributes:@{NSForegroundColorAttributeName:self.view.tintColor} forState:UIControlStateNormal];
    [phases addTarget:self action:@selector(phase:) forControlEvents:UIControlEventValueChanged];
    [self.content addArrangedSubview:phases];
    for (NSDictionary *group in self.store.lists[phase]) {
        [self.content addArrangedSubview:[self label:group[@"title"] heading:YES]];
        for (NSDictionary *item in group[@"items"]) {
            NSDictionary *answer = self.store.draft[@"answers"][item[@"id"]];
            UIStackView *response = [UIStackView new]; response.spacing = 12; response.distribution = UIStackViewDistributionFillEqually;
            for (NSInteger index=0; index<2; index++) {
                UIButton *choice = [self button:index == 0 ? @"✓ Done" : @"✕ Issue" action:@selector(answer:)];
                choice.tag = index; choice.accessibilityIdentifier = item[@"id"];
                choice.accessibilityLabel = [NSString stringWithFormat:@"%@: %@",index == 0 ? @"Done" : @"Issue",item[@"label"]];
                choice.selected = [answer[@"status"] isEqual:index == 0 ? @"done" : @"issue"];
                [response addArrangedSubview:choice];
            }
            [self colorResponse:response];
            UITextField *note = [self field:[@"note:" stringByAppendingString:item[@"id"]] value:answer[@"note"] ?: @"" placeholder:@"Issue note (optional)"];
            note.hidden = ![answer[@"status"] isEqual:@"issue"];
            UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[[self label:item[@"label"] heading:NO],response,note]];
            row.axis = UILayoutConstraintAxisVertical; row.spacing = 8;
            row.layoutMargins = UIEdgeInsetsMake(14,14,14,14); row.layoutMarginsRelativeArrangement = YES;
            row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; row.layer.cornerRadius = 12;
            [self.content addArrangedSubview:row];
        }
    }
    [self.content addArrangedSubview:[self label:@"Fuel and engine" heading:YES]];
    [self.content addArrangedSubview:[self label:@"Fuel level (0–100%)" heading:NO]];
    self.fuelGauge = [FuelGauge new]; self.fuelGauge.backgroundColor = UIColor.clearColor;
    self.fuelGauge.value = [self.store.draft[@"fuel"] length] ? [self.store.draft[@"fuel"] doubleValue] : -1;
    [self.fuelGauge.heightAnchor constraintEqualToConstant:210].active = YES;
    [self.content addArrangedSubview:self.fuelGauge];
    [self.fuelGauge addTarget:self action:@selector(fuelChanged:) forControlEvents:UIControlEventValueChanged];
    [self.content addArrangedSubview:[self label:@"Drag the fuel dial to set the level." heading:NO]];
    [self.content addArrangedSubview:[self field:@"hours" value:self.store.draft[@"hours"] placeholder:@"Engine hours"]];
    if (self.store.state[@"lastHours"] != NSNull.null)
        [self.content addArrangedSubview:[self label:[NSString stringWithFormat:@"Last engine reading: %@ hrs", self.store.state[@"lastHours"]] heading:NO]];
    [self.content addArrangedSubview:[self button:[@"Complete " stringByAppendingString:Title(phase)] action:@selector(finish)]];
}
- (void)finish {
    [self dismissKeyboard]; NSError *error = nil;
    if ([self.store complete:&error]) { [self render]; self.status.text = @"Checklist completed and saved."; }
    else { self.status.text = error.localizedDescription; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,self.status.text); }
}
- (void)history {
    [self.content addArrangedSubview:[self label:@"Sail history" heading:YES]];
    [self.content addArrangedSubview:[self button:@"Export JSON" action:@selector(export)]];
    [self.content addArrangedSubview:[self button:@"Export CSV" action:@selector(exportCSV)]];
    NSArray *records = self.store.state[@"records"];
    if (!records.count) [self.content addArrangedSubview:[self label:@"No completed checklists yet." heading:NO]];
    NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
    NSDateFormatter *local = [NSDateFormatter new]; local.dateStyle = NSDateFormatterMediumStyle; local.timeStyle = NSDateFormatterShortStyle;
    for (NSDictionary *r in records.reverseObjectEnumerator) {
        NSDate *date = [iso dateFromString:r[@"date"]];
        NSMutableString *text = [NSMutableString stringWithFormat:@"%@ · %@\n%@%% fuel · %@ engine hrs",Title(r[@"phase"]),date ? [local stringFromDate:date] : r[@"date"],r[@"fuel"],r[@"hours"]];
        BOOL issues = NO;
        for (NSDictionary *item in r[@"items"]) if ([item[@"status"] isEqual:@"issue"]) {
            issues = YES; [text appendFormat:@"\n\n✕ %@\n%@",item[@"label"],[item[@"note"] length] ? item[@"note"] : @"No comment."];
        }
        if (!issues) [text appendString:@"\n✓ No issues recorded"];
        [self.content addArrangedSubview:[self label:text heading:NO]];
    }
}
- (void)export {
    NSError *error = nil;
    if (![self.store save:&error]) { self.status.text = error.localizedDescription; return; }
    [self shareFile:self.store.file];
}
- (void)exportCSV {
    NSURL *file = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"sail-history.csv"];
    NSError *error = nil;
    if (![[self.store csv] writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:&error]) { self.status.text = error.localizedDescription; return; }
    [self shareFile:file];
}
- (void)shareFile:(NSURL *)file {
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
    share.popoverPresentationController.sourceView = self.navigation;
    share.popoverPresentationController.sourceRect = self.navigation.bounds;
    [self presentViewController:share animated:YES completion:nil];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[SailController new]];
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class)); }
}
