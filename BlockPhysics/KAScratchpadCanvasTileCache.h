//
//  KAScratchpadCanvasTileCache.h
//  Khan Academy
//
//  Created by Andy Matuschak on 8/6/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

/**
 A sparse cache of bitmap tiles. Clients can draw and read from arbitrary regions; the cache will map these operations onto tiles behind the scenes.
 */
@interface KAScratchpadCanvasTileCache : NSObject

- (instancetype)initWithTileSize:(CGSize)tileSize rasterizationScale:(CGFloat)rasterizationScale;

/// Calls `block` for each tile intersecting `rect` (specified in point-space) that has been drawn into.
- (void)enumerateImagesForTilesInRect:(CGRect)rect withBlock:(void (^)(UIImage *cachedImage, CGRect tileRect))block __attribute__((nonnull(2)));

/**
 Calls `drawingBlock` for each tile intersecting `rect`.
 
 During the execution of `drawingBlock`, `UIGraphicsGetCurrentContext()` will return a context configured for drawing into that tile.
 */
- (void)drawIntoTilesInRect:(CGRect)rect withBlock:(void (^)(CGRect tileRect))drawingBlock __attribute__((nonnull(2)));

/// The size of each cached tile in points.
@property (nonatomic, assign, readonly) CGSize tileSize;

/// The bitmap scale at which each tile's cache should be rasterized (think: -[CALayer rasterizationScale]).
@property (nonatomic, assign, readonly) CGFloat rasterizationScale;

#if KHAN_DEBUG
/// When YES, fills the background of each tile with a different color. Only affects tiles created after set to YES. Default: NO.
@property (nonatomic, assign, readwrite) BOOL drawsTileDebugBackgrounds;
#endif

- (instancetype)init __attribute__((unavailable("Use -initWithTileSize:rasterizationScale: instead")));
@end

// TODO(andy): implement cache volatility and lazy regeneration
// TODO(andy): implement high water mark (only permit so much tile surface area)
// TODO(andy): vacate cache under pressure
