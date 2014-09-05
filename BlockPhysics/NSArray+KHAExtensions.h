//
//  NSArray+KHAExtensions.h
//  Khan Academy
//
//  Created by Laura Savino on 10/14/13.
//  Copyright (c) 2013 Khan Academy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (KHAExtensions)

- (NSArray *)kha_mappedArrayUsingBlock:(id (^)(id obj, NSUInteger idx, BOOL *stop))block;
- (NSArray *)kha_filteredArrayUsingBlock:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))block;
@end
