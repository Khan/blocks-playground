//
//  KAScratchpadCanvasPathPlotter.m
//  Khan Academy
//
//  Created by Andy Matuschak on 7/14/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import <GLKit/GLKVector2.h>
#import "KAScratchpadCanvasPath.h"
#import "KAScratchpadCanvasPathPlotter.h"

@implementation KAScratchpadCanvasPathPlotter

/// Cheaply converts from CGPoint to GLKVector2
static inline GLKVector2 GLKVector2FromCGPoint(CGPoint point) {
	return GLKVector2Make(point.x, point.y);
}

/// Cheaply converts from GLKVector2 to CGPoint
static inline CGPoint CGPointFromGLKVector2(GLKVector2 vector) {
	return CGPointMake(vector.x, vector.y);
}

/// Projects out by `projectionMagnitude` in both directions from `projectionSourcePoint` along the vectors perpendicular to (`toPoint` - `fromPoint`). `fromPoint` and `toPoint` must be non-equal.
static inline void _getCGPointsProjectedFromPointGivenEndpoints(CGPoint projectionSourcePoint, CGFloat projectionMagnitude, CGPoint fromPoint, CGPoint toPoint, CGPoint *outPositivePoint, CGPoint *outNegativePoint) {
	NSCAssert(!CGPointEqualToPoint(fromPoint, toPoint), @"Can't project out from two equal points");
	GLKVector2 fromVec = GLKVector2FromCGPoint(fromPoint);
	GLKVector2 toVec = GLKVector2FromCGPoint(toPoint);
	GLKVector2 delta = GLKVector2Subtract(toVec, fromVec);
	GLKVector2 direction = GLKVector2Normalize(delta);
	GLKVector2 perpendicularDirection = GLKVector2Make(-direction.y, direction.x);

	GLKVector2 positiveProjectedVector = GLKVector2Add(GLKVector2FromCGPoint(projectionSourcePoint), GLKVector2MultiplyScalar(perpendicularDirection, projectionMagnitude));
	GLKVector2 negativeProjectedVector = GLKVector2Add(GLKVector2FromCGPoint(projectionSourcePoint), GLKVector2MultiplyScalar(perpendicularDirection, -1 * projectionMagnitude));

	*outPositivePoint = CGPointFromGLKVector2(positiveProjectedVector);
	*outNegativePoint = CGPointFromGLKVector2(negativeProjectedVector);
}

/*** Returns the midpoint of the line a-b. */
static inline CGPoint _CGPointHalfwayBetweenPoints(CGPoint a, CGPoint b) {
	return CGPointMake((a.x + b.x) / 2.0, (a.y + b.y) / 2.0);
}

/// Returns a path component whose point and width are the average of `a` and `b`'s.
static inline KAScratchpadCanvasPathComponent _pathComponentRepresentingMidpointOfPathComponents(KAScratchpadCanvasPathComponent a, KAScratchpadCanvasPathComponent b) {
	CGPoint midpoint = _CGPointHalfwayBetweenPoints(a.point, b.point);
	CGFloat averageWidth = (a.width + b.width) / 2.0;
	return (KAScratchpadCanvasPathComponent){.point = midpoint, .width = averageWidth};
}

/// Returns a bezier path describing a curved trapezoidal representation of a path component triple. The `throughComponent` is used to create control points for the curved outer edges of the trapezoid.
static inline UIBezierPath *_bezierPathRepresentingCurvedTrapezoid(KAScratchpadCanvasPathComponent fromComponent, KAScratchpadCanvasPathComponent throughComponent, KAScratchpadCanvasPathComponent toComponent) {
	CGPoint fromPositiveProjection, fromNegativeProjection;
	_getCGPointsProjectedFromPointGivenEndpoints(fromComponent.point, fromComponent.width / 2.0, fromComponent.point, throughComponent.point, &fromPositiveProjection, &fromNegativeProjection);

	CGPoint throughPositiveProjection, throughNegativeProjection;
	_getCGPointsProjectedFromPointGivenEndpoints(throughComponent.point, throughComponent.width / 2.0, fromComponent.point, toComponent.point, &throughPositiveProjection, &throughNegativeProjection);

	CGPoint toPositiveProjection, toNegativeProjection;
	_getCGPointsProjectedFromPointGivenEndpoints(toComponent.point, toComponent.width / 2.0, throughComponent.point, toComponent.point, &toPositiveProjection, &toNegativeProjection);

	UIBezierPath *curvedTrapezoidPath = [UIBezierPath bezierPath];
	[curvedTrapezoidPath moveToPoint:fromPositiveProjection];
	[curvedTrapezoidPath addQuadCurveToPoint:toPositiveProjection controlPoint:throughPositiveProjection];
	[curvedTrapezoidPath addLineToPoint:toNegativeProjection];
	[curvedTrapezoidPath addQuadCurveToPoint:fromNegativeProjection controlPoint:throughNegativeProjection];
	[curvedTrapezoidPath addLineToPoint:fromPositiveProjection];
	return curvedTrapezoidPath;
}

