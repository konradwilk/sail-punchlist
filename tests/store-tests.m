// SPDX-License-Identifier: BSD-3-Clause
#import <Foundation/Foundation.h>
#import "SailStore.h"
#define CHECK(condition) do { if (!(condition)) { NSLog(@"Failed at line %d: %s", __LINE__, #condition); return 1; } } while (0)
static void AnswerAll(SailStore *store) {
    for (NSDictionary *group in store.lists[store.state[@"phase"]]) for (NSDictionary *item in group[@"items"])
        store.draft[@"answers"][item[@"id"]] = [@{@"status":@"done", @"note":@""} mutableCopy];
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        CHECK([NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSURL *checklist = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSError *error = nil;
        SailStore *store = [[SailStore alloc] initWithDirectory:directory checklist:checklist error:&error];
        CHECK(store && !error && [store.state[@"phase"] isEqual:@"pre"]);
        CHECK([store.draft[@"fuel"] isEqual:@"50"]);
        CHECK([store.state[@"drafts"][@"post"][@"fuel"] isEqual:@"50"]);
        store.draft[@"fuel"] = @"72"; store.draft[@"hours"] = @"11.25";
        CHECK([store save:&error]);
        SailStore *sticky = [[SailStore alloc] initWithDirectory:directory checklist:checklist error:&error];
        CHECK([sticky.draft[@"hours"] isEqual:@"11.25"]);
        CHECK([sticky.draft[@"fuel"] isEqual:@"72"]); // Reopening does not decrement a draft.
        CHECK([[store csv] componentsSeparatedByString:@"\r\n"].count == 2); // Empty history exports a header.
        CHECK(![store complete:&error]); // Unreviewed items cannot be completed.
        AnswerAll(store);
        store.draft[@"fuel"] = @"";
        CHECK(![store complete:&error]); // Invalid empty readings are still refused.
        store.draft[@"fuel"] = @"101"; store.draft[@"hours"] = @"12.5";
        CHECK(![store complete:&error]);
        store.draft[@"fuel"] = @"0"; store.draft[@"hours"] = @"12x";
        CHECK(![store complete:&error]);
        store.draft[@"hours"] = @"NaN"; CHECK(![store complete:&error]);
        store.draft[@"hours"] = @"12.5";
        store.draft[@"answers"][@"pre-0"] = [@{@"status":@"issue",@"note":@"Need water"} mutableCopy];
        store.draft[@"answers"][@"pre-1"] = [@{@"status":@"issue",@"note":@"Fuel, \"reserve\"\nCheck again"} mutableCopy];
        store.state[@"drafts"][@"post"][@"hours"] = @"20";
        CHECK([store save:&error]);
        SailStore *reloaded = [[SailStore alloc] initWithDirectory:directory checklist:checklist error:&error];
        CHECK([reloaded.draft[@"answers"][@"pre-0"][@"note"] isEqual:@"Need water"]);
        CHECK([store complete:&error]); // Issues do not block completion.
        CHECK([store.state[@"phase"] isEqual:@"post"]);
        CHECK([store.draft[@"fuel"] isEqual:@"0"]); // Fuel stays at zero instead of becoming negative.
        CHECK([store.draft[@"hours"] doubleValue] == 13.5); // New checklist starts at last completed reading + 1.
        CHECK([store.state[@"records"] count] == 1);
        NSDictionary *record = store.state[@"records"][0];
        CHECK([record[@"fuel"] isEqual:@0] && [record[@"hours"] isEqual:@12.5]);
        CHECK([record[@"items"][0][@"note"] isEqual:@"Need water"]);
        CHECK([record[@"items"] count] == 23);
        NSString *csv = [store csv];
        CHECK([csv containsString:@"\"CompletedAt\",\"Phase\",\"FuelPercent\",\"EngineHours\",\"Item\",\"Status\",\"Note\"\r\n"]);
        CHECK([csv containsString:@"\"Fuel, \"\"reserve\"\"\nCheck again\""]);
        CHECK([csv containsString:@"\"Pre-Sail\",\"0\",\"12.5\""]);
        CHECK([csv componentsSeparatedByString:@"\r\n"].count == 25); // One row for each completed item, no draft rows.
        AnswerAll(store); store.draft[@"fuel"] = @"50"; store.draft[@"hours"] = @"12";
        CHECK(![store complete:&error]); // The engine cannot go backwards.
        store.draft[@"hours"] = @"13.75";
        CHECK([store complete:&error]);
        CHECK([store.state[@"records"] count] == 2 && [store.draft[@"hours"] isEqual:@"14.75"]);
        reloaded = [[SailStore alloc] initWithDirectory:directory checklist:checklist error:&error];
        CHECK([reloaded.state[@"records"] count] == 2);
        CHECK([reloaded.draft[@"fuel"] doubleValue] == 49); // 50% completed means a 49% next default.
        AnswerAll(store); store.draft[@"fuel"] = @"75"; store.draft[@"hours"] = @"15";
        // A path occupied by a directory forces an actual disk write error.
        CHECK([NSFileManager.defaultManager removeItemAtURL:store.file error:NULL]);
        CHECK([NSFileManager.defaultManager createDirectoryAtURL:store.file withIntermediateDirectories:NO attributes:nil error:NULL]);
        CHECK(![store complete:&error]);
        CHECK([store.state[@"records"] count] == 2 && [store.state[@"phase"] isEqual:@"pre"]);
        CHECK([NSFileManager.defaultManager removeItemAtURL:store.file error:NULL]);
        CHECK([store complete:&error]);
        CHECK([store.state[@"records"] count] == 3);
        CHECK([store.draft[@"fuel"] doubleValue] == 74); // 75% completed means a 74% next default.
        sticky = [[SailStore alloc] initWithDirectory:directory checklist:checklist error:&error];
        CHECK([sticky.draft[@"hours"] doubleValue] == 16); // Last engine reading was 15.
        CHECK([sticky.draft[@"fuel"] doubleValue] == 74); // The saved default remains sticky on reopen.
        // Malformed data must never silently become an empty log.
        CHECK([@"{broken" writeToURL:store.file atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        CHECK(![[SailStore alloc] initWithDirectory:directory checklist:checklist error:&error]);
        CHECK([[NSString stringWithContentsOfURL:store.file encoding:NSUTF8StringEncoding error:NULL] isEqual:@"{broken"]);
        [NSFileManager.defaultManager removeItemAtURL:directory error:NULL];
        NSLog(@"PASS: completion, validation, draft persistence, history, CSV escaping, write failure rollback, unreadable file protection");
    }
    return 0;
}
