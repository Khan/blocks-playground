//
//  KAScratchpadDrawing.h
//  Khan Academy
//
//  Created by Andy Matuschak on 7/8/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

/// The tools available for selection by the user.
typedef NS_ENUM(NSUInteger, KAScratchpadToolType) {
    KAScratchpadToolTypePen,
    KAScratchpadToolTypeEraser,
};
NSString *KANSStringFromKAScratchpadToolType(KAScratchpadToolType toolType);

@class KAScratchpadDrawingAction, KAScratchpadDrawingTouchSample;

/// Root data model for drawings. Separately manages pending and committed actions so that pending actions can be rendered more efficiently.
@interface KAScratchpadDrawing : NSObject
- (instancetype)initWithCommittedActions:(NSArray *)committedActions pendingAction:(KAScratchpadDrawingAction *)pendingAction __attribute__((nonnull(1)));
@property (nonatomic, strong, readonly) NSArray *committedActions; ///< Array of KAScratchpadDrawingActions that is expected to change less frequently than the pending action.
@property (nonatomic, strong, readonly) KAScratchpadDrawingAction *pendingAction; ///< An action which is expected to change more frequently.

+ (KAScratchpadDrawing *)emptyDrawing; ///< Returns a drawing with no committed or pending actions.
- (instancetype)drawingByCommittingPendingAction; ///< Returns a drawing with the pending action applied to the list of committed actions.
- (instancetype)drawingByDiscardingPendingAction; ///< Returns a drawing without a pending action.
- (instancetype)drawingByDiscardingMostRecentlyCommittedAction; ///< Returns a drawing without the most recently committed action.

- (instancetype)init __attribute__((unavailable("Use -initWithCommittedActions:pendingAction: instead")));
@end


/// Describes a single action in a drawing. Each distinct series of touch events (delimited by the touch ending) has its own action.
@interface KAScratchpadDrawingAction : NSObject
- (instancetype)initWithTouchSamples:(NSArray *)touchSamples toolType:(KAScratchpadToolType)toolType color:(UIColor *)color __attribute__((nonnull(1,3)));
@property (nonatomic, strong, readonly) NSArray *touchSamples; ///< Array of KAScratchpadDrawingTouchSamples.
@property (nonatomic, assign, readonly) KAScratchpadToolType toolType; ///< The tool type that was selected when this action was performed.
@property (nonatomic, strong, readonly) UIColor *color; ///< The color that was selected when this action was performed.

- (instancetype)actionByAppendingTouchSample:(KAScratchpadDrawingTouchSample *)touchSample __attribute__((nonnull(1))); ///< Returns a new action with `touchSample` at the end of the `touchSamples` list.

- (instancetype)init __attribute__((unavailable("Use -initWithTouchSamples:toolType:color: instead")));
@end


/// Describes a single touch sample.
@interface KAScratchpadDrawingTouchSample : NSObject
- (instancetype)initWithLocation:(CGPoint)location timestamp:(NSTimeInterval)timestamp;
@property (nonatomic, assign, readonly) CGPoint location; ///< The touch's location, represented in the coordinate space which will be used to render the result of that touch.
@property (nonatomic, assign, readonly) NSTimeInterval timestamp; ///< The touch's timestamp.

- (CGPoint)estimatedVelocityGivenPreviousTouchSample:(KAScratchpadDrawingTouchSample *)previousTouchSample __attribute__((nonnull(1))); ///< Crudely estimates the velocity using these two touch samples: distance over time.

- (instancetype)init __attribute__((unavailable("Use -initWithLocation:timestamp: instead")));
@end
