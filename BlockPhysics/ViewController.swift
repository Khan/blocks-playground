//
//  ViewController.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/12/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import UIKit

let spec = KFTunableSpec.specNamed("Blocks") as KFTunableSpec

class ViewController: UIViewController, UIGestureRecognizerDelegate {
	var blocks: [UIView] = []
	var draggingChain: [UIView] = []

	var panGesture: UIPanGestureRecognizer! = nil
	var liftGesture: UILongPressGestureRecognizer! = nil

	var animations: [UIView: POPSpringAnimation] = [:]

	var blockSize: CGFloat = 15.0

	override func loadView() {
		super.loadView()

		self.view.addGestureRecognizer(spec.twoFingerTripleTapGestureRecognizer())

		view.backgroundColor = UIColor.whiteColor()

		let numberOfBlocks = 50
		let blocksPerRow = 12
		blocks = []
		blocks.reserveCapacity(numberOfBlocks)

		for i in 0..<numberOfBlocks {
			let y = CGFloat(i / blocksPerRow * 200 + 80)
			let blockView = UIView()
			blockView.center.x = 25 + 60 * CGFloat(i % blocksPerRow)
			blockView.center.y = CGFloat(i / blocksPerRow * 200 + 80)
			spec.withDoubleForKey("blockSize", owner: blockView) {
				let view = $0 as UIView!
				let size = CGFloat($1)
				view.bounds.size.width = size
				view.bounds.size.height = size
			}
			spec.withDoubleForKey("blockBackgroundWhite", owner: blockView) { ($0 as UIView!).backgroundColor = UIColor(white: CGFloat($1), alpha: 1) }
			spec.withDoubleForKey("blockBorderWhite", owner: blockView) { ($0 as UIView!).layer.borderColor = UIColor(white: CGFloat($1), alpha: 1).CGColor }
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

		spec.withDoubleForKey("blockSize", owner: self) { ($0 as ViewController!).blockSize = CGFloat($1) }

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
						let trailingMagnificationScale = CGFloat(spec.doubleForKey("trailingMagnificationScale"))
						block.bounds = CGRectMake(0, 0, self.blockSize * trailingMagnificationScale, self.blockSize * trailingMagnificationScale)
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
				let animation = animations[draggingChain[i]]!
				let indexDelta = i - find(draggingChain, gesture.view)!
				let separation: CGFloat = draggingChain.count < 10 ? blockSize * 1.25 : -1.0
				let newToValue = CGPoint(x: gesture.view.center.x + CGFloat(indexDelta) * (separation + gesture.view.bounds.size.width), y: gesture.view.center.y)
				animation.toValue = NSValue(CGPoint: newToValue)
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					self.draggingChain[i].bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
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
				let leadingMagnificationScale = CGFloat(spec.doubleForKey("leadingMagnificationScale"))
				gesture.view.bounds = CGRectMake(0, 0, self.blockSize * leadingMagnificationScale, self.blockSize * leadingMagnificationScale)
			}, completion: nil)
			gesture.view.layer.zPosition = 100
		case .Ended:
			UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
				gesture.view.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
				}, completion: nil)
			gesture.view.layer.zPosition = 0
		default:
			break
		}
	}
}

