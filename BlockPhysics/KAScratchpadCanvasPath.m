//
//  KAScratchpadCanvasPath.m
//  Khan Academy
//
//  Created by Andy Matuschak on 7/8/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAHashingUtilities.h"
#import "KAScratchpadCanvasPath.h"

#pragma mark - KAScratchpadCanvasPathComponent

NSUInteger KAScratchpadCanvasPathComponentHash(KAScratchpadCanvasPathComponent pathComponent) {
	NSUInteger hash = 0;
	KA_HASH_INCORPORATE_NUMERIC(hash, pathComponent.point.x);
	KA_HASH_INCORPORATE_NUMERIC(hash, pathComponent.point.y);
	KA_HASH_INCORPORATE_NUMERIC(hash, pathComponent.width);
	return hash;
}

NSString *KAScratchpadCanvasPathComponentDescription(KAScratchpadCanvasPathComponent pathComponent) {
	return [NSString stringWithFormat:@"<KAScratchpadCanvasPathComponent: point = %@; width = %g>", NSStringFromCGPoint(pathComponent.point), pathComponent.width];
}

#pragma mark - KAScratchpadCanvasPath

@interface KAScratchpadCanvasPath ()
@property (nonatomic, strong, readonly) NSData *componentData;
@end

@implementation KAScratchpadCanvasPath

- (instancetype)initWithComponentData:(NSData *)componentData hasEndCap:(BOOL)hasEndCap {
	self = [super init];
	if (!self) {
		return nil;
	}

	NSParameterAssert(componentData);
	_componentData = componentData;
	_hasEndCap = hasEndCap;

	return self;
}

- (NSString *)description {
	NSMutableString *output = [[NSMutableString alloc] initWithFormat:@"<%@: %p; hasEndCap = %d; components = {\n", NSStringFromClass([self class]), self, self.hasEndCap];
	for (NSUInteger i = 0; i < self.componentCount; i++) {
		[output appendFormat:@"\t%@\n", KAScratchpadCanvasPathComponentDescription(self.components[i])];
	}
	[output appendString:@"}>"];
	return output;
}

- (KAScratchpadCanvasPathComponent *)components {
	return (KAScratchpadCanvasPathComponent *)[self.componentData bytes];
}

- (NSUInteger)componentCount {
	return [self.componentData length] / sizeof(KAScratchpadCanvasPathComponent);
}

- (BOOL)isEqual:(id)otherObject {
	if (self == otherObject) {
		return YES;
	} else if ([otherObject isKindOfClass:[KAScratchpadCanvasPath class]]) {
		KAScratchpadCanvasPath *otherPath = otherObject;
		return self.hasEndCap == otherPath.hasEndCap &&
		       self.componentCount == otherPath.componentCount &&
		       memcmp(self.components, otherPath.components, sizeof(KAScratchpadCanvasPathComponent) * self.componentCount) == 0;
	} else {
		return NO;
	}
}

- (NSUInteger)hash {
	NSUInteger hash = 0;
	KA_HASH_INCORPORATE_NUMERIC(hash, self.componentCount);
	KA_HASH_INCORPORATE_BOOLEAN(hash, self.hasEndCap);
	for (NSUInteger i = 0; i < self.componentCount; i++) {
		KA_HASH_INCORPORATE_NUMERIC(hash, KAScratchpadCanvasPathComponentHash(self.components[i]));
	}
	return hash;
}

@end