/// Returns a bezier path describing a straight trapezoid connecting `fromComponent` and `toComponent`.
static inline UIBezierPath *_bezierPathRepresentingStraightTrapezoid(KAScratchpadCanvasPathComponent fromComponent, KAScratchpadCanvasPathComponent toComponent) {
	CGPoint fromPositiveProjection, fromNegativeProjection;
	_getCGPointsProjectedFromPointGivenEndpoints(fromComponent.point, fromComponent.width / 2.0, fromComponent.point, toComponent.point, &fromPositiveProjection, &fromNegativeProjection);

	CGPoint toPositiveProjection, toNegativeProjection;
	_getCGPointsProjectedFromPointGivenEndpoints(toComponent.point, toComponent.width / 2.0, fromComponent.point, toComponent.point, &toPositiveProjection, &toNegativeProjection);

	UIBezierPath *trapezoidPath = [UIBezierPath bezierPath];
	[trapezoidPath moveToPoint:fromPositiveProjection];
	[trapezoidPath addLineToPoint:toPositiveProjection];
	[trapezoidPath addLineToPoint:toNegativeProjection];
	[trapezoidPath addLineToPoint:fromNegativeProjection];
	[trapezoidPath addLineToPoint:fromPositiveProjection];
	return trapezoidPath;
}

/// Returns whether `a` and `b` are distant enough from each other that rendering trapezoids between them would not cause artifacts.
static inline BOOL _pathComponentsAreDistantEnoughForRendering(KAScratchpadCanvasPathComponent a, KAScratchpadCanvasPathComponent b) {
	// TODO(andy): this subdivision should be more sophisticated in its adaptation, should depend on the local curvature of the segments (http://en.wikipedia.org/wiki/Curvature)
	return GLKVector2Distance(GLKVector2FromCGPoint(a.point), GLKVector2FromCGPoint(b.point)) > b.width / 2.0;
}

/// Returns a bezier path describing a semicirclar cap oriented at `onComponent` with an angle based on the vector from `neighborComponent` to `onComponent`.
static UIBezierPath *_bezierPathRepresentingSemicircularCap(KAScratchpadCanvasPathComponent onComponent, KAScratchpadCanvasPathComponent neighborComponent) {
	CGFloat angle = atan2(onComponent.point.y - neighborComponent.point.y, onComponent.point.x - neighborComponent.point.x);
	UIBezierPath *semicircle = [UIBezierPath bezierPathWithArcCenter:onComponent.point radius:onComponent.width / 2.0 startAngle:(angle - M_PI_2) endAngle:(angle + M_PI_2) clockwise:YES];
	[semicircle closePath];
	return semicircle;
}

/// Returns the index of the minimum component index in `canvasPath` which is distant enough from the first component index to subdivide correctly.
static NSInteger _effectiveSecondComponentIndexForCanvasPath(KAScratchpadCanvasPath *canvasPath) {
	if (canvasPath.componentCount > 0) {
		// Find the next component after the first that's distant enough to actually render trapezoids to.
		KAScratchpadCanvasPathComponent firstComponent = canvasPath.components[0];
		for (NSUInteger componentIndex = 1; componentIndex < canvasPath.componentCount; componentIndex++) {
			if (_pathComponentsAreDistantEnoughForRendering(firstComponent, canvasPath.components[componentIndex])) {
				return componentIndex;
			}
		}
	}
	return NSNotFound;
}

/// Returns YES when `canvasPath` should be represented by a simple circle rather than a complex curved trapezoidal bezier path.
static BOOL _shouldRepresentCanvasPathWithCircle(KAScratchpadCanvasPath *canvasPath, NSInteger effectiveSecondComponentIndex) {
	return (effectiveSecondComponentIndex == NSNotFound || canvasPath.componentCount == 2);
}

static UIBezierPath *_bezierPathRepresentingCircleForCanvasPath(KAScratchpadCanvasPath *canvasPath) {
	// Draw a circle at the first point with its width as diameter.
	KAScratchpadCanvasPathComponent firstComponent = canvasPath.components[0];
	CGPoint center = firstComponent.point;
	CGFloat diameter = firstComponent.width;
	return [UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x - diameter / 2.0, center.y - diameter / 2.0, diameter, diameter)];
}

