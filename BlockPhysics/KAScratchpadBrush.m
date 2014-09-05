//
//  KAScratchpadBrush.m
//  Khan Academy
//
//  Created by Andy Matuschak on 7/9/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAGeometryFunctions.h"
#import "KAScratchpadBrush.h"
#import "KAScratchpadDrawing.h"
#import "KAScratchpadCanvasPath.h"
#import "NSArray+KHAExtensions.h"

/**
 * A simple low-pass filter mixing `oldValue` with `newValue`.
 *
 * @param smoothingFactor Higher values retain more of `oldValue` in the output. Valid input range: [0, 1].
 */
static CGFloat _lowPassFilter(CGFloat oldValue, CGFloat newValue, CGFloat smoothingFactor) {
	NSCParameterAssert(smoothingFactor >= 0);
	NSCParameterAssert(smoothingFactor <= 1);
	return oldValue * smoothingFactor + newValue * (1.0 - smoothingFactor);
}

/**
 * Computes path component data from touch samples using the smoothed output of a velocity-based width function.
 *
 * @param touchSamples An NSArray of `KAScratchpadDrawingTouchSample`s. Must be non-nil.
 * @param widthSmoothingFactor The widths are put through a low-pass filter parameterized by this factor to keep them from varying too rapidly.
 * @param widthFunction A block returning the width for a touch sample with a given velocity magnitude. Must be non-nil.
 * @return An NSData encapsulating a C array of `KAScratchpadCanvasPathComponent`s.
 */
static NSData *_velocityBasedPathComponentDataForTouchSamples(NSArray *touchSamples, CGFloat widthSmoothingFactor, CGFloat (^widthFunction)(CGFloat velocityMagnitude)) __attribute__((nonnull(1,3)));
static NSData *_velocityBasedPathComponentDataForTouchSamples(NSArray *touchSamples, CGFloat widthSmoothingFactor, CGFloat (^widthFunction)(CGFloat velocityMagnitude)) {
	NSCParameterAssert(touchSamples);
	NSCParameterAssert(widthFunction);

	__block CGFloat previousWidth = -1;
	KAScratchpadCanvasPathComponent *outComponents = calloc([touchSamples count], sizeof(KAScratchpadCanvasPathComponent));
	[touchSamples enumerateObjectsUsingBlock:^(KAScratchpadDrawingTouchSample *touchSample, NSUInteger idx, BOOL *stop) {
		CGFloat newWidth;
		if (idx == 0) {
			newWidth = widthFunction(0.0);
		} else {
			CGPoint velocity = [touchSample estimatedVelocityGivenPreviousTouchSample:touchSamples[idx - 1]];
			CGFloat unsmoothedWidth = widthFunction(kha_CGPointMagnitude(velocity));
			newWidth = _lowPassFilter(previousWidth, unsmoothedWidth, widthSmoothingFactor);
		}
		previousWidth = newWidth;
		outComponents[idx] = (KAScratchpadCanvasPathComponent){.point = touchSample.location, .width = newWidth};
	}];

	return [NSData dataWithBytesNoCopy:outComponents length:sizeof(KAScratchpadCanvasPathComponent) * [touchSamples count] freeWhenDone:YES];
}


#pragma mark - KAScratchpadPenBrush

static const CGFloat KAScratchpadPenBrushTapDistanceThreshold = 1.842105; ///< Committed pairs of touches less than this distance apart will generate a "dot" instead of a line.

static const CGFloat KAScratchpadPenBrushMinimumWidth = 1.546053; ///< The width of the pen at the maximum velocity.
static const CGFloat KAScratchpadPenBrushMaximumWidth = 4.605263; ///< The width of the pen at the minimum velocity.
static const CGFloat KAScratchpadPenBrushFalloffFactor = 703.0461; ///< How quickly pen thickness falls off as velocity increases (higher values fall off more quickly).
static const CGFloat KAScratchpadPenBrushWidthSmoothingFactor = 0.3968421; ///< How much to smooth changes in brush width. 0 is no smoothing; 1 is smoothed so much that it never changes.

