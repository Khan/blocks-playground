//
//  NSArray+KHAExtensions.m
//  Khan Academy
//
//  Created by Laura Savino on 10/14/13.
//  Copyright (c) 2013 Khan Academy. All rights reserved.
//

#import "NSArray+KHAExtensions.h"

@implementation NSArray (KHAExtensions)

- (NSArray *)kha_mappedArrayUsingBlock:(id (^)(id obj, NSUInteger idx, BOOL *stop))block; {
	NSParameterAssert(block != nil);

	NSMutableArray *mappedArray = [NSMutableArray arrayWithCapacity:self.count];

	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		id mappedObj = block(obj, idx, stop);
		if (!mappedObj) {
			mappedObj = [NSNull null];
		}
		[mappedArray addObject:mappedObj];
	}];

	return [mappedArray copy];
}

- (NSArray *)kha_filteredArrayUsingBlock:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))block; {
	NSParameterAssert(block != nil);

	NSIndexSet *passedIndexes = [self indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return block(obj, idx, stop);
	}];

	return [self objectsAtIndexes:passedIndexes];
}

@end
