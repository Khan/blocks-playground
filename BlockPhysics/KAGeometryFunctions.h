//
//  KAGeometryFunctions.h
//  Khan Academy
//
//  Created by Laura Savino on 5/13/13.
//  Copyright (c) 2013 Khan Academy. All rights reserved.
//

#import <Foundation/Foundation.h>

CGRect kha_CGRectCenteredInRect(CGRect parentRect, CGRect rectToCenter);
CGRect kha_CGRectVerticallyCenteredInRect(CGRect parentRect, CGRect rectToCenter);
CGRect kha_CGRectHorizontallyCenteredInRect(CGRect parentRect, CGRect rectToCenter);

/** @return the given CGPoint with its x and y values rounded to the nearest integers */
CGPoint kha_CGPointIntegral(CGPoint point);

/** @return the Cartesian distance between `a` and `b`. */
CGFloat kha_CGPointDistance(CGPoint a, CGPoint b);

/** @return the Cartesian magnitude of `point`. */
CGFloat kha_CGPointMagnitude(CGPoint point);
