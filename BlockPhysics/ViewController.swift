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

	var animations: [UIView: POPSpringAnimation] = [:]

	var draggingChain: [UIView] = []

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

		for i in 0..<(numberOfBlocks) {
			let springAnimation = POPSpringAnimation(propertyNamed: kPOPLayerPosition)
			var toPoint: CGPoint = blocks[i].center
			springAnimation.toValue = NSValue(CGPoint: toPoint)
			springAnimation.removedOnCompletion = false;
			animations[blocks[i]] = springAnimation
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
		let blockIndex = find(blocks, gesture.view)!
		switch gesture.state {
		case .Began:
			draggingChain = [gesture.view]
			gesture.view.pop_removeAnimationForKey("position")
		case .Changed:
			let translation = gesture.translationInView(view)
			gesture.setTranslation(CGPoint(), inView: view)
			gesture.view.center.x += translation.x
			gesture.view.center.y += translation.y

			let draggingBlockIndexInChain = find(draggingChain, gesture.view)!
			for block in blocks {
				if !contains(draggingChain, block) && CGRectIntersectsRect(gesture.view.frame, block.frame) {
					draggingChain.insert(block, atIndex:1)
				}
			}

			for i in 0..<draggingChain.count {
				let animation = animations[draggingChain[i]]!
				let indexDelta = i * (gesture.velocityInView(view).x > 0 ? -1 : 1)
				let separation = CGFloat(2.0)
				let newToValue = CGPoint(x: gesture.view.center.x + CGFloat(indexDelta) * (separation + gesture.view.bounds.size.width), y: gesture.view.center.y)
				animation.toValue = NSValue(CGPoint: newToValue)
				animation.springSpeed = 80 - 8.0 * CGFloat(abs(indexDelta))
				animation.springBounciness = 0 + 2 * CGFloat(abs(indexDelta))
			}
		case .Ended:
			let animation = animations[blocks[blockIndex]]!
			animation.toValue = NSValue(CGPoint: blocks[blockIndex].center)
			animation.fromValue = animation.toValue
			gesture.view.pop_addAnimation(animation, forKey: "position")

			if draggingChain.count < 10 {
				for i in 0..<draggingChain.count {
					let animation = animations[draggingChain[i]]!
					let indexDelta = i - find(draggingChain, gesture.view)!
					let separation = CGFloat(25.0)
					let newToValue = CGPoint(x: gesture.view.center.x + CGFloat(indexDelta) * (separation + gesture.view.bounds.size.width), y: gesture.view.center.y)
					animation.toValue = NSValue(CGPoint: newToValue)
				}
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

