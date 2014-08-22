//
//  TunableSpec.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/21/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import Foundation
import UIKit

class TunableSpec {
	private var spec: KFTunableSpec!
	init(name: String) {
		spec = KFTunableSpec.specNamed(name) as KFTunableSpec?
		assert(spec != nil, "failed to load spec named \(name)")
	}

	subscript(key: String) -> Double {
		return spec.doubleForKey(key)
	}

	subscript(key: String) -> CGFloat {
		return CGFloat(spec.doubleForKey(key))
	}

	subscript(key: String) -> Bool {
		return spec.boolForKey(key)
	}

	func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, Double) -> ()) {
		spec.withDoubleForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, $1) })
	}

	func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, CGFloat) -> ()) {
		spec.withDoubleForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, CGFloat($1)) })
	}

	func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, Bool) -> ()) {
		spec.withBoolForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, $1) })
	}

	// boo, it has to be an NSDictionary because the spec value types are heterogeneous
	var dictionaryRepresentation: NSDictionary {
		return spec.dictionaryRepresentation()
	}

	var twoFingerTripleTapGestureRecognizer: UIGestureRecognizer {
		return spec.twoFingerTripleTapGestureRecognizer()
	}

	var controlsAreVisible: Bool {
		get {
			return spec.controlsAreVisible
		}
		set {
			spec.controlsAreVisible = newValue
		}
	}
}
