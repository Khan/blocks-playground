//
//  ViewController.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/12/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import UIKit

let spec = KFTunableSpec.specNamed("Blocks") as KFTunableSpec

typealias BlockView = UIView

enum BlockGrouping: SequenceType {
	case Block(BlockView)
	case Rod([BlockView])
	case Square([BlockView])

	func containsBlockView(blockView: BlockView) -> Bool {
		switch self {
		case .Block(let view):
			return view === blockView
		case .Rod(let views):
			return contains(views, blockView)
		case .Square(let views):
			return contains(views, blockView)
		}
	}

	typealias Generator = IndexingGenerator<Array<BlockView>>
	func generate() -> Generator {
		switch self {
		case .Block(let view):
			return [view].generate()
		case .Rod(let views):
			return views.generate()
		case .Square(let views):
			return views.generate()
		}
	}

	var count: Int {
		switch self {
		case .Block: return 1
		case .Rod(let views): return views.count
		case .Square(let views): return views.count
		}
	}
}

enum HorizontalDirection {
	case Left, Right
}

enum VerticalDirection {
	case Up, Down
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
	var blockViews: [BlockView] = []
	var draggingChain: [BlockGrouping] = []

	var panGesture: UIPanGestureRecognizer! = nil
	var liftGesture: UILongPressGestureRecognizer! = nil

	var blockSize: CGFloat = 15.0

	let positionAnimationKey = "position"
	var blockViewsToAnimations: [BlockView: POPSpringAnimation] = [:]
	var blockViewsToBlockGroupings: [BlockView: BlockGrouping] = [:]

	var horizontalDirection: HorizontalDirection = .Right
	var verticalDirection: VerticalDirection = .Up

