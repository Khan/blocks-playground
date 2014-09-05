//
//  KAScratchpadBrush.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/9/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAScratchpadCanvasStroke.h"

@class KAScratchpadCanvasPath;

/// Brushes describe the transformation from a sequence of touches to the path geometry that will be used to render the result of those touches.
@protocol KAScratchpadBrush <NSObject>

/**
 * Given a list of touch samples, returns a canvas path describing the represented geometry.
 *
 * @param touchSamples Must contain at least one sample.
 */
- (KAScratchpadCanvasPath *)pathForTouchSamples:(NSArray *)touchSamples isCommitted:(BOOL)isCommitted __attribute__((nonnull(1)));

@property (readonly, nonatomic) KAScratchpadRenderingMode renderingMode; ///< The rendering mode that should be used when drawing this brush's paths.

@end


/// Creates precise inking lines.
@interface KAScratchpadPenBrush : NSObject <KAScratchpadBrush>
@property (readwrite, assign, nonatomic) CGFloat lineWidth; ///< The width of the line to ink.
@property (readwrite, assign, nonatomic) CGFloat dotWidth; ///< The width of the dot to ink when the touch was lifted at the same place it arrived.
@end


/// Creates wide eraser marks.
@interface KAScratchpadEraserBrush : NSObject <KAScratchpadBrush>
// TODO(andy): more parameterizable
@end
