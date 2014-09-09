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

enum BlockGrouping: SequenceType, Printable, Equatable {
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

func == (left: BlockGrouping, right: BlockGrouping) -> Bool {
	return Array(left) == Array(right)
}

enum HorizontalDirection {
	case Left, Right
}

enum VerticalDirection {
	case Up, Down
}

class ViewController: UIViewController, UIGestureRecognizerDelegate, UIAlertViewDelegate, UIActionSheetDelegate {
	var blockViews: [BlockView] = []
	var draggingChain: [BlockGrouping] = []
	var touchedBlock: BlockView?
	var pinchingBlocks: (BlockView, BlockView)?

	var panGesture: UIPanGestureRecognizer!
	var liftGesture: UILongPressGestureRecognizer!

	var blockSize: CGFloat = 15.0

	let positionAnimationKey = "position"
	var blockViewsToAnimations: [BlockView: POPSpringAnimation] = [:]
	var blockViewsToBlockGroupings: [BlockView: BlockGrouping] = [:]

	var horizontalDirection: HorizontalDirection = .Left
	var verticalDirection: VerticalDirection = .Up

	var scratchpadController: KAScratchpadViewController!

	override func loadView() {
		super.loadView()

		self.view.addGestureRecognizer(spec.twoFingerTripleTapGestureRecognizer())
		scratchpadController = KAScratchpadViewController()
		self.addChildViewController(scratchpadController)
		self.view.addSubview(scratchpadController.view)

		view.backgroundColor = UIColor.whiteColor()

		blockViews = []

		let pinchGesture = UIPinchGestureRecognizer(target: self, action: "handlePinch:")
		pinchGesture.delegate = self
		view.addGestureRecognizer(pinchGesture)

		let panGesture = UIPanGestureRecognizer(target: self, action: "handlePan:")
		panGesture.delegate = self
		panGesture.maximumNumberOfTouches = 2
		view.addGestureRecognizer(panGesture)

		let addButton = UIButton.buttonWithType(.ContactAdd) as UIButton
		addButton.center = CGPoint(x: 30, y: 30)
		addButton.frame = CGRectInset(addButton.frame, -20, -20)
		addButton.addTarget(self, action: "addButtonPressed:", forControlEvents: .TouchUpInside)
		view.addSubview(addButton)

		let clearButton = UIButton.buttonWithType(.System) as UIButton
		view.addSubview(clearButton)
		clearButton.setTitle("Clear", forState: .Normal)
		clearButton.setTranslatesAutoresizingMaskIntoConstraints(false)
		view.addConstraint(NSLayoutConstraint(item: view, attribute: .Trailing, relatedBy: .Equal, toItem: clearButton, attribute: .Trailing, multiplier: 1, constant: 30))
		view.addConstraint(NSLayoutConstraint(item: clearButton, attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1, constant: 20))
		clearButton.addTarget(self, action: "clearButtonPressed:", forControlEvents: .TouchUpInside)

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

		// Debug block coloring:
//		blockView.backgroundColor = UIColor(hue: point.x / 768.0, saturation: 1.0 - (point.y / 1024.0) * 0.3, brightness: 0.7 + (point.y / 1024.0) * 0.3, alpha: 1.0)

		spec.withKey("blockBorderWhite", owner: blockView) { $0.layer.borderColor = UIColor(white: $1, alpha: 1).CGColor }
		blockView.layer.borderWidth = 1
		blockViews.append(blockView)
		view.addSubview(blockView)

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
		layoutBlockGrouping(grouping, givenAnchorPoint: point, anchorBlockView: grouping.firstBlock(), xSeparation: 0, ySeparation: 0)
		for blockView in blockViews {
			blockView.center = blockViewsToAnimations[blockView]!.toValue.CGPointValue()
		}
		return blockViews
	}

	// TODO DRY with addRowAtPoint
	func addSquareAtPoint(point: CGPoint) -> [BlockView] {
		let blockViews: [BlockView] = (0..<100).map { _ in self.addBlockAtPoint(point) }
		let grouping = BlockGrouping.Square(blockViews)
		for blockView in blockViews {
			blockViewsToBlockGroupings[blockView] = grouping
		}
		layoutBlockGrouping(grouping, givenAnchorPoint: point, anchorBlockView: grouping.firstBlock(), xSeparation: 0, ySeparation: 0)
		for blockView in blockViews {
			blockView.center = blockViewsToAnimations[blockView]!.toValue.CGPointValue()
		}
		return blockViews
	}

