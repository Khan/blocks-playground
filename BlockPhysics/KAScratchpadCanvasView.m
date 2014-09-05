//
//  KAScratchpadCanvasView.m
//  Khan Academy
//
//  Created by Kasra Kyanzadeh on 2014-06-11.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAScratchpadCanvasPath.h"
#import "KAScratchpadCanvasPathPlotter.h"
#import "KAScratchpadCanvasStroke.h"
#import "KAScratchpadCanvasTileCache.h"
#import "KAScratchpadCanvasView.h"

CGFloat KAScratchpadCanvasViewTileSize = 128.0; ///< The width and height of the tiles in the canvas view's tile cache (in points).

@interface KAScratchpadCanvasView ()

/**
 A rasterized cache of the committed strokes.

 `invalidateCommittedStrokeCache` clears this.
 `createCommittedStrokeCache` recreates it from scratch. `drawRect:` calls this.
 `applyPathGroupToCommittedStrokeCache:usingBezierPathCache:` adds a new stroke to the cache.

 */
@property (nonatomic, strong, readwrite) KAScratchpadCanvasTileCache *committedStrokeTileCache;

/// Used to generate bezier path representations of canvas paths.
@property (nonatomic, strong, readwrite) KAScratchpadCanvasPathPlotter *pathPlotter;

/// A cache of the bezier paths representing `pendingStroke`. Changes in lockstep with that property's value.
@property (nonatomic, strong, readwrite) NSArray *pendingStrokeCachedBezierPaths;

// readwrite internally so we can update drawingBounds as committedStrokes changes. Updated as a side effect of calling `createCommittedStrokeCacheBitmapContext`.
@property (nonatomic, assign, readwrite) CGRect drawingBounds;

@end

@implementation KAScratchpadCanvasView

- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}

	self.backgroundColor = [UIColor clearColor];
	self.pathPlotter = [[KAScratchpadCanvasPathPlotter alloc] init];

	// Pin the drawing to the top left for smooth rotations.
	self.contentMode = UIViewContentModeTopLeft;

	// Use a hardware-accelerated CGContext when rendering layer backing store.
	self.layer.drawsAsynchronously = YES;

	self.drawingBounds = CGRectZero;
	[self invalidateCommittedStrokeCache];

	return self;
}

- (void)setDrawingBounds:(CGRect)drawingBounds {
	_drawingBounds = CGRectIntegral(drawingBounds);
}

static CGRect _invalidatedDisplayRectForChangeInBezierPaths(NSArray *oldBezierPaths, NSArray *newBezierPaths) {
	NSCParameterAssert(newBezierPaths);
	NSCAssert([newBezierPaths count] >= [oldBezierPaths count], @"newBezierPaths must be larger or equal in length to oldBezierPaths");

	CGRect invalidatedDisplayRect = CGRectNull;
	for (NSUInteger bezierPathIndex = 0; bezierPathIndex < [newBezierPaths count]; bezierPathIndex++) {
		BOOL isNewPath = bezierPathIndex >= [oldBezierPaths count];
		BOOL isChangedPath = !isNewPath && ![oldBezierPaths[bezierPathIndex] isEqual:newBezierPaths[bezierPathIndex]];
		if (isNewPath || isChangedPath) {
			CGRect currentRectToInvalidate = [newBezierPaths[bezierPathIndex] bounds];
			if (isChangedPath) {
				currentRectToInvalidate = CGRectUnion(currentRectToInvalidate, [oldBezierPaths[bezierPathIndex] bounds]);
			}

			if (CGRectIsNull(invalidatedDisplayRect)) {
				invalidatedDisplayRect = currentRectToInvalidate;
			} else {
				invalidatedDisplayRect = CGRectUnion(invalidatedDisplayRect, currentRectToInvalidate);
			}
		}
	}
	return invalidatedDisplayRect;
}

