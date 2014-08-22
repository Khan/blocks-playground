//
//  TunableSpec.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/21/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import Foundation
import UIKit

public class TunableSpec {
	private var spec: KFTunableSpec!
	public init(name: String) {
		spec = KFTunableSpec.specNamed(name) as KFTunableSpec?
		assert(spec != nil, "failed to load spec named \(name)")
	}

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

	// boo, it has to be an NSDictionary because the spec value types are heterogeneous
	public var dictionaryRepresentation: NSDictionary {
		return spec.dictionaryRepresentation()
	}

	public var twoFingerTripleTapGestureRecognizer: UIGestureRecognizer {
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
