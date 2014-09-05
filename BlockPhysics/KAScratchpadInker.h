//
//  KAScratchpadInker.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/9/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KAScratchpadCanvasStroke, KAScratchpadDrawingAction;

/// The inker transforms a drawing action into a stroke suitable for rendering.
@interface KAScratchpadInker : NSObject
// TODO(andy): make parameterizable

/// Computes a stroke from a drawing action.
- (KAScratchpadCanvasStroke *)inkedStrokeForDrawingAction:(KAScratchpadDrawingAction *)drawingAction isCommitted:(BOOL)drawingIsCommitted __attribute__((nonnull(1)));

@end