- (void)setPendingStroke:(KAScratchpadCanvasStroke *)pendingStroke {
	if (![_pendingStroke isEqual:pendingStroke]) {
		NSArray *newPathRepresentedBezierPaths = nil;

		// Calculate the union of all changed components' bounds.
		if (!pendingStroke && _pendingStroke) {
			[self setNeedsDisplayInRect:_boundsForBezierPaths(self.pendingStrokeCachedBezierPaths)];
		} else if (pendingStroke) {
			if (_pendingStroke) {
				newPathRepresentedBezierPaths = [self.pathPlotter representedBezierPathsForCanvasPath:pendingStroke.path byModifyingPreviousCanvasPath:_pendingStroke.path withRepresentedBezierPaths:self.pendingStrokeCachedBezierPaths];
				[self setNeedsDisplayInRect:_invalidatedDisplayRectForChangeInBezierPaths(self.pendingStrokeCachedBezierPaths, newPathRepresentedBezierPaths)];
			} else {
				newPathRepresentedBezierPaths = [self.pathPlotter representedBezierPathsForCanvasPath:pendingStroke.path];
				[self setNeedsDisplayInRect:_boundsForBezierPaths(newPathRepresentedBezierPaths)];
			}
		}

		_pendingStroke = pendingStroke;
		self.pendingStrokeCachedBezierPaths = newPathRepresentedBezierPaths;
	}
}

- (void)setCommittedStrokes:(NSArray *)committedStrokes {
	if (_committedStrokes != committedStrokes) {
		// Special case to optimize committing a single action:
		if ([committedStrokes count] == [_committedStrokes count] + 1 &&
			[[committedStrokes subarrayWithRange:NSMakeRange(0, [_committedStrokes count])] isEqualToArray:_committedStrokes]) {
			KAScratchpadCanvasStroke *newStroke = [committedStrokes lastObject];
			NSArray *newPathRepresentedBezierPaths = [self.pathPlotter representedBezierPathsForCanvasPath:newStroke.path];
			[self setNeedsDisplayInRect:_invalidatedDisplayRectForChangeInBezierPaths(self.pendingStrokeCachedBezierPaths, newPathRepresentedBezierPaths)];
			[self applyStrokeToCommittedStrokeCache:newStroke usingBezierPathCache:newPathRepresentedBezierPaths];
		} else {
			[self invalidateCommittedStrokeCache];
			[self setNeedsDisplay];
		}
		// TODO(andy): add special case for undo to only redraw the tile containing the undone stroke

		_committedStrokes = [committedStrokes copy];
	}
}

#pragma mark Rendering

static CGBlendMode _blendModeForRenderingMode(KAScratchpadRenderingMode renderingMode) {
	switch (renderingMode) {
		case KAScratchpadRenderingModeDraw:
			return kCGBlendModeNormal;
		case KAScratchpadRenderingModeErase:
			return kCGBlendModeClear;
		default:
			NSCAssert(false, @"Bad scratchpad rendering mode (%@)", KANSStringFromKAScratchpadRenderingMode(renderingMode));
			return 0;
	}
}

/// Draws the given stroke in the current context, optionally using bezierPathCache to improve performance.
- (void)drawStroke:(KAScratchpadCanvasStroke *)stroke usingBezierPathCache:(NSArray *)bezierPathCache {
	NSParameterAssert(stroke);

	[stroke.color setFill];
	CGContextSetBlendMode(UIGraphicsGetCurrentContext(), _blendModeForRenderingMode(stroke.renderingMode));

	NSArray *bezierPaths = bezierPathCache ?: [self.pathPlotter representedBezierPathsForCanvasPath:stroke.path];
	for (UIBezierPath *bezierPath in bezierPaths) {
		[bezierPath fill];
	}
}

// TODO(andy): cache stroke bezier path bounds--all these computations are getting expensive
static inline CGRect _boundsForBezierPaths(NSArray *bezierPaths) {
	CGRect bounds = CGRectNull;
	for (UIBezierPath *path in bezierPaths) {
		bounds = CGRectUnion(bounds, path.bounds);
	}
	return bounds;
}

