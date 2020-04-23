//
//  BannerController.swift
//  myndios
//
//  Created by Matthias Hohmann on 09.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import NotificationBannerSwift
import UserNotifications
import SwiftyJSON

/// The `BannerController` is a collection of functions that handles the display of messages outside of the "regular" sequence.
class BannerController: NSObject {
    
    static let shared = BannerController()
    
    private let nc = NotificationCenter.default
    private let defaults = UserDefaults.standard
    private var banner: StatusBarNotificationBanner?
    
    override init() {
        super.init()
        nc.addObserver(self, selector: #selector(showMessage), name: NSNotification.Name("bannerMessage"), object: nil)
        nc.addObserver(self, selector: #selector(hideMessage), name: NSNotification.Name("bannerMessageCanceled"), object: nil)
    }
    
    /// this is used to handle annoucements from the download webdav, if any
    func setRemoteMessage(messageJSON: JSON) {
        
        let locale = NSLocale.autoupdatingCurrent.languageCode ?? "en"
        // unwrap the type of the message, else return
        guard messageJSON["type"].string != nil,
            let messages = messageJSON["messages"].array else {return}
        
        // get the message for the right locale, else return
        guard let message = messages.first(where: {$0["locale"].string == locale}) else {return}
        
        let title = message["title"].string!.withFilledPlaceholders()
        let text = message["text"].string!.withFilledPlaceholders()
              
        // Finally, set the message in user defaults
        defaults.set(title, forKey: "remoteMessageTitle")
        defaults.set(text, forKey: "remoteMessageText")
        defaults.set(true, forKey: "shouldPresentRemoteMessage")
        DispatchQueue.main.async {self.nc.post(name: Notification.Name("didReceiveRemoteMessage"), object: nil)}
    }
    
    func getRemoteMessageIfAny() -> (title: String, text: String)? {
        // if there is no message to be displayed or the message cannot be loaded, return nil
        guard defaults.bool(forKey: "shouldPresentRemoteMessage"),
            let title = defaults.string(forKey: "remoteMessageTitle"),
            let text = defaults.string(forKey: "remoteMessageText") else {return nil}
        
        return (title: title, text: text)
    }
    
    func didPresentMessage() {
      defaults.set(false, forKey: "shouldPresentRemoteMessage")
    }
    
    /// this schedules an iOS notification whenever the current day time out date passed, to inform subjects that the next set of scenarios can be completed
    func scheduleUserNotificationForDay(onDate date: Date) {
        
        // create content
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("#UNNextDayTitle#", comment: "")
        content.body = "\(defaults.string(forKey: "patientName") ?? "Dear participant"), \(NSLocalizedString("#UNNextDayText#", comment: ""))"
        content.categoryIdentifier = "alarm"
        content.sound = UNNotificationSound.default
        
        // create timeOut
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelUserNotificationForDay() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// this  is used to display short messages in the status bar
    @objc func showMessage(message: Notification) {
        banner = StatusBarNotificationBanner(title: message.userInfo!["message"] as! String)
        print(message.userInfo!["message"] as! String)
        switch message.userInfo!["style"] as! String{
        case "info":
            banner?.backgroundColor = .MP_Blue
            banner?.show()
        case "error":
            banner?.backgroundColor = .MP_Red
            banner?.show()
        case "devError":
            if defaults.bool(forKey: "isDeveloperModeEnabled") {
              banner?.backgroundColor = .MP_Red
              banner?.show()
              banner?.dismissOnTap = true
            }
        case "devSuccess":
            if defaults.bool(forKey: "isDeveloperModeEnabled") {
                banner?.backgroundColor = .MP_Green
                banner?.show()
                banner?.dismissOnTap = true
            }
        default:
            break
        }
        
        if message.userInfo!["say"] as! Bool {
            TTSController.shared.say(message.userInfo!["message"] as! String)
        }
    }
    
    @objc func hideMessage() {
        banner?.dismiss()
    }
    
    /// this is used to make an acoustic annoucement of certain events during recording
    func makeGeneralAnnouncement(forSignal signal: DeviceStates) {
        var announcement: String?
        switch signal {
        case .found:
            announcement = NSLocalizedString("#foundHeadset#", comment: "")
        case .connected:
            announcement = NSLocalizedString("#connectedHeadset#", comment: "")
        case .disconnected:
            announcement = NSLocalizedString("#disconnectedHeadset#", comment: "")
        case .onHead:
            announcement = NSLocalizedString("#headsetOnHead#", comment: "")
        case .goodSignal:
            announcement = NSLocalizedString("#goodSignal#", comment: "")
        case .goodSignalFront:
            announcement = NSLocalizedString("#goodSignalFront#", comment: "")
        case .goodSignalBack:
            announcement = NSLocalizedString("#goodSignalBack#", comment: "")
        default:
            break
        }
        announcement != nil ? (TTSController.shared.say(announcement!, force: true)) : ()
    }
}
