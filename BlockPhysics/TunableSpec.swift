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
	var _spec: KFTunableSpec!
	init(name: String) {
		_spec = KFTunableSpec.specNamed(name) as KFTunableSpec?
		assert(_spec != nil, "failed to load spec named \(name)")
	}

	subscript(key: String) -> Double {
		return _spec.doubleForKey(key)
	}

	subscript(key: String) -> CGFloat {
		return CGFloat(_spec.doubleForKey(key))
	}

	subscript(key: String) -> Bool {
		return _spec.boolForKey(key)
	}

	func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, Double) -> ()) {
		_spec.withDoubleForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, $1) })
	}

	func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, CGFloat) -> ()) {
		_spec.withDoubleForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, CGFloat($1)) })
	}

	func withKey<T where T: AnyObject>(key: String, owner weaklyHeldOwner: T, maintain maintenanceBlock: (T, Bool) -> ()) {
		_spec.withBoolForKey(key, owner: weaklyHeldOwner, maintain: { maintenanceBlock($0 as T, $1) })
	}

	// boo, it has to be an NSDictionary because the spec value types are heterogeneous
	var dictionaryRepresentation: NSDictionary {
		return _spec.dictionaryRepresentation()
	}

	var twoFingerTripleTapGestureRecognizer: UIGestureRecognizer {
		return _spec.twoFingerTripleTapGestureRecognizer()
	}

	var controlsAreVisible: Bool {
		get {
			return _spec.controlsAreVisible
		}
		set {
			_spec.controlsAreVisible = newValue
		}
	}
}