- (void)drawRect:(CGRect)rect {
	if (!self.committedStrokeTileCache) {
		[self createCommittedStrokeCache];
	}

	[self drawCommittedStrokeCacheInRect:rect];

	if (self.pendingStroke) {
		[self drawStroke:self.pendingStroke usingBezierPathCache:self.pendingStrokeCachedBezierPaths];
	}
}

#pragma mark Committed Stroke Cache

- (void)invalidateCommittedStrokeCache {
	self.committedStrokeTileCache = nil;
}

- (void)createCommittedStrokeCache {
	NSAssert(!self.committedStrokeTileCache, @"Committed stroke tile cache already exists");
	__block CGRect boundsForAllPaths = CGRectZero;

	if ([self.committedStrokes count] > 0) {
		self.committedStrokeTileCache = [[KAScratchpadCanvasTileCache alloc] initWithTileSize:CGSizeMake(KAScratchpadCanvasViewTileSize, KAScratchpadCanvasViewTileSize) rasterizationScale:self.window.screen.scale];
		for (KAScratchpadCanvasStroke *stroke in self.committedStrokes) {
			NSArray *bezierPaths = [self.pathPlotter representedBezierPathsForCanvasPath:stroke.path];
			CGRect strokeBounds = _boundsForBezierPaths(bezierPaths);

			[self drawIntoCommittedStrokeCacheInRect:strokeBounds withBlock:^{
				[self drawStroke:stroke usingBezierPathCache:bezierPaths];
			}];

			if (stroke.renderingMode == KAScratchpadRenderingModeDraw) {
				boundsForAllPaths = CGRectUnion(boundsForAllPaths, strokeBounds);
			}
			// TODOX(kasra): if an eraser stroke, shrink boundsForAllPaths instead of just ignoring.
		}
	}

	self.drawingBounds = boundsForAllPaths;
}

- (void)applyStrokeToCommittedStrokeCache:(KAScratchpadCanvasStroke *)stroke usingBezierPathCache:(NSArray *)bezierPathCache {
	CGRect pathBounds = _boundsForBezierPaths(bezierPathCache);

	if (stroke.renderingMode == KAScratchpadRenderingModeDraw) {
		// Expand drawingBounds to include this new path.
		CGRect boundsForAllPaths = CGRectUnion(self.drawingBounds, pathBounds);

		// Only update if bounds changed to avoid unnecessary KVO notifications.
		if (!CGRectEqualToRect(self.drawingBounds, boundsForAllPaths)) {
			self.drawingBounds = boundsForAllPaths;
		}
	}
	// TODOX(kasra): if an eraser stroke, might need to shrink self.drawingBounds.

	if (self.committedStrokeTileCache) {
		[self drawIntoCommittedStrokeCacheInRect:pathBounds withBlock:^{
			[self drawStroke:stroke usingBezierPathCache:bezierPathCache];
		}];
	}
}

- (void)drawCommittedStrokeCacheInRect:(CGRect)rect {
	if (!self.committedStrokeTileCache) {
		return;
	}

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, kCGBlendModeCopy);
	[self.committedStrokeTileCache enumerateImagesForTilesInRect:rect withBlock:^(UIImage *cachedImage, CGRect tileRect) {
		[cachedImage drawInRect:tileRect];
	}];
	CGContextRestoreGState(context);
}

- (void)drawIntoCommittedStrokeCacheInRect:(CGRect)rect withBlock:(void (^)())drawingActions {
	NSAssert(self.committedStrokeTileCache, @"Committed stroke tile cache doesn't yet exist.");
	[self.committedStrokeTileCache drawIntoTilesInRect:rect withBlock:^(CGRect tileFrame) {
		drawingActions();
	}];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
	if (self.window.screen.scale != newWindow.window.screen.scale) {
		[self invalidateCommittedStrokeCache];
	}
}

@end