	func addBlocks(numberOfBlocks: Int, atPoint: CGPoint) {
		let numberOfSquares = numberOfBlocks / 100
		let numberOfRods = (numberOfBlocks - numberOfSquares * 100) / 10
		let numberOfBlocks = numberOfBlocks - numberOfSquares * 100 - numberOfRods * 10
		var y = atPoint.y

		if (numberOfSquares > 0) {
			let squaresPerRow = 3
			for i in 0..<numberOfSquares {
				if i > 0 && i % squaresPerRow == 0 {
					y += blockSize * 10 + 75
				}
				addSquareAtPoint(CGPoint(x: atPoint.x + (blockSize * 10 + 75) * CGFloat(i % squaresPerRow), y: y))
			}

			y += blockSize * 10 + 150
		}

		if (numberOfRods > 0) {
			let rodsPerRow = 3
			for i in 0..<numberOfRods {
				if i > 0 && i % rodsPerRow == 0 {
					y += 75
				}
				addRowAtPoint(CGPoint(x: atPoint.x + (blockSize * 10 + 75) * CGFloat(i % rodsPerRow), y: y))
			}

			y += 150
		}

		let blocksPerRow = 12
		for i in 0..<numberOfBlocks {
			if i > 0 && i % blocksPerRow == 0 {
				y += 150
			}
			let blockView = addBlockAtPoint(CGPoint(x: atPoint.x + 60 * CGFloat(i % blocksPerRow), y: y))
		}
	}

