//
//  TunableSpec.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/21/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import Foundation
import UIKit

/* TunableSpec provides live tweaking of UI spec values in a running app. From the source code perspective, it's similar to NSUserDefaults, but the values are backed by a JSON file. It's able to display UI for tuning the values, and a share button exports a new JSON file to be checked back into source control.

	To use TunableSpec(name: "MainSpec"), the resources directory must contain a file MainSpec.json. That file has values and the information required to lay out a UI for tuning the values.

	A value can tuned with a slider or a switch.

	Sample JSON:

		[
			{
				"sliderMaxValue" : 300,
				"key" : "GridSpacing",
				"label" : "Grid Spacing",
				"sliderValue" : 175,
				"sliderMinValue" : 10
			},
			{
				"key" : "EnableClickySounds",
				"label" : "Clicky Sounds",
				"switchValue" : false
			}
		]

	or minimally,

		[
			{
				"key" : "GridSpacing",
				"sliderValue" : 175,
			},
			{
				"key" : "EnableClickySounds",
				"switchValue" : false
			}
		]

	Besides simple getters, "maintain" versions are provided so you can live update your UI. The maintenance block will be called whenever the value changes due to being tuned. For example, with

		spec.withKey("LabelText", owner: self) { (owner: UILabel, value: CGFloat) in
			owner.label.text = "\(value)"
		}

	the label text would live-update as you dragged the tuning slider. When the value type is inferrable from its use, you can write this more minimally as:

		spec.withKey("LabelAlpha", owner: self) { $0.label.alpha = $1 }

	The block argument is always invoked once right away so that the UI gets a correct initial value.

	The "owner" parameter is for avoiding leaks. If the owner is deallocated, the maintenance block will be as well. In the case below, self would leak, because the block keeps self alive and vice versa.

		spec.withKey("LabelText", owner:self) { owner, value in
			self.label.text = "\(value)" // LEAKS, DO NOT DO THIS, USE OWNER OR CAPTURE LABEL ITSELF
		}
*/
public class TunableSpec {
	private var spec: KFTunableSpec!
	public init(name: String) {
		spec = KFTunableSpec.specNamed(name) as KFTunableSpec?
		assert(spec != nil, "failed to load spec named \(name)")
	}

	// MARK: Getting Values

	public subscript(key: String) -> Double {
		return spec.doubleForKey(key)
	}

	public subscript(key: String) -> CGFloat {
		return CGFloat(spec.doubleForKey(key))
	}

	public subscript(key: String) -> Bool {
		return spec.boolForKey(key)
	}

	public func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, Double) -> ()) {
		spec.withDoubleForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, $1) })
	}

	public func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, CGFloat) -> ()) {
		spec.withDoubleForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, CGFloat($1)) })
	}

	public func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, Bool) -> ()) {
		spec.withBoolForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, $1) })
	}

	// MARK: Showing Tuning UI

	// useful as a metrics dictionary in -[NSLayoutConstraint constraintsWithVisualFormat:options:metrics:views:]
	public func dictionaryRepresentation() -> NSDictionary {
		return spec.dictionaryRepresentation()
	}

	public func twoFingerTripleTapGestureRecognizer() -> UIGestureRecognizer {
		return spec.twoFingerTripleTapGestureRecognizer()
	}

	public var controlsAreVisible: Bool {
		get {
			return spec.controlsAreVisible
		}
		set {
			spec.controlsAreVisible = newValue
		}
	}
}
