//
//  KAScratchpadInker.m
//  Khan Academy
//
//  Created by Andy Matuschak on 7/9/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAScratchpadBrush.h"
#import "KAScratchpadCanvasStroke.h"
#import "KAScratchpadDrawing.h"
#import "KAScratchpadInker.h"

@implementation KAScratchpadInker

+ (NSDictionary *)defaultBrushTable {
	// TODO(andy): make brush table parameterizable
	KAScratchpadPenBrush *penBrush = [[KAScratchpadPenBrush alloc] init];
	penBrush.lineWidth = 2.0;
	penBrush.dotWidth = 4.0;
	return @{ @(KAScratchpadToolTypePen):    penBrush,
			  @(KAScratchpadToolTypeEraser): [KAScratchpadEraserBrush new] };
}

- (KAScratchpadCanvasStroke *)inkedStrokeForDrawingAction:(KAScratchpadDrawingAction *)drawingAction isCommitted:(BOOL)drawingIsCommitted {
	NSParameterAssert(drawingAction);
	id <KAScratchpadBrush> brush = [[self class] defaultBrushTable][@(drawingAction.toolType)];
	return [[KAScratchpadCanvasStroke alloc] initWithPath:[brush pathForTouchSamples:drawingAction.touchSamples isCommitted:drawingIsCommitted]
													color:drawingAction.color
											renderingMode:brush.renderingMode];
}

@end
