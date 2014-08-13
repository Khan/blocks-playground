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
	var dynamicAnimator: UIDynamicAnimator! = nil

	var dragBehavior: UIAttachmentBehavior! = nil

	var anchors: [UIAttachmentBehavior] = []

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

		dynamicAnimator = UIDynamicAnimator(referenceView: view)

		let dynamicItemBehavior = UIDynamicItemBehavior(items: blocks)
		dynamicItemBehavior.allowsRotation = true
		dynamicItemBehavior.density = 1000
		dynamicItemBehavior.resistance = 1
//		dynamicItemBehavior.elasticity = 0.3
		dynamicAnimator.addBehavior(dynamicItemBehavior)

		let collisionBehavior = UICollisionBehavior(items: blocks)
//		dynamicAnimator.addBehavior(collisionBehavior)

		for i in 0..<(numberOfBlocks-1) {
			let addSpring: (UIOffset) -> Void = { offset in
//				var attachment = UIAttachmentBehavior(item: self.blocks[i], offsetFromCenter: offset, attachedToAnchor: self.blocks[i].center)
				var attachment = UIAttachmentBehavior(item: self.blocks[i], offsetFromCenter: offset, attachedToItem: self.blocks[i+1], offsetFromCenter: UIOffset(horizontal: -50, vertical: 0))
				attachment.damping = 0.5
				attachment.frequency = 2 + 0.2 * CGFloat(i)
				self.dynamicAnimator.addBehavior(attachment)
//				self.anchors.append(attachment)
			}

			addSpring(UIOffset(horizontal: -25, vertical: 25))
			addSpring(UIOffset(horizontal: 25, vertical: 25))
			addSpring(UIOffset(horizontal: 25, vertical: -25))
			addSpring(UIOffset(horizontal: -25, vertical: -25))
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
		case .Began:
			if dragBehavior {
				dynamicAnimator.removeBehavior(dragBehavior)
				dragBehavior = nil
			}
			dragBehavior = UIAttachmentBehavior(item: gesture.view, attachedToAnchor: gestureLocation)
			dragBehavior.length = 0
//			dragBehavior.damping = 1
//			dragBehavior.frequency = 1
			dynamicAnimator.addBehavior(dragBehavior)
			gesture.setTranslation(CGPointZero, inView: view)
		case .Changed:
			dragBehavior.anchorPoint = gestureLocation
			let translation = gesture.translationInView(view)
			for anchor in anchors {
				if (anchor.items[0] as UIView != gesture.view) {
				anchor.anchorPoint.x += translation.x
				anchor.anchorPoint.y += translation.y
				}
			}
			gesture.setTranslation(CGPointZero, inView: view)

/*			for block in blocks {
				if CGRectIntersectsRect(block.frame, gesture.view.frame) && block != gesture.view && anchors.count == 0{
					let attachment = UIAttachmentBehavior(item: block, offsetFromCenter: UIOffset(horizontal: 25, vertical: 0), attachedToItem: gesture.view, offsetFromCenter: UIOffset(horizontal: -50, vertical: 0))
					attachment.damping = 10
					attachment.frequency = 25
					dynamicAnimator.addBehavior(attachment)
//					anchors.append(attachment)

					let attachment2 = UIAttachmentBehavior(item: block, offsetFromCenter: UIOffset(horizontal: -25, vertical: 0), attachedToAnchor: CGPoint(x: CGRectGetMidX(gesture.view.frame) - 75, y: CGRectGetMidY(gesture.view.frame)))
					attachment2.damping = 10
					attachment2.frequency = 25
					attachment2.length = 0
//					dynamicAnimator.addBehavior(attachment2)
//					anchors.append(attachment2)
				}
			}*/
		default:
			break
		}
	}

	func handleLift(gesture: UIGestureRecognizer) {
		switch gesture.state {
		case .Began:
			UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
//				gesture.view.transform = CGAffineTransformMakeScale(1.25, 1.25)
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

