//
//  KAScratchpadCanvasStroke.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/8/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

typedef NS_ENUM(NSUInteger, KAScratchpadRenderingMode) {
    KAScratchpadRenderingModeDraw,
    KAScratchpadRenderingModeErase,
};
NSString *KANSStringFromKAScratchpadRenderingMode(KAScratchpadRenderingMode renderingMode);

@class KAScratchpadCanvasPath;

/// Contains all the data needed to render a given stroke (a continuous sequence of touches representing one inking path) on a canvas.
@interface KAScratchpadCanvasStroke : NSObject

- (instancetype)initWithPath:(KAScratchpadCanvasPath *)path color:(UIColor *)color renderingMode:(KAScratchpadRenderingMode)renderingMode __attribute__((nonnull(1,2)));

@property (nonatomic, strong, readonly) KAScratchpadCanvasPath *path; ///< The path describing the geometry of this stroke.
@property (nonatomic, strong, readwrite) UIColor *color; ///< The color to use when rendering this stroke.
@property (nonatomic, assign, readwrite) KAScratchpadRenderingMode renderingMode; ///< The rendering mode to use when rasterizing this stroke.

- (instancetype)init __attribute__((unavailable("Use -initWithPath:color:renderingMode: instead")));

@end
