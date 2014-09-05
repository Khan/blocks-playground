//
//  KAScratchpadViewController.m
//  Khan Academy
//
//  Created by Kasra Kyanzadeh on 2014-06-07.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

#import "KAScratchpadViewController.h"

#import "KAScratchpadGestureRecognizer.h"
#import "KAScratchpadCanvasView.h"
#import "KAScratchpadDrawing.h"
#import "KAScratchpadInker.h"
#import "NSArray+KHAExtensions.h"

@interface KAScratchpadViewController () <UIGestureRecognizerDelegate, UIScrollViewDelegate>

@property (nonatomic, strong, readwrite) KAScratchpadDrawing *drawing;
@property (nonatomic, strong, readwrite) KAScratchpadInker *inker;

@property (nonatomic, strong, readwrite) UIColor *drawingColor; ///< New drawing actions will use this color.

@property (nonatomic, strong) KAScratchpadCanvasView *canvasView;

// Keep track of the canvas view frame for a smooth rotation animation.
@property (nonatomic, assign) CGRect canvasViewFrameBeforeRotation;
@property (nonatomic, assign) CGRect canvasViewFrameAfterRotation;

@property (nonatomic, assign, readwrite) BOOL canUndo;

// Contains the grid background when scratchpad is active. A separate view is used (as opposed to setting backgroundWebView.backgroundColor) so we can fade the grid in/out.
@property (nonatomic, strong) UIView *scratchpadBackgroundView;

@property (nonatomic, strong) KAScratchpadGestureRecognizer *dragRecognizer;

/// The drawing action corresponding to the current touch. nil if dragRecognizer is not recognizing.
@property (nonatomic, strong) KAScratchpadDrawingAction *currentDrawingAction;

@end

@implementation KAScratchpadViewController

@synthesize canUndo = _canUndo;

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.multipleTouchEnabled = YES;
	self.view.backgroundColor = [UIColor whiteColor];

	self.dragRecognizer = [[KAScratchpadGestureRecognizer alloc] initWithTarget:self action:@selector(didDrag:)];
	self.dragRecognizer.delegate = self;
	[self.view addGestureRecognizer:self.dragRecognizer];

	self.drawingColor = [UIColor darkGrayColor];
	self.drawing = [KAScratchpadDrawing emptyDrawing];
	self.inker = [KAScratchpadInker new];
}

- (void)loadView {
	[super loadView];

	// The scratchpad canvas sits on top of the web view and has its bounds origin shifted to match the web view's.
	self.canvasView = [KAScratchpadCanvasView new];
	self.canvasView.frame = self.view.bounds;
	self.canvasView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.canvasView];
	self.canvasView.userInteractionEnabled = NO; // The canvas view itself is not interactive: our gesture recognizer modifies the drawing it displays.
}

- (void)resetCanvas {
	self.drawing = [KAScratchpadDrawing emptyDrawing];
}

- (void)undo {
	self.drawing = [self.drawing drawingByDiscardingMostRecentlyCommittedAction];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	// Keep the contentOffset of the web view's scroll view and our canvas in sync
	NSAssert(scrollView == self.backgroundWebView.scrollView, @"Expected background web view's scroll view %@ but got %@", self.backgroundWebView.scrollView, scrollView);
	self.scratchpadBackgroundView.bounds = (CGRect){scrollView.contentOffset, self.scratchpadBackgroundView.bounds.size};
	self.canvasView.bounds = (CGRect){scrollView.contentOffset, self.canvasView.bounds.size};
	[self.canvasView setNeedsDisplay];
}

- (void)setDrawing:(KAScratchpadDrawing *)drawing {
	if (![_drawing isEqual:drawing]) {
		self.canUndo = ([drawing.committedActions count] > 0);

		self.canvasView.pendingStroke = drawing.pendingAction ? [self.inker inkedStrokeForDrawingAction:drawing.pendingAction isCommitted:NO] : nil;

		if (![_drawing.committedActions isEqual:drawing.committedActions]) {
			self.canvasView.committedStrokes = [drawing.committedActions kha_mappedArrayUsingBlock:^id(KAScratchpadDrawingAction *action, NSUInteger idx, BOOL *stop) {
				return [self.inker inkedStrokeForDrawingAction:action isCommitted:YES];
			}];
		}

		_drawing = drawing;
	}
}