	override func loadView() {
		super.loadView()

		self.view.addGestureRecognizer(spec.twoFingerTripleTapGestureRecognizer())

		view.backgroundColor = UIColor.whiteColor()

		let numberOfBlocks = 50
		let blocksPerRow = 12
		blockViews = []
		blockViews.reserveCapacity(numberOfBlocks)

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
			blockViews.append(blockView)
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
			var toPoint: CGPoint = blockViews[i].center
			springAnimation.toValue = NSValue(CGPoint: toPoint)
			springAnimation.removedOnCompletion = false;
			blockViewsToAnimations[blockViews[i]] = springAnimation
			blockViews[i].pop_addAnimation(springAnimation, forKey: positionAnimationKey)
		}
	}

	func positionAnimationForBlockView(blockView: BlockView) -> POPSpringAnimation {
		return blockViewsToAnimations[blockView]!
	}

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldReceiveTouch touch: UITouch!) -> Bool {
		return contains(blockViews, touch.view)
	}

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer!) -> Bool {
		return (gestureRecognizer.isKindOfClass(UIPanGestureRecognizer.self) && otherGestureRecognizer.isKindOfClass(UILongPressGestureRecognizer.self)) ||
			(gestureRecognizer.isKindOfClass(UILongPressGestureRecognizer.self) && otherGestureRecognizer.isKindOfClass(UIPanGestureRecognizer.self))
	}

	func updateAnimationConstantsForBlockGrouping(blockGrouping: BlockGrouping, givenDraggingView draggingView: BlockView) {
		for blockView in blockGrouping {
			let blockDestination = blockViewsToAnimations[blockView]!.toValue.CGPointValue()
			let deltaPoint = CGPoint(x: draggingView.center.x - blockDestination.x, y: draggingView.center.y - blockDestination.y)
			let distance = sqrt(deltaPoint.x*deltaPoint.x + deltaPoint.y*deltaPoint.y)
			let unitDistance = Double(distance / blockSize)
			let animation = blockViewsToAnimations[blockView]!
			animation.springSpeed = CGFloat(max(spec.doubleForKey("blockSpeedIntercept") - spec.doubleForKey("blockSpeedNegativeSlope") * unitDistance, 1))
			animation.springBounciness = CGFloat(min(spec.doubleForKey("blockSpringinessIntercept") + spec.doubleForKey("blockSpringinessSlope") * unitDistance, 20))
		}
	}

	func handlePan(gesture: UIPanGestureRecognizer) {
		let gestureLocation = gesture.locationInView(view)
		let blockIndex = find(blockViews, gesture.view)!
		switch gesture.state {
		case .Began:
			let grouping = blockViewsToBlockGroupings[gesture.view]
			draggingChain = [grouping ?? .Block(gesture.view)]
			gesture.view.pop_removeAnimationForKey("position")

			horizontalDirection = gesture.velocityInView(view).x > 0 ? .Right : .Left
			verticalDirection = gesture.velocityInView(view).y > 0 ? .Down : .Up
		case .Changed:
			let translation = gesture.translationInView(view)
			gesture.setTranslation(CGPoint(), inView: view)
			gesture.view.center.x += translation.x
			gesture.view.center.y += translation.y

			let gestureVelocity = gesture.velocityInView(view)
			let velocityThreshold = CGFloat(100)
			if horizontalDirection == .Left && (gestureVelocity.x > velocityThreshold) {
				horizontalDirection = .Right
			} else if horizontalDirection == .Right && gestureVelocity.x < -velocityThreshold {
				horizontalDirection = .Left
			}

			if verticalDirection == .Up && (gestureVelocity.y > velocityThreshold) {
				verticalDirection = .Down
			} else if verticalDirection == .Down && gestureVelocity.y < -velocityThreshold {
				verticalDirection = .Up
			}

//			let draggingBlockIndexInChain = find(draggingChain, gesture.view)!
			for block in blockViews {
				if !contains(draggingChain, {$0.containsBlockView(block)}) && CGRectIntersectsRect(gesture.view.frame, block.frame) {
					let firstGroup = draggingChain[0]
					switch firstGroup {
					case .Block(let view):
						draggingChain[0] = .Rod([view, block])
						updateAnimationConstantsForBlockGrouping(draggingChain[0], givenDraggingView: gesture.view)
					case .Rod(var views):
						if views.count < 10 {
							views.insert(block, atIndex: 1)
							draggingChain[0] = .Rod(views)
						} else {
							draggingChain[0] = .Block(gesture.view)
							views[0] = block
							draggingChain.insert(.Rod(views), atIndex: 1)
						}
						for grouping in draggingChain {
							updateAnimationConstantsForBlockGrouping(grouping, givenDraggingView: gesture.view)
						}
					case .Square(var views):
						abort()
					}
					UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
						let trailingMagnificationScale = CGFloat(spec.doubleForKey("trailingMagnificationScale"))
						block.bounds = CGRectMake(0, 0, self.blockSize * trailingMagnificationScale, self.blockSize * trailingMagnificationScale)
					}, completion: nil)
				}
			}

			var y = gesture.view.center.y
			for grouping in draggingChain {
				var x = gesture.view.center.x
				for blockView in grouping {
					let animation = positionAnimationForBlockView(blockView)
					let xSeparation = CGFloat(18 - grouping.count * 2.0)
					let newToValue = CGPoint(x: x, y: y)
					animation.toValue = NSValue(CGPoint: newToValue)
					x += (xSeparation + blockView.bounds.size.width) * (horizontalDirection == .Right ? -1 : 1)
				}

				let ySeparation = CGFloat(20)
				y += (ySeparation + blockSize) * (verticalDirection == .Down ? -1 : 1)
			}
		case .Ended:
			let draggingBlockAnimation = positionAnimationForBlockView(gesture.view)
			draggingBlockAnimation.toValue = NSValue(CGPoint: blockViews[blockIndex].center)
			draggingBlockAnimation.fromValue = draggingBlockAnimation.toValue
			gesture.view.pop_addAnimation(draggingBlockAnimation, forKey: "position")
/*
			for i in 0..<draggingChain.count {
				let animation = positionAnimationForBlockView(draggingChain[i])
				let indexDelta = i - find(draggingChain, gesture.view)!
				let separation: CGFloat = draggingChain.count < 10 ? blockSize * 1.25 : -1.0
				let newToValue = CGPoint(x: gesture.view.center.x + CGFloat(indexDelta) * (separation + gesture.view.bounds.size.width), y: gesture.view.center.y)
				animation.toValue = NSValue(CGPoint: newToValue)
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					self.draggingChain[i].bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
				}, completion: nil)
			}*/
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

