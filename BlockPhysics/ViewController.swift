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
		return contains(self.generate(), blockView)
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

	func firstBlock() -> BlockView {
		var generator =  generate()
		return generator.next()!
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

			let springAnimation = POPSpringAnimation(propertyNamed: kPOPLayerPosition)
			var toPoint: CGPoint = blockViews[i].center
			springAnimation.toValue = NSValue(CGPoint: toPoint)
			springAnimation.removedOnCompletion = false;
			blockViewsToAnimations[blockViews[i]] = springAnimation
			blockViews[i].pop_addAnimation(springAnimation, forKey: positionAnimationKey)

			blockViewsToBlockGroupings[blockView] = .Block(blockView)
		}

		spec.withDoubleForKey("blockSize", owner: self) { ($0 as ViewController!).blockSize = CGFloat($1) }
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

	func layoutBlockGrouping(blockGrouping: BlockGrouping, givenAnchorPoint anchorPoint: CGPoint, anchorBlockView: BlockView) {
		let xSeparation = CGFloat(18 - blockGrouping.count * 2.0)
		let blocks = Array(blockGrouping)
		let anchorBlockIndex = find(blocks, anchorBlockView)!
		for blockIndex in 0..<blocks.count {
			let blockView = blocks[blockIndex]
			let indexDelta = blockIndex - anchorBlockIndex
			let animation = positionAnimationForBlockView(blockView)

			let x = anchorPoint.x + (xSeparation + blockView.bounds.size.width) * CGFloat(indexDelta) * (horizontalDirection == .Right ? -1 : 1)
			let newToValue = CGPoint(x: x, y: anchorPoint.y)
			animation.toValue = NSValue(CGPoint: newToValue)
		}
	}

	func handlePan(gesture: UIPanGestureRecognizer) {
		let gestureLocation = gesture.locationInView(view)
		let blockIndex = find(blockViews, gesture.view)!
		switch gesture.state {
		case .Began:
			draggingChain = [blockViewsToBlockGroupings[gesture.view]!]
			gesture.view.pop_removeAnimationForKey("position")

			horizontalDirection = gesture.velocityInView(view).x > 0 ? .Right : .Left
			verticalDirection = gesture.velocityInView(view).y > 0 ? .Down : .Up
		case .Changed:
			let translation = gesture.translationInView(view)
			gesture.setTranslation(CGPoint(), inView: view)
			gesture.view.center.x += translation.x
			gesture.view.center.y += translation.y

			let gestureVelocity = gesture.velocityInView(view)
			let velocityThreshold = CGFloat(spec.doubleForKey("velocityThreshold"))
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
							views.removeAtIndex(find(views, gesture.view)!)
							views.insert(block, atIndex: 0)
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
			for groupingIndex in 0..<draggingChain.count {
				let grouping = draggingChain[groupingIndex]
				let anchorBlockView = groupingIndex == 0 ? gesture.view : grouping.firstBlock()
				layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: gesture.view.center.x, y: y), anchorBlockView: anchorBlockView)
				let ySeparation = CGFloat(20)
				y += (ySeparation + blockSize) * (verticalDirection == .Down ? -1 : 1)
			}
		case .Ended:
			let draggingBlockAnimation = positionAnimationForBlockView(gesture.view)
			draggingBlockAnimation.toValue = NSValue(CGPoint: blockViews[blockIndex].center)
			draggingBlockAnimation.fromValue = draggingBlockAnimation.toValue
			gesture.view.pop_addAnimation(draggingBlockAnimation, forKey: "position")

			var groupingsToCommit: [BlockGrouping] = []
			for grouping in draggingChain {
				switch grouping {
				case .Block:
					groupingsToCommit.append(grouping)
				case .Rod:
					if grouping.count < 10 {
						for blockView in grouping {
							groupingsToCommit.append(.Block(blockView))
						}
					} else {
						groupingsToCommit.append(grouping)
					}
				case .Square:
					abort()
				}
			}

			for grouping in groupingsToCommit {
				var x = gesture.view.center.x
				for blockView in grouping {
					blockViewsToBlockGroupings[blockView] = grouping

					UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
						blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
					}, completion: nil)
				}

				let firstBlockAnimation = blockViewsToAnimations[grouping.firstBlock()]!
				let firstBlockAnimationToPoint = firstBlockAnimation.toValue.CGPointValue()
				layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: firstBlockAnimationToPoint.x, y: firstBlockAnimationToPoint.y), anchorBlockView: grouping.firstBlock())
			}
		default:
			break
		}
	}

	func handleLift(gesture: UIGestureRecognizer) {
		let hitView = gesture.view as BlockView
		let hitGrouping = blockViewsToBlockGroupings[hitView]!
		switch gesture.state {
		case .Began:
			for blockView in hitGrouping {
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					let leadingMagnificationScale = CGFloat(spec.doubleForKey("leadingMagnificationScale"))
					let trailingMagnificationScale = CGFloat(spec.doubleForKey("trailingMagnificationScale"))
					let magnificationScale = (blockView == hitView) ? leadingMagnificationScale : trailingMagnificationScale
					blockView.bounds = CGRectMake(0, 0, self.blockSize * magnificationScale, self.blockSize * magnificationScale)
				}, completion: nil)
			}
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitView)
			gesture.view.layer.zPosition = 100
		case .Ended:
			UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
				gesture.view.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
				}, completion: nil)
			gesture.view.layer.zPosition = 0
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitView)
		default:
			break
		}
	}
}

