//
//  KAScratchpadGestureRecognizer.m
//  Khan Academy
//
//  Created by Kasra Kyanzadeh on 2014-06-10.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAScratchpadGestureRecognizer.h"
#import "KAGeometryFunctions.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

static const CGFloat KAIgnoreAdditionalTouchesDistanceThreshold = 40.0;

@interface KAScratchpadGestureRecognizer ()

// The touch being used to draw.
@property (nonatomic, strong) UITouch *activeTouch;

// When the user drags past the threshold distance, this is set to YES. This means additional touches won't cancel the gesture anymore.
@property (nonatomic, assign) BOOL shouldIgnoreAdditionalTouches;

@property (nonatomic, assign) CGPoint touchStartLocation;

@property (nonatomic, assign) NSTimeInterval previousTouchTime;
@property (nonatomic, assign) NSTimeInterval currentTouchTime;

@end

@implementation KAScratchpadGestureRecognizer

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	if (self.shouldIgnoreAdditionalTouches) {
		// Do nothing.
		return;
	}

	if (!self.activeTouch && touches.count == 1) {
		self.state = UIGestureRecognizerStateBegan;
		self.activeTouch = [touches anyObject];
		self.touchStartLocation = [self.activeTouch locationInView:self.view];
		self.previousTouchTime = [NSDate timeIntervalSinceReferenceDate];
		self.currentTouchTime = self.previousTouchTime;
	} else {
		// Additional touches cancel the gesture.
		self.state = UIGestureRecognizerStateFailed;
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	// Only one touch is allowed until we start ignoring additional touches.
	if (!self.shouldIgnoreAdditionalTouches && touches.count > 1) {
		self.state = UIGestureRecognizerStateCancelled;
	} else {
		if ([touches containsObject:self.activeTouch]) {
			self.previousTouchTime = self.currentTouchTime;
			self.currentTouchTime = self.activeTouch.timestamp;

			self.state = UIGestureRecognizerStateChanged;

			CGFloat distance = kha_CGPointDistance(self.touchStartLocation, [self.activeTouch locationInView:self.view]);
			if (distance > KAIgnoreAdditionalTouchesDistanceThreshold) {
				self.shouldIgnoreAdditionalTouches = YES;
			}
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if ([touches containsObject:self.activeTouch]) {
		self.state = UIGestureRecognizerStateEnded;
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	if ([touches containsObject:self.activeTouch]) {
		self.state = UIGestureRecognizerStateCancelled;
	}
}

- (void)cancelRecognition {
	// Only cancel if we're recognizing.
	if (self.activeTouch) {
		self.state = UIGestureRecognizerStateCancelled;
	}
}

- (void)reset {
	[super reset];

	self.activeTouch = nil;
	self.shouldIgnoreAdditionalTouches = NO;
}

- (CGPoint)locationInView:(UIView *)view {
	NSAssert(self.activeTouch, @"There is no touch to give the location for.");
	return [self.activeTouch locationInView:view];
}

- (CGPoint)velocityInView:(UIView *)view {
	if (!self.activeTouch) {
		return CGPointZero;
	}

	CGPoint previousLocation = [self.activeTouch previousLocationInView:view];
	CGPoint currentLocation = [self.activeTouch locationInView:view];

	CGFloat deltaX = currentLocation.x - previousLocation.x;
	CGFloat deltaY = currentLocation.y - previousLocation.y;

	NSTimeInterval deltaTime = self.currentTouchTime - self.previousTouchTime;

	if (deltaTime <= 0) {
		return CGPointZero;
	}

	return CGPointMake(deltaX / deltaTime, deltaY / deltaTime);
}

@end
