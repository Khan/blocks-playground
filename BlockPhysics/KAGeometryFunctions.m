//
//  KAGeometryFunctions.m
//  Khan Academy
//
//  Created by Laura Savino on 5/13/13.
//  Copyright (c) 2013 Khan Academy. All rights reserved.
//

#import "KAGeometryFunctions.h"

CGRect kha_CGRectCenteredInRect(CGRect parentRect, CGRect rectToCenter) {
	CGFloat x = (parentRect.size.width - rectToCenter.size.width) / 2 + parentRect.origin.x;
	CGFloat y = (parentRect.size.height - rectToCenter.size.height) / 2 + parentRect.origin.y;

	CGRect centeredRect = CGRectMake(x, y, rectToCenter.size.width, rectToCenter.size.height);

	return CGRectIntegral(centeredRect);
}

CGRect kha_CGRectVerticallyCenteredInRect(CGRect parentRect, CGRect rectToCenter) {
	
	CGFloat y = (parentRect.size.height - rectToCenter.size.height) / 2 + parentRect.origin.y;

	CGRect centeredRect = rectToCenter;
	centeredRect.origin.y = y;

	return CGRectIntegral(centeredRect);
}

CGRect kha_CGRectHorizontallyCenteredInRect(CGRect parentRect, CGRect rectToCenter) {

	CGFloat x = (parentRect.size.width - rectToCenter.size.width) / 2 + parentRect.origin.x;

	CGRect centeredRect = rectToCenter;
	centeredRect.origin.x = x;

	return CGRectIntegral(centeredRect);
}

CGPoint kha_CGPointIntegral(CGPoint point) {
	return CGPointMake(roundf(point.x), roundf(point.y));
}

CGFloat kha_CGPointDistance(CGPoint a, CGPoint b) {
	return sqrt(pow((a.x - b.x), 2) + pow((a.y - b.y), 2));
}

CGFloat kha_CGPointMagnitude(CGPoint point) {
	return sqrt(point.x * point.x + point.y * point.y);
}
