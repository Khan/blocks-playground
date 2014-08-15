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

		let numberOfBlocks = 50
		let blocksPerRow = 12
		blocks = []
		blocks.reserveCapacity(numberOfBlocks)

		for i in 0..<numberOfBlocks {
			let row = CGFloat(i / blocksPerRow * 200 + 80)
			let blockView = UIView(frame: CGRectMake(25 + 60 * CGFloat(i % blocksPerRow), row, 20, 20))
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
					UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
						block.bounds = CGRectMake(0, 0, 35, 35)
					}, completion: nil)
				}
			}

			for i in 0..<draggingChain.count {
				let animation = animations[draggingChain[i]]!
				let indexDelta = i * (gesture.velocityInView(view).x > 0 ? -1 : 1)
				let separation = CGFloat(0.0)
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

			for i in 0..<draggingChain.count {
				if draggingChain.count < 10 {
					let animation = animations[draggingChain[i]]!
					let indexDelta = i - find(draggingChain, gesture.view)!
					let separation = CGFloat(20)
					let newToValue = CGPoint(x: gesture.view.center.x + CGFloat(indexDelta) * (separation + gesture.view.bounds.size.width), y: gesture.view.center.y)
					animation.toValue = NSValue(CGPoint: newToValue)
				}
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					self.draggingChain[i].bounds = CGRectMake(0, 0, 20, 20)
				}, completion: nil)
			}
		default:
			break
		}
	}

	func handleLift(gesture: UIGestureRecognizer) {
		switch gesture.state {
		case .Began:
			UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
				gesture.view.bounds = CGRectMake(0, 0, 40, 40)
			}, completion: nil)
			gesture.view.layer.zPosition = 100
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