/// Returns an array of bezier paths which describe a curved trapezoidal inking shape for `canvasPath`. As an optimization for incremental stroking, you may specify `skipPathsUntilComponentIndex` to avoid actually generating bezier paths until that index.
static NSArray *_bezierPathsRepresentingCurvedTrapezoidalBezierPathForCanvasPath(KAScratchpadCanvasPath *canvasPath, NSInteger effectiveSecondComponentIndex, NSInteger skipPathsUntilComponentIndex) {
	NSMutableArray *paths = [NSMutableArray array];

	KAScratchpadCanvasPathComponent firstComponent = canvasPath.components[0];
	KAScratchpadCanvasPathComponent secondComponent = canvasPath.components[effectiveSecondComponentIndex];

	if (effectiveSecondComponentIndex >= skipPathsUntilComponentIndex) {
		// Draw a cap on the front of the path.
		[paths addObject:_bezierPathRepresentingSemicircularCap(firstComponent, secondComponent)];

		// Draw a straight trapezoid between the first component, and the midpoint between the first and second.
		KAScratchpadCanvasPathComponent initialMidpointComponent = _pathComponentRepresentingMidpointOfPathComponents(firstComponent, secondComponent);
		[paths addObject:_bezierPathRepresentingStraightTrapezoid(firstComponent, initialMidpointComponent)];
	}

	// Draw curved trapezoids between all the intermediate path segments.
	KAScratchpadCanvasPathComponent componentToRenderFrom = firstComponent;
	KAScratchpadCanvasPathComponent componentToRenderThrough = secondComponent;
	NSUInteger indexOfComponentToRenderThrough = effectiveSecondComponentIndex;
	for (NSUInteger componentIndex = effectiveSecondComponentIndex + 1; componentIndex < canvasPath.componentCount; componentIndex++) {
		KAScratchpadCanvasPathComponent componentToRenderTo = canvasPath.components[componentIndex];
		// Avoid subdivision artifacts by only rendering trapezoids that are a sufficient width.
		if (_pathComponentsAreDistantEnoughForRendering(componentToRenderFrom, componentToRenderTo) &&
			_pathComponentsAreDistantEnoughForRendering(componentToRenderThrough, componentToRenderTo)) {
			if (componentIndex >= skipPathsUntilComponentIndex) {
				// Render a curved trapezoid:
				// - from the midpoint between the last two components rendered
				// - through the last component rendered
				// - to the midpoint between the current component and the last component rendered
				KAScratchpadCanvasPathComponent fromThroughMidpointComponent = _pathComponentRepresentingMidpointOfPathComponents(componentToRenderFrom, componentToRenderThrough);
				KAScratchpadCanvasPathComponent throughToMidpointComponent = _pathComponentRepresentingMidpointOfPathComponents(componentToRenderThrough, componentToRenderTo);
				[paths addObject:_bezierPathRepresentingCurvedTrapezoid(fromThroughMidpointComponent, componentToRenderThrough, throughToMidpointComponent)];
			}
			componentToRenderFrom = componentToRenderThrough;
			componentToRenderThrough = componentToRenderTo;
			indexOfComponentToRenderThrough = componentIndex;
		}
	}

	KAScratchpadCanvasPathComponent penultimateComponent = componentToRenderFrom;
	KAScratchpadCanvasPathComponent finalComponent = componentToRenderThrough;
	NSUInteger finalComponentIndex = indexOfComponentToRenderThrough;

	if (finalComponentIndex >= skipPathsUntilComponentIndex && canvasPath.hasEndCap) {
		// Draw a straight trapezoid between the midpoint of last two used components and the last used component.
		KAScratchpadCanvasPathComponent finalMidpointComponent = _pathComponentRepresentingMidpointOfPathComponents(penultimateComponent, finalComponent);
		[paths addObject:_bezierPathRepresentingStraightTrapezoid(finalMidpointComponent, finalComponent)];

		// Draw a cap on the end of the path.
		[paths addObject:_bezierPathRepresentingSemicircularCap(finalComponent, penultimateComponent)];
	}

	return paths;
}

- (NSArray *)representedBezierPathsForCanvasPath:(KAScratchpadCanvasPath *)canvasPath {
	NSParameterAssert(canvasPath);

	if (canvasPath.componentCount > 0) {
		NSInteger effectiveSecondComponentIndex = _effectiveSecondComponentIndexForCanvasPath(canvasPath);

		// TODO(andy): handle two components specially as a capped straight trapezoid
		if (_shouldRepresentCanvasPathWithCircle(canvasPath, effectiveSecondComponentIndex)) {
			return @[_bezierPathRepresentingCircleForCanvasPath(canvasPath)];
		} else {
			return _bezierPathsRepresentingCurvedTrapezoidalBezierPathForCanvasPath(canvasPath, effectiveSecondComponentIndex, 0);
		}
	} else {
		return @[];
	}
}

