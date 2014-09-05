//
//  KAScratchpadCanvasView.h
//  Khan Academy
//
//  Created by Kasra Kyanzadeh on 2014-06-11.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KAScratchpadCanvasStroke;

/**
 A view that efficiently renders strokes.

 Pending strokes are rendered expecting that they will change more frequently; committed strokes are cached to a bitmap.
 */
@interface KAScratchpadCanvasView : UIView

@property (nonatomic, strong, readwrite) KAScratchpadCanvasStroke *pendingStroke;
@property (nonatomic, strong, readwrite) NSArray *committedStrokes;

/// The rectangle starting at (0, 0) that contains all the committed strokes of the drawing.
@property (nonatomic, assign, readonly) CGRect drawingBounds;

@end
