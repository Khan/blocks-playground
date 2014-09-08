
//  AppDelegate.swift
//  BlockPhysics
//
//  Created by Andy Matuschak on 8/12/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		UIApplication.sharedApplication().statusBarHidden = true
		return true
	}
}