/// Returns bezier paths representing `canvasPath` given that it contains `previousCanvasPath` as a strict prefix, leveraging `previousCanvasPathRepresentedBezierPaths` as an optimization.
- (NSArray *)representedBezierPathsForCanvasPath:(KAScratchpadCanvasPath *)canvasPath byAddingToCanvasPath:(KAScratchpadCanvasPath *)previousCanvasPath withRepresentedBezierPaths:(NSArray *)previousCanvasPathRepresentedBezierPaths {
	// The structure of this incremental addition should be changed alongside the implementation of `representedBezierPathsForCanvasPath`.
	NSInteger newCanvasPathEffectiveSecondComponentIndex = _effectiveSecondComponentIndexForCanvasPath(canvasPath);
	NSInteger oldCanvasPathEffectiveSecondComponentIndex = _effectiveSecondComponentIndexForCanvasPath(previousCanvasPath);
	if (_shouldRepresentCanvasPathWithCircle(canvasPath, newCanvasPathEffectiveSecondComponentIndex)) {
		// Was just a circle; will still just be a circle.
		return previousCanvasPathRepresentedBezierPaths;
	} else if (_shouldRepresentCanvasPathWithCircle(previousCanvasPath, oldCanvasPathEffectiveSecondComponentIndex)) {
		// The old path was just a circle; we can't reuse that.
		return [self representedBezierPathsForCanvasPath:canvasPath];
	} else {
		NSArray *newRepresentedBezierPaths = _bezierPathsRepresentingCurvedTrapezoidalBezierPathForCanvasPath(canvasPath, newCanvasPathEffectiveSecondComponentIndex, previousCanvasPath.componentCount);
		// The new path components may be close enough to the previous path components that no new bezier paths are generated.
		if ([newRepresentedBezierPaths count] > 0) {
			// But if new bezier paths have been generated, strip off the "tail" of the previous bezier path list (if necessary) and append the new paths.
			NSArray *reusableRepresentedBezierPathsFromPreviousCanvasPath = previousCanvasPathRepresentedBezierPaths;
			if (previousCanvasPath.hasEndCap) {
				NSUInteger countOfElementsToRemoveFromPreviousCanvasPathRepresentedBezierPaths = 2; // one for the straight trapezoid; one for the potential end cap.
				NSAssert([previousCanvasPathRepresentedBezierPaths count] >= countOfElementsToRemoveFromPreviousCanvasPathRepresentedBezierPaths, @"unexpected previous bezier path structure");
				reusableRepresentedBezierPathsFromPreviousCanvasPath = [previousCanvasPathRepresentedBezierPaths subarrayWithRange:NSMakeRange(0, [previousCanvasPathRepresentedBezierPaths count] - countOfElementsToRemoveFromPreviousCanvasPathRepresentedBezierPaths)];
			}
			return [reusableRepresentedBezierPathsFromPreviousCanvasPath arrayByAddingObjectsFromArray:newRepresentedBezierPaths];
		} else {
			return previousCanvasPathRepresentedBezierPaths;
		}
	}
}

- (NSArray *)representedBezierPathsForCanvasPath:(KAScratchpadCanvasPath *)canvasPath byModifyingPreviousCanvasPath:(KAScratchpadCanvasPath *)previousCanvasPath withRepresentedBezierPaths:(NSArray *)previousCanvasPathRepresentedBezierPaths {
	NSParameterAssert(canvasPath);
	NSParameterAssert(previousCanvasPath);
	NSParameterAssert(previousCanvasPathRepresentedBezierPaths);

	if (canvasPath.componentCount > 0) {
		// We can only cheaply extend the previous path's representation if it's a strict prefix of the new canvas path.
		if (canvasPath.componentCount > previousCanvasPath.componentCount &&
			memcmp(canvasPath.components, previousCanvasPath.components, sizeof(KAScratchpadCanvasPathComponent) * previousCanvasPath.componentCount) == 0) {
			return [self representedBezierPathsForCanvasPath:canvasPath byAddingToCanvasPath:previousCanvasPath withRepresentedBezierPaths:previousCanvasPathRepresentedBezierPaths];
		} else {
			return [self representedBezierPathsForCanvasPath:canvasPath];
		}
	} else {
		return @[];
	}
}

@end
