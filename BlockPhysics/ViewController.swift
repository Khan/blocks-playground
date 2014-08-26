//
//  ViewController.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/12/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import UIKit

let spec = TunableSpec(name: "Blocks")

class BlockView: UIView {
	override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
		let touchableSize: CGFloat = 44.0
		let touchableBounds = CGRect(x: (bounds.size.width - touchableSize) / 2.0, y: (bounds.size.height - touchableSize) / 2.0, width: touchableSize, height: touchableSize)
		return CGRectContainsPoint(touchableBounds, point)
	}
}

enum BlockGrouping: SequenceType, Printable {
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
		var generator = generate()
		return generator.next()!
	}

	var count: Int {
		switch self {
		case .Block: return 1
		case .Rod(let views): return views.count
		case .Square(let views): return views.count
		}
	}

	var description: String {
		var output = "("
		switch self {
		case .Block: output += "Block: "
		case .Rod: output += "Rod: "
		case .Square: output += "Square: "
		}
		output += "(\(count) views))"
		return output
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


		let numberOfRods = 12
		let rodsPerRow = 2
		for i in 0..<numberOfRods {
			let y = CGFloat(i / rodsPerRow * 50 + 550)
			addRowAtPoint(CGPoint(x: 350 + 200 * CGFloat(i % rodsPerRow), y: y))
		}

		spec.withKey("blockSize", owner: self) { $0.blockSize = $1 }
	}

	func addBlockAtPoint(point: CGPoint) -> BlockView {
		let blockView = BlockView()
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
		return contains(blockViews, touch.view as BlockView)
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

	func layoutBlockGrouping(blockGrouping: BlockGrouping, givenAnchorPoint anchorPoint: CGPoint, anchorBlockView: BlockView) -> CGFloat {
		let xSeparation = max(CGFloat(18.0 - blockGrouping.count * 2.0), -1)
		let ySeparation = max(CGFloat(18.0 - blockGrouping.count / 5.0), -1)
		let blocks = Array(blockGrouping)
		let anchorBlockIndex = find(blocks, anchorBlockView)!

		let activeHorizontalDirection = (anchorBlockIndex == 0 || anchorBlockIndex == blocks.count - 1) ? horizontalDirection : .Left
		let activeVerticalDirection = (anchorBlockIndex == 0 || anchorBlockIndex == blocks.count - 1) ? verticalDirection : .Up

		for blockIndex in 0..<blocks.count {
			let blockView = blocks[blockIndex]
			let indexDelta = blockIndex - anchorBlockIndex
			let animation = positionAnimationForBlockView(blockView)

			let x = anchorPoint.x + (xSeparation + blockView.bounds.size.width) * CGFloat(indexDelta % 10) * (activeHorizontalDirection == .Right ? -1 : 1)
			let y = anchorPoint.y + (ySeparation + blockView.bounds.size.height) * CGFloat(indexDelta / 10) * (activeVerticalDirection == .Down ? -1 : 1)
			let newToValue = CGPoint(x: x, y: y)
			animation.toValue = NSValue(CGPoint: newToValue)
		}

		let numberOfRows = Int(ceil(Double(blocks.count) / 10.0))
		return CGFloat(numberOfRows) * blockSize * spec["trailingMagnificationScale"]
	}

	func incorporateGrouping(hitGroup: BlockGrouping, touchedBlock: BlockView) {
		let holdingGroup = draggingChain[0]
		switch holdingGroup {
		case .Block(let holdingBlockView):
			draggingChain.insert(hitGroup, atIndex: 1)
		case .Rod(var holdingRodViews):
			switch hitGroup {
			case .Block(let hitBlockView):
				draggingChain[0] = .Block(touchedBlock)
				holdingRodViews.removeAtIndex(find(holdingRodViews, touchedBlock)!)
				holdingRodViews.insert(hitBlockView, atIndex: 0)
				draggingChain.insert(.Rod(holdingRodViews), atIndex: 1)
			case .Rod, .Square:
				draggingChain.insert(hitGroup, atIndex: 1)
			}
		case .Square(var holdingSquareViews):
			switch hitGroup {
			case .Block(let hitBlockView):
				// TODO DRY with rod case above
				draggingChain[0] = .Block(touchedBlock)
				holdingSquareViews.removeAtIndex(find(holdingSquareViews, touchedBlock)!)
				holdingSquareViews.insert(hitBlockView, atIndex: 0)
				draggingChain.insert(.Square(holdingSquareViews), atIndex: 1)
			case .Rod:
				draggingChain.insert(hitGroup, atIndex: 0)
			case .Square:
				draggingChain.insert(hitGroup, atIndex: 1)
			}
		}

		draggingChain = reduce(draggingChain.reverse(), []) { chain, newGrouping in
			var newChain = chain
			if chain.count > 0 {
				switch chain.last! {
				case .Block(let firstBlockView):
					switch newGrouping {
					case .Block(let secondBlockView):
						newChain[newChain.count-1] = .Rod([secondBlockView, firstBlockView])
					case .Rod, .Square: abort()
					}
				case .Rod(let firstRodViews):
					switch newGrouping {
					case .Block(let secondBlockView):
						if firstRodViews.count < 10 {
							newChain[newChain.count-1] = .Rod([secondBlockView] + firstRodViews)
						} else {
							newChain.append(newGrouping)
						}
					case .Rod(let secondRodViews):
						if secondRodViews.count < 10 {
							let newViews = secondRodViews + firstRodViews
							newChain[newChain.count-1] = .Rod(Array(newViews[0..<10]))
							let remainderViews = Array(newViews[10..<newViews.count])
							if remainderViews.count > 1 {
								newChain.append(.Rod(remainderViews))
							} else {
								newChain.append(.Block(remainderViews[0]))
							}
						} else {
							newChain[newChain.count-1] = .Square(secondRodViews + firstRodViews)
						}
					case .Square: abort()
					}
				case .Square(let firstSquareViews):
					switch newGrouping {
					case .Block(let secondBlockView):
						newChain.append(newGrouping)
					case .Rod(let secondRodViews):
						if secondRodViews.count < 10 {
							newChain.append(newGrouping)
						} else {
							let newSquareViews = secondRodViews + firstSquareViews
							if newSquareViews.count <= 100 {
								newChain[newChain.count-1] = .Square(newSquareViews)
							} else {
								newChain[newChain.count-1] = .Square(Array(newSquareViews[0..<100]))
								let remainderViews = Array(newSquareViews[100..<newSquareViews.count])
								if remainderViews.count > 1 {
									newChain.append(.Rod(remainderViews))
								} else {
									newChain.append(.Block(remainderViews[0]))
								}
							}
						}
					case .Square(let secondSquareViews):
						// TODO handle incomplete square
						abort()
					}
				}
			} else {
				newChain = [newGrouping]
			}

			return newChain
		}.reverse()
	}

	func handlePan(gesture: UIPanGestureRecognizer) {
		let gestureLocation = gesture.locationInView(view)
		let touchedBlock = gesture.view as BlockView
		let blockIndex = find(blockViews, touchedBlock)!
		switch gesture.state {
		case .Began:
			draggingChain = [blockViewsToBlockGroupings[touchedBlock]!]
			touchedBlock.pop_removeAnimationForKey("position")

			horizontalDirection = gesture.velocityInView(view).x > 0 ? .Right : .Left
			verticalDirection = gesture.velocityInView(view).y > 0 ? .Down : .Up
		case .Changed:
			let translation = gesture.translationInView(view)
			gesture.setTranslation(CGPoint(), inView: view)
			touchedBlock.center.x += translation.x
			touchedBlock.center.y += translation.y

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
					incorporateGrouping(hitGroup, touchedBlock: touchedBlock)
					println(draggingChain)
					for grouping in draggingChain {
						updateAnimationConstantsForBlockGrouping(grouping, givenDraggingView: touchedBlock)
					}

					for hitBlock in hitGroup {
						UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
							let trailingMagnificationScale: CGFloat = spec["trailingMagnificationScale"]
							hitBlock.bounds = CGRectMake(0, 0, self.blockSize * trailingMagnificationScale, self.blockSize * trailingMagnificationScale)
							}, completion: nil)
					}
				}
			}

			var y = touchedBlock.center.y
			for groupingIndex in 0..<draggingChain.count {
				let grouping = draggingChain[groupingIndex]
				let anchorBlockView = groupingIndex == 0 ? touchedBlock : grouping.firstBlock()
				let groupingHeight = layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: touchedBlock.center.x, y: y), anchorBlockView: anchorBlockView)
				let verticalMargin: CGFloat = 20.0
				y += (verticalMargin + groupingHeight) * (verticalDirection == .Down ? -1 : 1)
			}
		case .Ended:
			let draggingBlockAnimation = positionAnimationForBlockView(touchedBlock)
			draggingBlockAnimation.toValue = NSValue(CGPoint: blockViews[blockIndex].center)
			draggingBlockAnimation.fromValue = draggingBlockAnimation.toValue
			touchedBlock.pop_addAnimation(draggingBlockAnimation, forKey: "position")

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
					let squareBlockViews: [BlockView] = Array(grouping)
					if grouping.count < 100 {
						for minimumIndex in stride(from: 0, to: grouping.count, by: 10) {
							let boundIndex = min(minimumIndex + 10, grouping.count)
							let rodBlocks: [BlockView] = Array(squareBlockViews[minimumIndex..<boundIndex])
							groupingsToCommit.append(BlockGrouping.Rod(rodBlocks))
						}
					} else {
						groupingsToCommit.append(grouping)
					}
				}
			}

			for groupingIndex in 0..<groupingsToCommit.count {
				let grouping = groupingsToCommit[groupingIndex]
				var x = touchedBlock.center.x
				for blockView in grouping {
					blockViewsToBlockGroupings[blockView] = grouping

					UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
						blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
					}, completion: nil)
				}

				let anchorBlockView = groupingIndex == 0 ? touchedBlock : grouping.firstBlock()
				let anchorBlockAnimation = blockViewsToAnimations[anchorBlockView]!
				let anchorAnimationToPoint = anchorBlockAnimation.toValue.CGPointValue()
				layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: anchorAnimationToPoint.x, y: anchorAnimationToPoint.y), anchorBlockView: anchorBlockView)
			}
		default:
			break
		}
	}

	func handleLift(gesture: UIGestureRecognizer) {
		let hitBlock = gesture.view as BlockView
		let hitGrouping = blockViewsToBlockGroupings[hitBlock]!
		switch gesture.state {
		case .Began:
			for blockView in hitGrouping {
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					let leadingMagnificationScale: CGFloat = spec["leadingMagnificationScale"]
					let trailingMagnificationScale: CGFloat = spec["trailingMagnificationScale"]
					let magnificationScale = (blockView == hitBlock) ? leadingMagnificationScale : trailingMagnificationScale
					blockView.bounds = CGRectMake(0, 0, self.blockSize * magnificationScale, self.blockSize * magnificationScale)
				}, completion: nil)
			}
			updateAnimationConstantsForBlockGrouping(hitGrouping, givenDraggingView: hitBlock)
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitBlock)
			hitBlock.layer.zPosition = 100
		case .Ended:
			for blockView in hitGrouping {
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
				}, completion: nil)
			}
			hitBlock.layer.zPosition = 0
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitBlock)
		default:
			break
		}
	}
}
