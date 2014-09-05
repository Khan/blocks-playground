//
//  KAScratchpadViewController.h
//  Khan Academy
//
//  Created by Kasra Kyanzadeh on 2014-06-07.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

// TODO(kasra): decouple the scratchpad and the web view.

@class KAScratchpadViewController;

/**
 Provides the exercise scratchpad.

 Contains a web view and allows the user to draw on top
 of the web view contents.
 */
@interface KAScratchpadViewController : UIViewController

/** The web view that's behind the scratchpad (shows exercise contents). */
@property (nonatomic, strong, readwrite) UIWebView *backgroundWebView;

/** Touches originating in these edge insets will be ignored. */
@property (nonatomic, assign, readwrite) UIEdgeInsets ignoreTouchEdgeInsets;

@end