	func positionAnimationForBlockView(blockView: BlockView) -> POPSpringAnimation {
		return blockViewsToAnimations[blockView]!
	}

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldReceiveTouch touch: UITouch!) -> Bool {
		return touch.view is BlockView
	}

	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer!) -> Bool {
		if (gestureRecognizer is UILongPressGestureRecognizer || otherGestureRecognizer is UILongPressGestureRecognizer) {
			return true
		} else {
			return false
		}
	}

	func addButtonPressed(sender: UIButton) {
		let alertView = UIAlertView(title: "How many blocks?", message: "", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Add")
		alertView.alertViewStyle = .PlainTextInput
		alertView.textFieldAtIndex(0)!.keyboardType = .NumberPad
		alertView.show()
	}

	func clearButtonPressed(sender: UIButton) {
		let actionSheet = UIActionSheet(title: "Are you sure?", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: "Clear")
		actionSheet.showFromRect(sender.frame, inView: view, animated: true)
	}

	func actionSheet(actionSheet: UIActionSheet, didDismissWithButtonIndex buttonIndex: Int) {
		if buttonIndex == actionSheet.destructiveButtonIndex {
			for blockView in blockViews {
				blockView.removeFromSuperview()
			}
			blockViews = []
			blockViewsToAnimations = [:]
			blockViewsToBlockGroupings = [:]

			scratchpadController.resetCanvas()
		}
	}

	func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
		if buttonIndex != alertView.cancelButtonIndex {
			if let blockCount = alertView.textFieldAtIndex(0)!.text.toInt() {
				addBlocks(blockCount, atPoint: CGPoint(x: 50, y: 70))
			}
		}
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

	func layoutBlockGrouping(blockGrouping: BlockGrouping, givenAnchorPoint anchorPoint: CGPoint, anchorBlockView: BlockView, xSeparation: CGFloat, ySeparation: CGFloat) -> CGFloat {
		let xSeparation = max(CGFloat(18.0 - blockGrouping.count * 2.0), -1)
		let ySeparation = max(CGFloat(18.0 - blockGrouping.count / 5.0), -1)
		let blocks = Array(blockGrouping)
		let anchorBlockIndex = find(blocks, anchorBlockView)!

		let activeHorizontalDirection = (anchorBlockIndex == 0 || anchorBlockIndex == blocks.count - 1) ? horizontalDirection : .Left
		let activeVerticalDirection = (anchorBlockIndex == 0 || anchorBlockIndex == blocks.count - 1) ? verticalDirection : .Up

		for blockIndex in 0..<blocks.count {
			let blockView = blocks[blockIndex]
			let columnDelta = blockIndex % 10 - anchorBlockIndex % 10
			let rowDelta = blockIndex / 10 - anchorBlockIndex / 10
			let animation = positionAnimationForBlockView(blockView)

			let x = anchorPoint.x + (xSeparation + blockView.bounds.size.width) * CGFloat(columnDelta) * (activeHorizontalDirection == .Right ? -1 : 1)
			let y = anchorPoint.y + (ySeparation + blockView.bounds.size.height) * CGFloat(rowDelta) * (activeVerticalDirection == .Down ? -1 : 1)
			let newToValue = CGPoint(x: x, y: y)
			animation.toValue = NSValue(CGPoint: newToValue)
		}

		let firstY = blocks[0].center.y
		let lastY = blocks.last!.center.y
		let height = abs(lastY - firstY) + blockSize * spec["trailingMagnificationScale"]
		return height
	}

	func incorporateGrouping(hitGroup: BlockGrouping, givenTouchedBlock aTouchedBlock: BlockView) {
		let holdingGroup = draggingChain[0]
		switch holdingGroup {
		case .Block(let holdingBlockView):
			draggingChain.insert(hitGroup, atIndex: 1)
		case .Rod(var holdingRodViews):
			switch hitGroup {
			case .Block(let hitBlockView):
				draggingChain[0] = .Block(aTouchedBlock)
				holdingRodViews.removeAtIndex(find(holdingRodViews, aTouchedBlock)!)
				holdingRodViews.insert(hitBlockView, atIndex: 0)
				draggingChain.insert(.Rod(holdingRodViews), atIndex: 1)
			case .Rod, .Square:
				draggingChain.insert(hitGroup, atIndex: 1)
			}
		case .Square(var holdingSquareViews):
			switch hitGroup {
			case .Block(let hitBlockView):
				// TODO DRY with rod case above
				draggingChain[0] = .Block(aTouchedBlock)
				holdingSquareViews.removeAtIndex(find(holdingSquareViews, aTouchedBlock)!)
				holdingSquareViews.insert(hitBlockView, atIndex: 0)
				draggingChain.insert(.Square(holdingSquareViews), atIndex: 1)
			case .Rod(var hitRodViews):
				holdingSquareViews.removeAtIndex(find(holdingSquareViews, aTouchedBlock)!)
				holdingSquareViews.insert(hitRodViews.last!, atIndex: 0)
				draggingChain[0] = .Square(holdingSquareViews)
				hitRodViews.removeLast()
				hitRodViews.insert(aTouchedBlock, atIndex: 0)
				draggingChain.insert(.Rod(hitRodViews), atIndex: 0)
				draggingChain[0] = .Rod(hitRodViews)
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
							newChain.append(newGrouping)
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
								newChain[newChain.count-1] = .Square(Array(newSquareViews[newSquareViews.count-100..<newSquareViews.count]))
								let remainderViews = Array(newSquareViews[0..<newSquareViews.count-100])
								if remainderViews.count > 1 {
									newChain.append(.Rod(remainderViews))
								} else {
									newChain.append(.Block(remainderViews[0]))
								}
							}
						}
					case .Square(let secondSquareViews):
						if secondSquareViews.count > firstSquareViews.count {
							newChain.append(newChain[newChain.count-1])
							newChain[newChain.count-2] = newGrouping
						} else {
							newChain.append(newGrouping)
						}
					}
				}
			} else {
				newChain = [newGrouping]
			}

			return newChain
		}.reverse()
	}

	func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer!) -> Bool {
		switch gestureRecognizer {
		case is UIPinchGestureRecognizer, is UIPanGestureRecognizer where gestureRecognizer.numberOfTouches() > 2:
			// The pinch gesture should only begin if the two hit blocks are in the same grouping.
			let firstTouchedBlockView = view.hitTest(gestureRecognizer.locationOfTouch(0, inView: view), withEvent: nil) as BlockView
			let secondTouchedBlockView = view.hitTest(gestureRecognizer.locationOfTouch(1, inView: view), withEvent: nil) as BlockView
			let firstTouchedGrouping = blockViewsToBlockGroupings[firstTouchedBlockView]!
			let secondTouchedGrouping = blockViewsToBlockGroupings[secondTouchedBlockView]!
			if firstTouchedGrouping == secondTouchedGrouping {
				return true
			} else {
				return false
			}
		default: return true
		}
	}

	func handlePinch(gesture: UIPinchGestureRecognizer) {
		switch gesture.state {
		case .Began:
			let firstBlock = view.hitTest(gesture.locationOfTouch(0, inView: view), withEvent: nil) as BlockView // TODO: more robust; this will fail in edge cases
			let secondBlock = view.hitTest(gesture.locationOfTouch(1, inView: view), withEvent: nil) as BlockView // TODO: more robust; this will fail in edge cases
			pinchingBlocks = (firstBlock, secondBlock)
		case .Changed:
			break
			/*
			let pinchingGroup = blockViewsToBlockGroupings[pinchingBlocks!.0]!
			let blocksInGroup = Array(pinchingGroup)
			let indexDistance = abs(find(blocksInGroup, pinchingBlocks!.0)! - find(blocksInGroup, pinchingBlocks!.1)!)
			let restingDistance = pinchingBlocks!.0.bounds.size.width * CGFloat(indexDistance)
			let currentDistance = abs(gesture.locationOfTouch(0, inView: view).x - gesture.locationOfTouch(1, inView: view).x)
			let xSeparation = (currentDistance - restingDistance) / CGFloat(indexDistance)

			let maximumSeparation = blockSize * 2.0
			let minimumSeparation: CGFloat = 0.0
			var rubberbandedSeparation = maximumSeparation * (1.0 - (1.0 / ((xSeparation * 0.55 / maximumSeparation) + 1.0)))
			layoutBlockGrouping(pinchingGroup, givenAnchorPoint: gesture.locationOfTouch(0, inView: view), anchorBlockView: pinchingBlocks!.0, xSeparation: rubberbandedSeparation, ySeparation: 0)
*/
		case .Ended where gesture.scale > 1.5:
			let pinchingGroup = blockViewsToBlockGroupings[pinchingBlocks!.0]!
			switch pinchingGroup {
			case .Block: break
			case .Rod(let pinchedBlockViews):
				// TODO: some kind of layout invalidation mechanism. this is nuts.
				dispatch_async(dispatch_get_main_queue()) {
					for blockViewIndex in 0..<pinchingGroup.count {
						let blockView = pinchedBlockViews[blockViewIndex]
						let newGrouping: BlockGrouping = .Block(blockView)
						self.blockViewsToBlockGroupings[blockView] = newGrouping

						UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
							blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
							}, completion: nil)

						let anchorBlockView = newGrouping.firstBlock()
						let anchorBlockAnimation = self.blockViewsToAnimations[anchorBlockView]!
						var anchorAnimationToPoint = anchorBlockAnimation.toValue.CGPointValue()
						anchorAnimationToPoint.x -= CGFloat(5 - blockViewIndex) * self.blockSize * 1.5
						self.layoutBlockGrouping(newGrouping, givenAnchorPoint: CGPoint(x: anchorAnimationToPoint.x, y: anchorAnimationToPoint.y), anchorBlockView: anchorBlockView, xSeparation: 0, ySeparation: 0)
					}
				}
			case .Square(let pinchedSquareViews):
				// TODO DRY with above
				dispatch_async(dispatch_get_main_queue()) {
					for blockViewIndex in stride(from: 0, to: pinchedSquareViews.count, by: 10) {
						let newGrouping: BlockGrouping = .Rod(Array(pinchedSquareViews[blockViewIndex..<blockViewIndex+10]))
						for blockView in newGrouping {
							self.blockViewsToBlockGroupings[blockView] = newGrouping
							UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
								blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
							}, completion: nil)
						}

						let anchorBlockView = newGrouping.firstBlock()
						let anchorBlockAnimation = self.blockViewsToAnimations[anchorBlockView]!
						var anchorAnimationToPoint = anchorBlockAnimation.toValue.CGPointValue()
						anchorAnimationToPoint.y -= CGFloat(5 - blockViewIndex/10) * self.blockSize * 1.5
						self.layoutBlockGrouping(newGrouping, givenAnchorPoint: CGPoint(x: anchorAnimationToPoint.x, y: anchorAnimationToPoint.y), anchorBlockView: anchorBlockView, xSeparation: 0, ySeparation: 0)
					}
				}
			}
		case .Ended: break;
		case .Cancelled: break; // TODO
		default: abort()
		}
	}

	func handlePan(gesture: UIPanGestureRecognizer) {
		let gestureLocation = gesture.locationInView(view)
		switch gesture.state {
		case .Began:
			draggingChain = [blockViewsToBlockGroupings[touchedBlock!]!]
			touchedBlock!.pop_removeAnimationForKey("position")

			horizontalDirection = gesture.velocityInView(view).x > 0 ? .Right : .Left
			verticalDirection = gesture.velocityInView(view).y > 0 ? .Down : .Up
		case .Changed:
			let translation = gesture.translationInView(view)
			gesture.setTranslation(CGPoint(), inView: view)
			touchedBlock!.center.x += translation.x
			touchedBlock!.center.y += translation.y

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
					incorporateGrouping(hitGroup, givenTouchedBlock: touchedBlock!)
					for grouping in draggingChain {
						updateAnimationConstantsForBlockGrouping(grouping, givenDraggingView: touchedBlock!)
					}

					for hitBlock in hitGroup {
						UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
							let trailingMagnificationScale: CGFloat = spec["trailingMagnificationScale"]
							hitBlock.bounds = CGRectMake(0, 0, self.blockSize * trailingMagnificationScale, self.blockSize * trailingMagnificationScale)
							}, completion: nil)
					}
				}
			}

			var y = touchedBlock!.center.y
			for groupingIndex in 0..<draggingChain.count {
				let grouping = draggingChain[groupingIndex]
				let anchorBlockView = groupingIndex == 0 ? touchedBlock! : grouping.firstBlock()
				let groupingHeight = layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: touchedBlock!.center.x, y: y), anchorBlockView: anchorBlockView, xSeparation: 0, ySeparation: 0)
				let verticalMargin: CGFloat = 20.0
				y += (verticalMargin + groupingHeight) * (verticalDirection == .Down ? -1 : 1)
			}
		case .Ended:
			let blockIndex = find(blockViews, touchedBlock!)!
			let draggingBlockAnimation = positionAnimationForBlockView(touchedBlock!)
			draggingBlockAnimation.toValue = NSValue(CGPoint: blockViews[blockIndex].center)
			draggingBlockAnimation.fromValue = draggingBlockAnimation.toValue
			touchedBlock!.pop_addAnimation(draggingBlockAnimation, forKey: "position")

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
				var x = touchedBlock!.center.x
				for blockView in grouping {
					blockViewsToBlockGroupings[blockView] = grouping

					UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
						blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
					}, completion: nil)
				}

				let anchorBlockView = groupingIndex == 0 ? touchedBlock! : grouping.firstBlock()
				let anchorBlockAnimation = blockViewsToAnimations[anchorBlockView]!
				let anchorAnimationToPoint = anchorBlockAnimation.toValue.CGPointValue()
				layoutBlockGrouping(grouping, givenAnchorPoint: CGPoint(x: anchorAnimationToPoint.x, y: anchorAnimationToPoint.y), anchorBlockView: anchorBlockView, xSeparation: 0, ySeparation: 0)
			}

			touchedBlock = nil
		case .Cancelled: break; // TODO
		default: abort()
		}
	}

	func handleLift(gesture: UIGestureRecognizer) {
		let hitBlock = gesture.view as BlockView
		let hitGrouping = blockViewsToBlockGroupings[hitBlock]!
		switch gesture.state {
		case .Began:
			touchedBlock = hitBlock
			for blockView in hitGrouping {
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					let leadingMagnificationScale: CGFloat = spec["leadingMagnificationScale"]
					let trailingMagnificationScale: CGFloat = spec["trailingMagnificationScale"]
					let magnificationScale = (blockView == hitBlock) ? leadingMagnificationScale : trailingMagnificationScale
					blockView.bounds = CGRectMake(0, 0, self.blockSize * magnificationScale, self.blockSize * magnificationScale)
				}, completion: nil)
			}
			updateAnimationConstantsForBlockGrouping(hitGrouping, givenDraggingView: hitBlock)
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitBlock, xSeparation: 0, ySeparation: 0)
			hitBlock.layer.zPosition = 100
		case .Ended:
			for blockView in hitGrouping {
				UIView.animateWithDuration(0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.BeginFromCurrentState | UIViewAnimationOptions.AllowUserInteraction, animations: {
					blockView.bounds = CGRectMake(0, 0, self.blockSize, self.blockSize)
				}, completion: nil)
			}
			hitBlock.layer.zPosition = 0
			layoutBlockGrouping(hitGrouping, givenAnchorPoint: gesture.locationInView(view), anchorBlockView: hitBlock, xSeparation: 0, ySeparation: 0)
		default:
			break
		}
	}

	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}
