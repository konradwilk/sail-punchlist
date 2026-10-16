// SPDX-License-Identifier: BSD-3-Clause
#import "SailStore.h"
#include <math.h>

static BOOL Fail(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"SailPunchlist" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
static NSMutableDictionary *Draft(NSString *hours) {
    return [@{@"answers":[NSMutableDictionary new], @"fuel":@"", @"hours":hours} mutableCopy];
}
static BOOL Number(NSString *text, double *value) {
    if (![text isKindOfClass:NSString.class] || !text.length) return NO;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return [scanner scanDouble:value] && scanner.isAtEnd && isfinite(*value) && *value >= 0;
}
static BOOL Valid(id state) {
    if (![state isKindOfClass:NSDictionary.class] || ![state[@"version"] isEqual:@1] ||
        ![@[@"pre",@"post"] containsObject:state[@"phase"]] || ![state[@"drafts"] isKindOfClass:NSDictionary.class] ||
        ![state[@"records"] isKindOfClass:NSArray.class]) return NO;
    id last = state[@"lastHours"];
    if (last != NSNull.null && (![last isKindOfClass:NSNumber.class] || !isfinite([last doubleValue]) || [last doubleValue] < 0)) return NO;
    for (NSString *phase in @[@"pre",@"post"]) {
        id d = state[@"drafts"][phase];
        if (![d isKindOfClass:NSDictionary.class] || ![d[@"answers"] isKindOfClass:NSDictionary.class] ||
            ![d[@"fuel"] isKindOfClass:NSString.class] || ![d[@"hours"] isKindOfClass:NSString.class]) return NO;
        for (id a in [d[@"answers"] allValues])
            if (![a isKindOfClass:NSDictionary.class] || ![@[@"done",@"issue"] containsObject:a[@"status"]] || ![a[@"note"] isKindOfClass:NSString.class]) return NO;
    }
    for (id r in state[@"records"]) {
        if (![r isKindOfClass:NSDictionary.class] || ![@[@"pre",@"post"] containsObject:r[@"phase"]] ||
            ![r[@"date"] isKindOfClass:NSString.class] || ![r[@"fuel"] isKindOfClass:NSNumber.class] ||
            ![r[@"hours"] isKindOfClass:NSNumber.class] || ![r[@"items"] isKindOfClass:NSArray.class]) return NO;
        for (id item in r[@"items"])
            if (![item isKindOfClass:NSDictionary.class] || ![item[@"label"] isKindOfClass:NSString.class] ||
                ![@[@"done",@"issue"] containsObject:item[@"status"]] || ![item[@"note"] isKindOfClass:NSString.class]) return NO;
    }
    return YES;
}
static NSString *CSVRow(NSArray *values) {
    NSMutableArray *cells = [NSMutableArray new];
    for (id value in values) {
        NSString *escaped = [[value description] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
        [cells addObject:[NSString stringWithFormat:@"\"%@\"",escaped]];
    }
    return [[cells componentsJoinedByString:@","] stringByAppendingString:@"\r\n"];
}
@implementation SailStore
- (instancetype)initWithDirectory:(NSURL *)directory checklist:(NSURL *)checklist error:(NSError **)error {
    if (!(self = [super init])) return nil;
    NSData *content = [NSData dataWithContentsOfURL:checklist options:0 error:error];
    if (!content) return nil;
    _lists = [NSJSONSerialization JSONObjectWithData:content options:0 error:error];
    if (!_lists) return nil;
    _file = [directory URLByAppendingPathComponent:@"native-sail.json"];
    if ([NSFileManager.defaultManager fileExistsAtPath:_file.path]) {
        NSData *data = [NSData dataWithContentsOfURL:_file options:0 error:error];
        if (!data) return nil;
        _state = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error];
        if (!Valid(_state)) { Fail(error,@"Cannot read the saved sail log. The file has not been changed."); return nil; }
    } else {
        _state = [@{@"version":@1, @"phase":@"pre", @"lastHours":NSNull.null,
                    @"drafts":[@{@"pre":Draft(@""), @"post":Draft(@"")} mutableCopy], @"records":[NSMutableArray new]} mutableCopy];
    }
    return self;
}
- (NSMutableDictionary *)draft { return self.state[@"drafts"][self.state[@"phase"]]; }
- (BOOL)save:(NSError **)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.state options:NSJSONWritingPrettyPrinted error:error];
    return data && [data writeToURL:self.file options:NSDataWritingAtomic error:error];
}
- (NSString *)csv {
    NSMutableString *csv = [CSVRow(@[@"CompletedAt",@"Phase",@"FuelPercent",@"EngineHours",@"Item",@"Status",@"Note"]) mutableCopy];
    for (NSDictionary *record in self.state[@"records"]) for (NSDictionary *item in record[@"items"]) {
        [csv appendString:CSVRow(@[record[@"date"], [record[@"phase"] isEqual:@"pre"] ? @"Pre-Sail" : @"Post-Sail",
                                  record[@"fuel"],record[@"hours"],item[@"label"],item[@"status"],item[@"note"]])];
    }
    return csv;
}
- (BOOL)complete:(NSError **)error {
    NSString *phase = self.state[@"phase"];
    NSMutableDictionary *draft = self.draft;
    NSMutableArray *items = [NSMutableArray new];
    for (NSDictionary *group in self.lists[phase]) for (NSDictionary *item in group[@"items"]) {
        NSDictionary *a = draft[@"answers"][item[@"id"]];
        if (![@[@"done",@"issue"] containsObject:a[@"status"]]) return Fail(error,@"Mark every item Done or Issue.");
        [items addObject:@{@"label":item[@"label"], @"status":a[@"status"], @"note":[a[@"status"] isEqual:@"issue"] ? a[@"note"] : @""}];
    }
    double fuel, hours;
    if (!Number(draft[@"fuel"], &fuel) || fuel > 100) return Fail(error,@"Enter fuel from 0 to 100 percent.");
    if (!Number(draft[@"hours"], &hours)) return Fail(error,@"Enter valid engine hours.");
    if (self.state[@"lastHours"] != NSNull.null && hours < [self.state[@"lastHours"] doubleValue])
        return Fail(error,@"Engine hours cannot be below the last recorded reading.");
    // Roll back the completion if persistence fails, so Retry cannot duplicate it.
    NSData *previous = [NSJSONSerialization dataWithJSONObject:self.state options:0 error:error];
    if (!previous) return NO;
    NSString *date = [[NSISO8601DateFormatter new] stringFromDate:NSDate.date];
    [self.state[@"records"] addObject:@{@"phase":phase, @"date":date, @"fuel":@(fuel), @"hours":@(hours), @"items":items}];
    id last = self.state[@"lastHours"];
    NSString *previousSuggestion = last == NSNull.null ? @"" : [@([last doubleValue] + 1) stringValue];
    self.state[@"lastHours"] = @(hours);
    self.state[@"drafts"][phase] = Draft([@(hours + 1) stringValue]);
    NSString *next = [phase isEqual:@"pre"] ? @"post" : @"pre";
    if (![self.state[@"drafts"][next][@"hours"] length] || [self.state[@"drafts"][next][@"hours"] isEqual:previousSuggestion]) self.state[@"drafts"][next][@"hours"] = [@(hours + 1) stringValue];
    self.state[@"phase"] = next;
    if ([self save:error]) return YES;
    _state = [NSJSONSerialization JSONObjectWithData:previous options:NSJSONReadingMutableContainers error:NULL];
    return NO;
}
@end