@implementation KAScratchpadPenBrush

static BOOL _touchSamplesRepresentTap(NSArray *touchSamples) {
	// TODO: we should still try to recognize touch sequences with more than two samples as a tap, so long as no touch strays too far from the initial touch
	switch ([touchSamples count]) {
		case 1:  return YES;
		case 2:  return kha_CGPointDistance([(KAScratchpadDrawingTouchSample *)touchSamples[0] location], [(KAScratchpadDrawingTouchSample *)touchSamples[1] location]) < KAScratchpadPenBrushTapDistanceThreshold;
		default: return NO;
	}
}

- (KAScratchpadCanvasPath *)pathForTouchSamples:(NSArray *)touchSamples isCommitted:(BOOL)isCommitted {
	NSParameterAssert([touchSamples count] > 0);

	NSData *componentData = nil;
	if (_touchSamplesRepresentTap(touchSamples) && isCommitted) {
		KAScratchpadCanvasPathComponent dotComponent = (KAScratchpadCanvasPathComponent){.point = [(KAScratchpadDrawingTouchSample *)touchSamples[0] location], .width = self.dotWidth};
		componentData = [NSData dataWithBytes:&dotComponent length:sizeof(KAScratchpadCanvasPathComponent)];
	} else {
		componentData = _velocityBasedPathComponentDataForTouchSamples(touchSamples, KAScratchpadPenBrushWidthSmoothingFactor, ^CGFloat(CGFloat velocityMagnitude) {
			// Interpolate the pen width according to exponential decay.
			return (KAScratchpadPenBrushMaximumWidth - KAScratchpadPenBrushMinimumWidth) * exp(-1 * velocityMagnitude / KAScratchpadPenBrushFalloffFactor) + KAScratchpadPenBrushMinimumWidth;
		});
	}

	return [[KAScratchpadCanvasPath alloc] initWithComponentData:componentData hasEndCap:isCommitted];
}

- (KAScratchpadRenderingMode)renderingMode {
	return KAScratchpadRenderingModeDraw;
}

@end


#pragma mark - KAScratchpadEraserBrush

static const CGFloat KAScratchpadEraserBrushMinimumWidth = 4.539474; ///< The width of the eraser at the minimum velocity.
static const CGFloat KAScratchpadEraserBrushMaximumWidth = 223.6842; ///< The width of the eraser at the maximum velocity.
static const CGFloat KAScratchpadEraserBrushMaximumVelocity = 6000; ///< Velocity at which eraser will have maximum width.
static const CGFloat KAScratchpadEraserBrushWidthSmoothingFactor = 0.6547368; ///< How much to smooth changes in brush width. 0 is no smoothing; 1 is smoothed so much that it never changes.

@implementation KAScratchpadEraserBrush

- (KAScratchpadCanvasPath *)pathForTouchSamples:(NSArray *)touchSamples isCommitted:(BOOL)isCommitted {
	NSData *componentData = _velocityBasedPathComponentDataForTouchSamples(touchSamples, KAScratchpadEraserBrushWidthSmoothingFactor, ^CGFloat(CGFloat velocityMagnitude) {
		// Linearly interpolate an eraser width, according to velocity.
		CGFloat newWidth = (KAScratchpadEraserBrushMaximumWidth - KAScratchpadEraserBrushMinimumWidth) * (velocityMagnitude / KAScratchpadEraserBrushMaximumVelocity) + KAScratchpadEraserBrushMinimumWidth;
		return MIN(newWidth, KAScratchpadEraserBrushMaximumWidth);
	});
	return [[KAScratchpadCanvasPath alloc] initWithComponentData:componentData hasEndCap:isCommitted];
}

- (KAScratchpadRenderingMode)renderingMode {
	return KAScratchpadRenderingModeErase;
}

@end
