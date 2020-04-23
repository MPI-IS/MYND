//
//  AppDelegate.swift
//  myndios
//
//  Created by Matthias Hohmann on 15.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import NotificationBannerSwift

/// # Basic settings that span the whole application
/**
 ## Usage
 This class is instanciated automatically as root of the application
 
 ## Features
 - Set the global tint based on the value in Constants
 - Configure switches with the global tint
 - Configure tooltips with the global tint
 - If the user previously signed up, we take them straight to the Scenario Select, otherwise we show the SignUp screen
 - If the app was launched for the first time or was reset, ensure that some defaults are set from the beginning
 
 */
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    // MARK: - Dependencies
    private let defaults: UserDefaults = UserDefaults.standard
    private let nc = NotificationCenter.default
    private let study = StudyController.shared
    private let bannerController = BannerController.shared
    
    /// This function is called when the app is launched for the first time
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Make sure the device does not go to sleep
        application.isIdleTimerDisabled = true
        
        /// Set the global tint based on the value in Constants
        window?.tintColor = Constants.appTint
        
        /// Set all switches to the global tint
        UISwitch.appearance().onTintColor = Constants.appTint
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: Constants.appTint]
        
        /// If the user previously signed up, we take them straight to the Scenario Select, otherwise we show the SignUp screen
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        var initialViewController: UIViewController?
        var activeStudy: Studies?
        
        // Cycle through all potential studies and look for a savefile
        for study in Studies.allValues {
            if let saveFile = defaults.dictionary(forKey: study.rawValue) {
                if saveFile["enrolled"] as! Bool && saveFile["active"] as! Bool {
                   activeStudy = study
                }
            }
        }
        
        // If there was no savefile, start with login screen, else go to mainView and load the active study
        if activeStudy != nil {
            study.loadAndSetStudy(activeStudy!)
            initialViewController = storyboard.instantiateViewController(withIdentifier: "MainViewController")
        } else {
            initialViewController == nil ? (initialViewController = storyboard.instantiateViewController(withIdentifier: "LoginView")) : ()
            print("App was reset or first launched")
            Constants.setUserDefaults()
        }
        
        window?.rootViewController = initialViewController
        window?.makeKeyAndVisible()
    
        return true
    }
    

    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        // If a recording was happening when the app entered background, end it here.
        TTSController.shared.stop()
        DataController.shared.stop()
        if let mainView = window?.rootViewController as? MainViewController {
            mainView.nav.popToRootViewController(animated: true)
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        applicationDidEnterBackground(application)
    }

    
}
