//
//  ViewController.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/12/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import UIKit

let spec = TunableSpec(name: "Blocks")

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

	var horizontalDirection: HorizontalDirection = .Left
	var verticalDirection: VerticalDirection = .Down

	override func loadView() {
		super.loadView()

		self.view.addGestureRecognizer(spec.twoFingerTripleTapGestureRecognizer())

		view.backgroundColor = UIColor.whiteColor()

		let numberOfBlocks = 40
		let blocksPerRow = 12
		blockViews = []
		blockViews.reserveCapacity(numberOfBlocks)

		for i in 0..<numberOfBlocks {
			let y = CGFloat(i / blocksPerRow * 200 + 80)
			let blockView = addBlockAtPoint(CGPoint(x: 25 + 60 * CGFloat(i % blocksPerRow), y: y))
		}


		let numberOfRods = 8
		let rodsPerRow = 2
		for i in 0..<numberOfRods {
			let y = CGFloat(i / rodsPerRow * 50 + 550)
			addRowAtPoint(CGPoint(x: 350 + 200 * CGFloat(i % rodsPerRow), y: y))
		}

		spec.withKey("blockSize", owner: self) { $0.blockSize = $1 }
	}

	func addBlockAtPoint(point: CGPoint) -> BlockView {
		let blockView = UIView()
		blockView.center = point
		spec.withKey("blockSize", owner: blockView) { (blockView: UIView, size: CGFloat) in
			blockView.bounds.size.width = size
			blockView.bounds.size.height = size
		}
		spec.withKey("blockBackgroundWhite", owner: blockView) { $0.backgroundColor = UIColor(white: $1, alpha: 1) }
		spec.withKey("blockBorderWhite", owner: blockView) { $0.layer.borderColor = UIColor(white: $1, alpha: 1).CGColor }
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
		var toPoint: CGPoint = blockView.center
		springAnimation.toValue = NSValue(CGPoint: toPoint)
		springAnimation.removedOnCompletion = false;
		blockViewsToAnimations[blockView] = springAnimation
		blockView.pop_addAnimation(springAnimation, forKey: positionAnimationKey)

		blockViewsToBlockGroupings[blockView] = .Block(blockView)

		return blockView
	}

	func addRowAtPoint(point: CGPoint) -> [BlockView] {
		let blockViews: [BlockView] = (0..<10).map { _ in self.addBlockAtPoint(point) }
		let grouping = BlockGrouping.Rod(blockViews)
		for blockView in blockViews {
			blockViewsToBlockGroupings[blockView] = grouping
		}
		layoutBlockGrouping(grouping, givenAnchorPoint: point, anchorBlockView: grouping.firstBlock())
		for blockView in blockViews {
			blockView.center = blockViewsToAnimations[blockView]!.toValue.CGPointValue()
		}
		return blockViews
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
			let unitDistance = min(distance / blockSize, 12)
			let animation = blockViewsToAnimations[blockView]!
			
			let friction = spec["nearFriction"] * exp(-1 * spec["frictionFalloff"] * unitDistance)
			let tension = spec["nearTension"] * exp(-1 * spec["tensionFalloff"] * unitDistance)
			animation.dynamicsFriction = friction
			animation.dynamicsMass = 1
			animation.dynamicsTension = tension
		}
	}

	func layoutBlockGrouping(blockGrouping: BlockGrouping, givenAnchorPoint anchorPoint: CGPoint, anchorBlockView: BlockView) {
		let xSeparation = CGFloat(18 - blockGrouping.count * 2.0)
		let blocks = Array(blockGrouping)
		let anchorBlockIndex = find(blocks, anchorBlockView)!

		let activeHorizontalDirection = (anchorBlockIndex == 0 || anchorBlockIndex == blocks.count - 1) ? horizontalDirection : .Left

		for blockIndex in 0..<blocks.count {
			let blockView = blocks[blockIndex]
			let indexDelta = blockIndex - anchorBlockIndex
			let animation = positionAnimationForBlockView(blockView)

			let x = anchorPoint.x + (xSeparation + blockView.bounds.size.width) * CGFloat(indexDelta) * (activeHorizontalDirection == .Right ? -1 : 1)
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
			let velocityThreshold: CGFloat = spec["velocityThreshold"]
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
				if block.pointInside(gesture.locationInView(block), withEvent: nil) && !contains(draggingChain, {$0.containsBlockView(block)}) {
					let hitGroup = blockViewsToBlockGroupings[block]!
					switch hitGroup {
					case .Block:
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
						case .Square(var views):
							abort()
						}
					case .Rod:
						draggingChain.insert(hitGroup, atIndex: 1)
					case .Square: abort()
					}

					for grouping in draggingChain {
						updateAnimationConstantsForBlockGrouping(grouping, givenDraggingView: gesture.view)
					}

					for hitBlock in hitGroup {
						UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
							let trailingMagnificationScale: CGFloat = spec["trailingMagnificationScale"]
							hitBlock.bounds = CGRectMake(0, 0, self.blockSize * trailingMagnificationScale, self.blockSize * trailingMagnificationScale)
							}, completion: nil)
					}
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

			for groupingIndex in 0..<groupingsToCommit.count {
				let grouping = groupingsToCommit[groupingIndex]
				var x = gesture.view.center.x
				for blockView in grouping {
					blockViewsToBlockGroupings[blockView] = grouping

					UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
						blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
					}, completion: nil)
				}

				let anchorBlockView = groupingIndex == 0 ? gesture.view : grouping.firstBlock()
				let anchorBlockAnimation = blockViewsToAnimations[anchorBlockView]!
				let anchorAnimationToPoint = anchorBlockAnimation.toValue.CGPointValue()
				layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: anchorAnimationToPoint.x, y: anchorAnimationToPoint.y), anchorBlockView: anchorBlockView)
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
					let leadingMagnificationScale: CGFloat = spec["leadingMagnificationScale"]
					let trailingMagnificationScale: CGFloat = spec["trailingMagnificationScale"]
					let magnificationScale = (blockView == hitView) ? leadingMagnificationScale : trailingMagnificationScale
					blockView.bounds = CGRectMake(0, 0, self.blockSize * magnificationScale, self.blockSize * magnificationScale)
				}, completion: nil)
			}
			updateAnimationConstantsForBlockGrouping(hitGrouping, givenDraggingView: gesture.view)
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitView)
			gesture.view.layer.zPosition = 100
		case .Ended:
			for blockView in hitGrouping {
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
				}, completion: nil)
			}
			gesture.view.layer.zPosition = 0
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitView)
		default:
			break
		}
	}
}
