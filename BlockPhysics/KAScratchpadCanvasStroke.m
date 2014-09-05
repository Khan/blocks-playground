//
//  KAScratchpadCanvasStroke.m
//  Khan Academy
//
//  Created by Andy Matuschak on 7/8/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAHashingUtilities.h"
#import "KAScratchpadCanvasStroke.h"
#import "KAScratchpadCanvasPath.h"

NSString *KANSStringFromKAScratchpadRenderingMode(KAScratchpadRenderingMode renderingMode) {
	switch (renderingMode) {
		case KAScratchpadRenderingModeDraw:  return @"Draw";
		case KAScratchpadRenderingModeErase: return @"Erase";
		default:							 NSCAssert(false, @"Unknown rendering mode"); return nil;
	}
}

@implementation KAScratchpadCanvasStroke

- (instancetype)initWithPath:(KAScratchpadCanvasPath *)path color:(UIColor *)color renderingMode:(KAScratchpadRenderingMode)renderingMode {
	self = [super init];
	if (!self) {
		return nil;
	}

	NSParameterAssert(path);
	NSParameterAssert(color);
	_path = path;
	_color = color;
	_renderingMode = renderingMode;

	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p; color = %@; renderingMode = %@; path = %@>", NSStringFromClass([self class]), self, self.color, KANSStringFromKAScratchpadRenderingMode(self.renderingMode), self.path];
}

- (BOOL)isEqual:(id)otherObject {
	if (self == otherObject) {
		return YES;
	} else if ([otherObject isKindOfClass:[KAScratchpadCanvasStroke class]]) {
		KAScratchpadCanvasStroke *otherStroke = otherObject;
		return [self.path isEqual:otherStroke.path] &&
			   [self.color isEqual:otherStroke.color] &&
			   self.renderingMode == otherStroke.renderingMode;
	} else {
		return NO;
	}
}

- (NSUInteger)hash {
	NSUInteger hash = 0;
	KA_HASH_INCORPORATE_OBJECT(hash, self.path);
	KA_HASH_INCORPORATE_OBJECT(hash, self.color);
	KA_HASH_INCORPORATE_NUMERIC(hash, self.renderingMode);
	return hash;
}

@end
