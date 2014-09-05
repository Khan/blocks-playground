//
//  KAScratchpadCanvasPathPlotter.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/14/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

@class KAScratchpadCanvasPath;

/// Creates bezier path representations out of `KAScratchpadCanvasPath`s, suitable for rendering with CoreGraphics.
@interface KAScratchpadCanvasPathPlotter : NSObject

/// Returns bezier paths which will depict `canvasPath` when rasterized.
- (NSArray *)representedBezierPathsForCanvasPath:(KAScratchpadCanvasPath *)canvasPath __attribute__((nonnull(1)));

/// Returns bezier paths which will depict `canvasPath` when rasterized, minimizing computation by reusing a previous bezier path representation for a previous canvas path. When `previousCanvasPath` is a prefix of `canvasPath`, only the new bezier paths will be generated.
- (NSArray *)representedBezierPathsForCanvasPath:(KAScratchpadCanvasPath *)canvasPath byModifyingPreviousCanvasPath:(KAScratchpadCanvasPath *)previousCanvasPath withRepresentedBezierPaths:(NSArray *)previousCanvasPathRepresentedBezierPaths __attribute__((nonnull(1,2,3)));
@end
