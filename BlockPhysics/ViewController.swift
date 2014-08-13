//
//  ViewController.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/12/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
	var blocks: [UIView] = []

	var panGesture: UIPanGestureRecognizer! = nil
	var liftGesture: UILongPressGestureRecognizer! = nil

	var animations: [POPSpringAnimation] = []

	override func loadView() {
		super.loadView()
		view.backgroundColor = UIColor.whiteColor()

		let numberOfBlocks = 10
		blocks = []
		blocks.reserveCapacity(numberOfBlocks)

		for i in 0..<numberOfBlocks {
			let blockView = UIView(frame: CGRect(x: 25 + 75 * i, y: 200, width: 50, height: 50))
			blockView.backgroundColor = UIColor(white: 0.9, alpha: 1)
			blockView.layer.borderColor = UIColor(white: 0.7, alpha: 1).CGColor
			blockView.layer.borderWidth = 1
			blocks.append(blockView)
			view.addSubview(blockView)

			let panGesture = UIPanGestureRecognizer(target: self, action: "handlePan:")
			panGesture.delegate = self
			blockView.addGestureRecognizer(panGesture)

			let liftGesture = UILongPressGestureRecognizer(target: self, action: "handleLift:")
			liftGesture.minimumPressDuration = 0
			liftGesture.delegate = self
			blockView.addGestureRecognizer(liftGesture)
		}

		for i in 0..<(numberOfBlocks-1) {
			let springAnimation = POPSpringAnimation(propertyNamed: kPOPLayerPosition)
			var toPoint: CGPoint = blocks[i].center
			springAnimation.springSpeed = 20 + 4.0 * CGFloat(i)
			springAnimation.springBounciness = 15.0 - 1.0 * CGFloat(i)
			springAnimation.toValue = NSValue(CGPoint: toPoint)
			springAnimation.removedOnCompletion = false;
			animations.append(springAnimation)
			blocks[i].pop_addAnimation(springAnimation, forKey: "position")
		}

	}

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldReceiveTouch touch: UITouch!) -> Bool {
		return contains(blocks, touch.view)
	}

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer!) -> Bool {
		return (gestureRecognizer.isKindOfClass(UIPanGestureRecognizer.self) && otherGestureRecognizer.isKindOfClass(UILongPressGestureRecognizer.self)) ||
			(gestureRecognizer.isKindOfClass(UILongPressGestureRecognizer.self) && otherGestureRecognizer.isKindOfClass(UIPanGestureRecognizer.self))
	}

	func handlePan(gesture: UIPanGestureRecognizer) {
		let gestureLocation = gesture.locationInView(view)
		switch gesture.state {
		case .Changed:
			let translation = gesture.translationInView(view)
			gesture.setTranslation(CGPoint(), inView: view)
			gesture.view.center.x += translation.x
			gesture.view.center.y += translation.y
			for springAnimation in animations {
				var newToValue = springAnimation.toValue.CGPointValue()
				newToValue.x += translation.x
				newToValue.y += translation.y
				springAnimation.toValue = NSValue(CGPoint: newToValue)
			}
		default:
			break
		}
	}

	func handleLift(gesture: UIGestureRecognizer) {
		switch gesture.state {
		case .Began:
			UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
				gesture.view.transform = CGAffineTransformMakeScale(1.25, 1.25)
			}, completion: nil)
			gesture.view.layer.zPosition = 1
		case .Ended:
			UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
				gesture.view.transform = CGAffineTransformIdentity
				}, completion: nil)
			gesture.view.layer.zPosition = 0
		default:
			break
		}
	}
}