#pragma mark - Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	self.canvasViewFrameBeforeRotation = self.canvasView.frame;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	// While the rotation animation is taking place, set the frame of the canvas view so it's the union
	// of the landscape and portrait frames. This ensures that no clipping of scratchpad contents occurs
	// during the rotation. After the rotation is done, we set the frame to `canvasViewFrameAfterRotation`.
	self.canvasViewFrameAfterRotation = self.canvasView.frame;
	CGFloat maxWidth = MAX(CGRectGetWidth(self.canvasViewFrameBeforeRotation),
						   CGRectGetWidth(self.canvasViewFrameAfterRotation));
	CGFloat maxHeight = MAX(CGRectGetHeight(self.canvasViewFrameBeforeRotation),
							CGRectGetHeight(self.canvasViewFrameAfterRotation));
	self.canvasView.frame = CGRectMake(0, 0, maxWidth, maxHeight);
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	self.canvasView.frame = self.canvasViewFrameAfterRotation;
}

#pragma mark - Gesture recognizer

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	NSAssert(gestureRecognizer == self.dragRecognizer, @"Expected drag recognizer %@ but got %@", self.dragRecognizer, gestureRecognizer);

	CGRect touchableBounds = UIEdgeInsetsInsetRect(self.view.bounds, self.ignoreTouchEdgeInsets);
	return CGRectContainsPoint(touchableBounds, [touch locationInView:self.view]);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	// The scratchpad drawing gesture recognizer should always recognize.
	return (gestureRecognizer == self.dragRecognizer);
}

- (void)cleanUpCurrentDrawingAction {
	self.currentDrawingAction = nil;
}

- (void)discardCurrentDrawingAction {
	self.drawing = [self.drawing drawingByDiscardingPendingAction];

	// Remove this drawing action if it's in pendingDrawingActions.
	[self cleanUpCurrentDrawingAction];
}

- (void)createNewCurrentDrawingActionWithRecognizer:(UIGestureRecognizer *)recognizer {
	self.currentDrawingAction = [[KAScratchpadDrawingAction alloc] initWithTouchSamples:@[] toolType:KAScratchpadToolTypePen color:self.drawingColor];
}

- (void)appendToCurrentDrawingActionTouchSampleFromRecognizer:(KAScratchpadGestureRecognizer *)recognizer {
	KAScratchpadDrawingTouchSample *touchSample = [[KAScratchpadDrawingTouchSample alloc] initWithLocation:[recognizer.activeTouch locationInView:self.canvasView] timestamp:recognizer.activeTouch.timestamp];
	self.currentDrawingAction = [self.currentDrawingAction actionByAppendingTouchSample:touchSample];

	BOOL commitDrawingAction = recognizer.state == UIGestureRecognizerStateEnded;

	// Render the updated currentDrawingAction
	[self updateDrawingWithPendingAction:self.currentDrawingAction commitDrawingAction:commitDrawingAction];
}

- (void)didDrag:(KAScratchpadGestureRecognizer *)recognizer {
	NSAssert(recognizer == self.dragRecognizer, @"Expected drag recognizer %@ but got %@", self.dragRecognizer, recognizer);
	NSAssert(self.drawingColor, @"Set line color before attempting to draw on scratchpad");

	if (recognizer.state == UIGestureRecognizerStateCancelled) {
		[self discardCurrentDrawingAction];
	} else {
		if (recognizer.state == UIGestureRecognizerStateBegan) {
			[self createNewCurrentDrawingActionWithRecognizer:recognizer];
		}

		[self appendToCurrentDrawingActionTouchSampleFromRecognizer:recognizer];

		if (recognizer.state == UIGestureRecognizerStateEnded) {
			[self cleanUpCurrentDrawingAction];
		}
	}
}

- (void)updateDrawingWithPendingAction:(KAScratchpadDrawingAction *)action commitDrawingAction:(BOOL)commitDrawingAction {
	KAScratchpadDrawing *drawing = [[KAScratchpadDrawing alloc] initWithCommittedActions:self.drawing.committedActions pendingAction:action];

	if (commitDrawingAction) {
		drawing = [drawing drawingByCommittingPendingAction];
	}

	self.drawing = drawing;

}

@end
