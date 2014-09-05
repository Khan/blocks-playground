//
//  KAScratchpadDrawing.m
//  Khan Academy
//
//  Created by Andy Matuschak on 7/8/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAHashingUtilities.h"
#import "KAScratchpadDrawing.h"

NSString *KANSStringFromKAScratchpadToolType(KAScratchpadToolType toolType) {
	switch (toolType) {
		case KAScratchpadToolTypePen:    return @"Pen";
		case KAScratchpadToolTypeEraser: return @"Eraser";
		default:						 NSCAssert(false, @"Unknown tool type"); return nil;
	}
}

#pragma mark - KAScratchpadDrawing

@implementation KAScratchpadDrawing

- (instancetype)initWithCommittedActions:(NSArray *)committedActions pendingAction:(KAScratchpadDrawingAction *)pendingAction {
	self = [super init];
	if (!self) {
		return nil;
	}

	NSParameterAssert(committedActions);
	_committedActions = [committedActions copy];
	_pendingAction = pendingAction;

	return self;
}

+ (KAScratchpadDrawing *)emptyDrawing {
	static dispatch_once_t onceToken;
	static KAScratchpadDrawing *emptyDrawing = nil;
	dispatch_once(&onceToken, ^{
		emptyDrawing = [[KAScratchpadDrawing alloc] initWithCommittedActions:@[] pendingAction:nil];
	});
	return emptyDrawing;
}

- (instancetype)drawingByCommittingPendingAction {
	if (self.pendingAction) {
		if (self.pendingAction.toolType == KAScratchpadToolTypeEraser && [self.committedActions count] == 0) {
			// No point in building up committed erasures on an empty drawing. Also no sense in letting the user undo such actions.
			return [KAScratchpadDrawing emptyDrawing];
		} else {
			return [[KAScratchpadDrawing alloc] initWithCommittedActions:[self.committedActions arrayByAddingObject:self.pendingAction] pendingAction:nil];
		}
	} else {
		return self;
	}
}

- (instancetype)drawingByDiscardingPendingAction {
	return [[KAScratchpadDrawing alloc] initWithCommittedActions:self.committedActions pendingAction:nil];
}

- (instancetype)drawingByDiscardingMostRecentlyCommittedAction {
	if ([self.committedActions count] > 0) {
		return [[KAScratchpadDrawing alloc] initWithCommittedActions:[self.committedActions subarrayWithRange:NSMakeRange(0, [self.committedActions count] - 1)] pendingAction:nil];
	} else {
		return self; // We don't have any committed actions.
	}
}

- (BOOL)isEqual:(id)otherObject {
	if (self == otherObject) {
		return YES;
	} else if ([otherObject isKindOfClass:[KAScratchpadDrawing class]]) {
		KAScratchpadDrawing *otherDrawing = otherObject;
		return [self.committedActions isEqual:otherDrawing.committedActions] &&
		       (self.pendingAction == otherDrawing.pendingAction || [self.pendingAction isEqual:otherDrawing.pendingAction]);
	} else {
		return NO;
	}
}

- (NSUInteger)hash {
	NSUInteger hash = 0;
	KA_HASH_INCORPORATE_OBJECT(hash, self.pendingAction);
	KA_HASH_INCORPORATE_NSARRAY(hash, self.committedActions);
	return hash;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p; committedActions = %@; pendingAction = %@>", NSStringFromClass([self class]), self, self.committedActions, self.pendingAction];
}

@end


#pragma mark - KAScratchpadDrawingAction

@implementation KAScratchpadDrawingAction

- (instancetype)initWithTouchSamples:(NSArray *)touchSamples toolType:(KAScratchpadToolType)toolType color:(UIColor *)color {
	self = [super init];
	if (!self) {
		return nil;
	}

	NSParameterAssert(touchSamples);
	NSParameterAssert(color);
	_touchSamples = [touchSamples copy];
	_toolType = toolType;
	_color = color;

	return self;
}

- (instancetype)actionByAppendingTouchSample:(KAScratchpadDrawingTouchSample *)touchSample {
	NSParameterAssert(touchSample);
	return [[KAScratchpadDrawingAction alloc] initWithTouchSamples:[self.touchSamples arrayByAddingObject:touchSample] toolType:self.toolType color:self.color];
}

- (BOOL)isEqual:(id)otherObject {
	if (self == otherObject) {
		return YES;
	} else if ([otherObject isKindOfClass:[KAScratchpadDrawingAction class]]) {
		KAScratchpadDrawingAction *otherAction = otherObject;
		return [self.touchSamples isEqual:otherAction.touchSamples] &&
		       self.toolType == otherAction.toolType &&
		       [self.color isEqual:otherAction.color];
	} else {
		return NO;
	}
}

- (NSUInteger)hash {
	NSUInteger hash = 0;
	KA_HASH_INCORPORATE_NSARRAY(hash, self.touchSamples);
	KA_HASH_INCORPORATE_NUMERIC(hash, self.toolType);
	KA_HASH_INCORPORATE_OBJECT(hash, self.color);
	return hash;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p; toolType = %@; color = %@; touchSamples = %@>", NSStringFromClass([self class]), self, KANSStringFromKAScratchpadToolType(self.toolType), self.color, self.touchSamples];
}

@end


#pragma mark - KAScratchpadDrawingTouchSample

@implementation KAScratchpadDrawingTouchSample

- (instancetype)initWithLocation:(CGPoint)location timestamp:(NSTimeInterval)timestamp {
	self = [super init];
	if (!self) {
		return nil;
	}

	_location = location;
	_timestamp = timestamp;

	return self;
}

- (CGPoint)estimatedVelocityGivenPreviousTouchSample:(KAScratchpadDrawingTouchSample *)previousTouchSample {
	NSParameterAssert(previousTouchSample);
	CGFloat deltaX = self.location.x - previousTouchSample.location.x;
	CGFloat deltaY = self.location.y - previousTouchSample.location.y;

	NSTimeInterval deltaTime = self.timestamp - previousTouchSample.timestamp;

	if (deltaTime <= 0) {
		return CGPointZero;
	}

	return CGPointMake(deltaX / deltaTime, deltaY / deltaTime);
}

- (BOOL)isEqual:(id)otherObject {
	if (self == otherObject) {
		return YES;
	} else if ([otherObject isKindOfClass:[KAScratchpadDrawingTouchSample class]]) {
		KAScratchpadDrawingTouchSample *otherSample = otherObject;
		return CGPointEqualToPoint(self.location, otherSample.location) && self.timestamp == otherSample.timestamp;
	} else {
		return NO;
	}
}

- (NSUInteger)hash {
	NSUInteger hash = 0;
	KA_HASH_INCORPORATE_NUMERIC(hash, self.location.x);
	KA_HASH_INCORPORATE_NUMERIC(hash, self.location.y);
	KA_HASH_INCORPORATE_NUMERIC(hash, self.timestamp);
	return hash;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p; location = %@; timestamp = %g>", NSStringFromClass([self class]), self, NSStringFromCGPoint(self.location), self.timestamp];
}

@end
