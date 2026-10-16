// SPDX-License-Identifier: BSD-3-Clause
#import <Foundation/Foundation.h>

@interface SailStore : NSObject
@property(nonatomic, readonly) NSDictionary *lists;
@property(nonatomic, readonly) NSMutableDictionary *state;
@property(nonatomic, readonly) NSURL *file;
- (instancetype)initWithDirectory:(NSURL *)directory checklist:(NSURL *)checklist error:(NSError **)error;
- (NSMutableDictionary *)draft;
- (BOOL)save:(NSError **)error;
- (NSString *)csv;
- (BOOL)complete:(NSError **)error;
@end
