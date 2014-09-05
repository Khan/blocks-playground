//
//  KAScratchpadCanvasTileCache.m
//  Khan Academy
//
//  Created by Andy Matuschak on 8/6/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAScratchpadCanvasTileCache.h"

@interface KAScratchpadCanvasTileCache ()

/// Sparsely maps NSIndexPaths representing tile coordinates to CGBitmapContextRefs.
@property (nonatomic, strong, readonly) NSMutableDictionary *indexPathsToBitmapContexts;

/**
 Sparsely maps NSIndexPaths representing tile coordinates to UIImage caches of the corresponding contexts.

 The keys of this dictionary will be a subset of the keys of `indexPathsToBitmapContexts`: whenever a
 context changes, the corresponding UIImage is cleared. It's regenerated on demand.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *indexPathsToUIImages;

@end

@implementation KAScratchpadCanvasTileCache
- (instancetype)initWithTileSize:(CGSize)tileSize rasterizationScale:(CGFloat)rasterizationScale {
	self = [super init];
	if (!self) {
		return nil;
	}

	NSAssert(tileSize.width > 0, @"non-positive tile width");
	NSAssert(tileSize.height > 0, @"non-positive tile width");
	NSAssert(rasterizationScale > 0, @"non-positive rasterization scale");

	_tileSize = tileSize;
	_rasterizationScale = rasterizationScale;
	_indexPathsToBitmapContexts = [NSMutableDictionary new];
	_indexPathsToUIImages = [NSMutableDictionary new];
	return self;
}

/// Calls `block` once for every tile intersecting `rect`, passing the index path for each tile along.
static void _enumerateTileIndexPathsWithBlock(CGRect rect, CGSize tileSize, void (^block)(NSIndexPath *indexPath)) {
	// We only support positive rects:
	rect = CGRectStandardize(rect);
	if (rect.origin.x < 0) {
		rect.size.width += rect.origin.x;
		rect.origin.x = 0;
	}
	if (rect.origin.y < 0) {
		rect.size.height += rect.origin.y;
		rect.origin.y = 0;
	}

	NSUInteger minimumTileXIndex = floor(CGRectGetMinX(rect) / tileSize.width);
	NSUInteger minimumTileYIndex = floor(CGRectGetMinY(rect) / tileSize.height);
	NSUInteger boundForTileXIndex = ceil(CGRectGetMaxX(rect) / tileSize.width);
	NSUInteger boundForTileYIndex = ceil(CGRectGetMaxY(rect) / tileSize.height);
	for (CGFloat i = minimumTileXIndex; i < boundForTileXIndex; i++) {
		for (CGFloat j = minimumTileYIndex; j < boundForTileYIndex; j++) {
			block([NSIndexPath indexPathWithIndexes:(NSUInteger []){i, j} length:2]);
		}
	}
}

static inline CGRect _tileFrameForIndexPath(NSIndexPath *indexPath, CGSize tileSize) {
	return CGRectMake([indexPath indexAtPosition:0] * tileSize.width, [indexPath indexAtPosition:1] * tileSize.height, tileSize.width, tileSize.height);
}

- (void)enumerateImagesForTilesInRect:(CGRect)rect withBlock:(void (^)(UIImage *cachedImage, CGRect tileFrame))block {
	_enumerateTileIndexPathsWithBlock(rect, self.tileSize, ^(NSIndexPath *indexPath) {
		UIImage *tileImage = self.indexPathsToUIImages[indexPath];
		if (!tileImage) {
			CGContextRef context = (__bridge CGContextRef)self.indexPathsToBitmapContexts[indexPath];
			if (context) {
				CGImageRef tileCGImage = CGBitmapContextCreateImage(context);
				NSCAssert(tileCGImage, @"failed to create tile cache image from bitmap context");
				tileImage = [UIImage imageWithCGImage:tileCGImage scale:self.rasterizationScale orientation:UIImageOrientationUp];
				self.indexPathsToUIImages[indexPath] = tileImage;
				CGImageRelease(tileCGImage);
			}
		}

		if (tileImage) {
			block(tileImage, _tileFrameForIndexPath(indexPath, self.tileSize));
		}
	});
}

static CGContextRef _createBitmapContext(CGSize contextSizeInPoints, CGFloat rasterizationScale) {
	CGFloat numberOfColumns = contextSizeInPoints.width * rasterizationScale;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSCAssert(colorSpace, @"Couldn't create color space.");
	CGContextRef outputBitmap = CGBitmapContextCreate(NULL,                                            /* means: please manage the data buffer for me */
													  numberOfColumns,                                 /* width */
													  contextSizeInPoints.height * rasterizationScale, /* height */
													  8,                                               /* bits per component */
													  numberOfColumns * 4,                             /* bytes per row */
													  colorSpace,                                      /* color space */
													  kCGImageAlphaPremultipliedFirst                  /* bitmap attributes */
													  );
	NSCAssert(outputBitmap, @"Couldn't create bitmap context.");
	CGColorSpaceRelease(colorSpace);
	return outputBitmap;
}

/// Maps CG's coordinate space to UIKit's.
static void _configureTiledContextCTM(CGContextRef context, CGRect tileFrame, CGFloat rasterizationScale) {
	// Flip the bitmap:
	CGContextTranslateCTM(context, 0, CGRectGetHeight(tileFrame) * rasterizationScale);
	CGContextScaleCTM(context, rasterizationScale, -1.0 * rasterizationScale);

	// And translate it into its tile position:
	CGContextTranslateCTM(context, -1.0 * CGRectGetMinX(tileFrame), -1.0 * CGRectGetMinY(tileFrame));
}

- (void)drawIntoTilesInRect:(CGRect)rect withBlock:(void (^)(CGRect tileFrame))drawingBlock {
	_enumerateTileIndexPathsWithBlock(rect, self.tileSize, ^(NSIndexPath *indexPath) {
		CGRect tileFrame = _tileFrameForIndexPath(indexPath, self.tileSize);
		CGContextRef context = (__bridge CGContextRef)self.indexPathsToBitmapContexts[indexPath];

#if KHAN_DEBUG
		BOOL shouldDrawDebugBackground = self.drawsTileDebugBackgrounds && !context;
#endif
		if (!context) {
			context = _createBitmapContext(self.tileSize, self.rasterizationScale);
			self.indexPathsToBitmapContexts[indexPath] = CFBridgingRelease(context);
			_configureTiledContextCTM(context, tileFrame, self.rasterizationScale);
		}

		UIGraphicsPushContext(context);
#if KHAN_DEBUG
		if (shouldDrawDebugBackground) {
			CGFloat debugHue = 0.1 * [indexPath indexAtPosition:0];
			CGFloat debugBrightness = 1.0 - 0.1 * [indexPath indexAtPosition:1];
			[[UIColor colorWithHue:debugHue saturation:0.8 brightness:debugBrightness alpha:1.0] set];
			UIRectFill(tileFrame);
		}
#endif
		drawingBlock(tileFrame);
		UIGraphicsPopContext();

		// Invalidate the UIImage cache of this tile:
		[self.indexPathsToUIImages removeObjectForKey:indexPath];
	});
}

@end
