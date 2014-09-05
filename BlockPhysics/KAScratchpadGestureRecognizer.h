//
//  KAScratchpadGestureRecognizer.h
//  Khan Academy
//
//  Created by Kasra Kyanzadeh on 2014-06-10.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

/**
 A gesture recognizer used for drawing on the scratchpad.
 
 The only thing special about it is that it only works with
 exactly one touch. If the user ever touches with more than
 one finger, the gesture recognizer will cancel.
 */
@interface KAScratchpadGestureRecognizer : UIGestureRecognizer

@property (nonatomic, strong, readonly) UITouch *activeTouch;

/** Returns the velocity vector of the gesture's touch in pts/sec in the view. */
- (CGPoint)velocityInView:(UIView *)view;

/** If the gesture recognizer is recognizing, moves it to the cancelled state. */
- (void)cancelRecognition;

@end
