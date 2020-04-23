//
//  Extensions.swift
//  myndios
//
//  Created by Matthias Hohmann on 14.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//
// Various extensions of existing classes. Stack Overflow URLs are indicated where applicable for more information

import UIKit
import AVFoundation


/// https://stackoverflow.com/questions/24046164/how-do-i-get-a-reference-to-the-app-delegate-in-swift
extension UIViewController {
    var app:AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
}

/// this was used to have quick access to the original color scheme
extension UIColor {
    
    class var MP_Green: UIColor {
        return UIColor.init(red: 17/255, green: 102/255, blue: 86/255, alpha: 1)
    }
    
    class var MP_lightGreen: UIColor {
        return UIColor.init(red: 17/255, green: 102/255, blue: 86/255, alpha: 0.5)
    }
    
    class var MP_Grey: UIColor {
        return UIColor.init(red: 221/255, green: 222/255, blue: 214/255, alpha: 1)
    }
    
    class var MP_lightGrey: UIColor {
        return UIColor.init(red: 221/255, green: 222/255, blue: 214/255, alpha: 0.5)
    }
    
    class var MP_Blue: UIColor {
        return UIColor.init(red: 60/255, green: 104/255, blue: 145/255, alpha: 1.0)
    }
    
    class var MP_lightBlue: UIColor {
        return UIColor.init(red: 60/255, green: 104/255, blue: 145/255, alpha: 0.5)
    }
    
    class var MP_Red: UIColor {
        return UIColor.init(red: 129/255, green: 41/255, blue: 54/255, alpha: 1.0)
    }
    
    class var MP_Orange: UIColor {
        return UIColor.init(red: 220/255, green: 138/255, blue: 35/255, alpha: 1.0)
    }
    
}

/// https://stackoverflow.com/questions/33632266/animate-text-change-of-uilabel
extension UIView {
    func pushTransition(_ duration:CFTimeInterval = 0.3) {
        let animation:CATransition = CATransition()
        animation.timingFunction =  CAMediaTimingFunction(name:
            .easeInEaseOut)
        animation.type = .push
        animation.subtype = .fromRight
        animation.duration = duration
        animation.fillMode = .removed
        layer.add(animation, forKey: CATransitionType.push.rawValue)
    }
    
    func makeCircular() {
        self.layer.cornerRadius = self.bounds.width / 2.0
        self.clipsToBounds = true
        self.layer.masksToBounds = true
    }
}

/// https://stackoverflow.com/questions/33632266/animate-text-change-of-uilabel
extension UILabel {
    func pushText(_ text: String, _ duration: CFTimeInterval = 0.3) {
        self.pushTransition(duration)
        self.text = text
    }
}

/// https://stackoverflow.com/questions/33632266/animate-text-change-of-uilabel
extension UITextView {
    func pushText(_ text: String, _ duration: CFTimeInterval = 0.3) {
        self.pushTransition(duration)
        self.text = text
    }
}

/// https://stackoverflow.com/questions/12904410/completion-block-for-popviewcontroller
extension UINavigationController {
    
    public func pushViewController( _  viewController: UIViewController,
                                   animated: Bool,
                                   completion: (()->())?) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        pushViewController(viewController, animated: animated)
        CATransaction.commit()
    }
    
    public func popToRootViewController(animated: Bool,
                                   completion: (()->())?) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        popToRootViewController(animated: animated)
        CATransaction.commit()
    }
    
}

/// https://stackoverflow.com/questions/24026510/how-do-i-shuffle-an-array-in-swift
extension MutableCollection {
    /// Shuffles the contents of this collection.
    mutating func shuffle() {
        let c = count
        guard c > 1 else { return }
        
        for (firstUnshuffled, unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
            let d: Int = numericCast(arc4random_uniform(numericCast(unshuffledCount)))
            let i = index(firstUnshuffled, offsetBy: d)
            swapAt(firstUnshuffled, i)
        }
    }
}

/// https://stackoverflow.com/questions/24026510/how-do-i-shuffle-an-array-in-swift
extension Sequence {
    /// Returns an array with the contents of this sequence, shuffled.
    func shuffled() -> [Element] {
        var result = Array(self)
        result.shuffle()
        return result
    }
}

extension Date {
    func timeStamp() -> String {
        let dateFormatter = DateFormatter()
        //dateFormatter.locale = NSLocale.autoupdatingCurrent
        dateFormatter.setLocalizedDateFormatFromTemplate("MM dd yyyy, hh:mm:ss ZZZZ")
        return dateFormatter.string(from: self)
    }
}

/// https://stackoverflow.com/questions/24494784/get-class-name-of-object-as-string-in-swift
extension NSObject {
    var className: String {
        return String(describing: type(of: self))
    }
    
    class var className: String {
        return String(describing: self)
    }
}

/// https://stackoverflow.com/questions/27292255/how-to-loop-over-struct-properties-in-swift
extension UIViewController {
    func allProperties() throws -> [String: Any] {
        
        var result: [String: Any] = [:]
        
        let mirror = Mirror(reflecting: self)
        
        // Optional check to make sure we're iterating over a struct or class
        guard let style = mirror.displayStyle, style == .struct || style == .class else {
            throw NSError()
        }
        
        for (property, value) in mirror.children {
            guard let property = property else {
                continue
            }
            
            result[property] = value
        }
        
        return result
    }
}

/// https://stackoverflow.com/questions/41387549/how-to-align-text-inside-textview-vertically
extension UITextView {
    
    func centerVertically() {
        let fittingSize = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        let size = sizeThatFits(fittingSize)
        let topOffset = (bounds.size.height - size.height * zoomScale) / 2
        let positiveTopOffset = max(1, topOffset)
        contentOffset.y = -positiveTopOffset
    }
    
}

/// https://danilovdev.blogspot.com/2017/10/how-to-add-border-just-to-one-side-of.html
extension UIView {
    
    func addBorders(edges: UIRectEdge = .all, color: UIColor = .black, width: CGFloat = 1.0) {
        
        func createBorder() -> UIView {
            let borderView = UIView(frame: CGRect.zero)
            borderView.translatesAutoresizingMaskIntoConstraints = false
            borderView.backgroundColor = color
            return borderView
        }
        
        if (edges.contains(.all) || edges.contains(.top)) {
            let topBorder = createBorder()
            self.addSubview(topBorder)
            NSLayoutConstraint.activate([
                topBorder.topAnchor.constraint(equalTo: self.topAnchor),
                topBorder.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                topBorder.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                topBorder.heightAnchor.constraint(equalToConstant: width)
                ])
        }
        if (edges.contains(.all) || edges.contains(.left)) {
            let leftBorder = createBorder()
            self.addSubview(leftBorder)
            NSLayoutConstraint.activate([
                leftBorder.topAnchor.constraint(equalTo: self.topAnchor),
                leftBorder.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                leftBorder.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                leftBorder.widthAnchor.constraint(equalToConstant: width)
                ])
        }
        if (edges.contains(.all) || edges.contains(.right)) {
            let rightBorder = createBorder()
            self.addSubview(rightBorder)
            NSLayoutConstraint.activate([
                rightBorder.topAnchor.constraint(equalTo: self.topAnchor),
                rightBorder.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                rightBorder.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                rightBorder.widthAnchor.constraint(equalToConstant: width)
                ])
        }
        if (edges.contains(.all) || edges.contains(.bottom)) {
            let bottomBorder = createBorder()
            self.addSubview(bottomBorder)
            NSLayoutConstraint.activate([
                bottomBorder.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                bottomBorder.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                bottomBorder.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                bottomBorder.heightAnchor.constraint(equalToConstant: width)
                ])
        }
    }
}


/// via https://stackoverflow.com/questions/18756640/width-and-height-equal-to-its-superview-using-autolayout-programmatically
extension UIView {
    
    func scaleToFillSuperView(withConstant constant: CGFloat) {
        guard self.superview != nil else {return}
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: self,
                           attribute: .leading,
                           relatedBy: .equal,
                           toItem: superview,
                           attribute: .leading,
                           multiplier: 1.0,
                           constant: constant).isActive = true
        
        NSLayoutConstraint(item: self,
                           attribute: .trailing,
                           relatedBy: .equal,
                           toItem: superview,
                           attribute: .trailing,
                           multiplier: 1.0,
                           constant: constant).isActive = true
        
        NSLayoutConstraint(item: self,
                           attribute: .top,
                           relatedBy: .equal,
                           toItem: superview,
                           attribute: .top,
                           multiplier: 1.0,
                           constant: constant).isActive = true
        
        NSLayoutConstraint(item: self,
                           attribute: .bottom,
                           relatedBy: .equal,
                           toItem: superview,
                           attribute: .bottom,
                           multiplier: 1.0,
                           constant: constant).isActive = true
    }
    
}

/// https://stackoverflow.com/questions/34215320/use-storyboard-to-mask-uiview-and-give-rounded-corners
extension UIView {
    
    @IBInspectable var cornerRadiusV: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable var borderWidthV: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    @IBInspectable var borderColorV: UIColor? {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }
}

/// https://gist.github.com/SerxhioGugo/30987682a97b9b03dac37361e6ffd145
extension UIView {
    
    // OUTPUT 1
    func dropShadow(scale: Bool = true) {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: -1, height: 1)
        layer.shadowRadius = 1
   
        
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
    
    // OUTPUT 2
    func dropShadow(color: UIColor, opacity: Float = 0.5, offSet: CGSize, radius: CGFloat = 1, scale: Bool = true) {
        layer.masksToBounds = false
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offSet
        layer.shadowRadius = radius

        
        layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
}

extension TimeInterval{
    
    func stringFromTimeInterval(truncateZeroValues noZeros: Bool = true) -> String {
        
        let ti = NSInteger(self)
        
        let hours = (ti / 3600)
        let minutes = (ti / 60) % 60
        let seconds = ti % 60
        
        if !noZeros {
            return String(format: "in %0.1d:%0.1d:%0.1d",hours,minutes,seconds)
        }
        
        if Int(hours) != 0 {
            return String(format: "%0.1d \(NSLocalizedString("#hours#", comment: ""))",hours)
        } else if Int(minutes) != 0 {
            return String(format: "%0.1d \(NSLocalizedString("#minutes#", comment: ""))",minutes)
        } else if Int(seconds) != 0 {
            return String(format: "%0.1d \(NSLocalizedString("#seconds#", comment: ""))",seconds)
        } else {
            return "now"
        }
    }
}

/// https://stackoverflow.com/questions/32851720/how-to-remove-special-characters-from-string-in-swift-2
extension String {
    
    var alphanumeric: String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890")
        return self.filter {okayChars.contains($0) }
    }
}

/// this extends the string class and fills in any placeholders within it
extension String {
    mutating func mutatingWithFilledPlaceholders(withOptionalArguments dict: [String: String]? = nil) {
        let defaults = UserDefaults.standard
        
        // Names
        self = self.replacingOccurrences(of: "#patientName#", with: defaults.string(forKey: "patientName") ?? NSLocalizedString("#participant#", comment: ""))
        self = self.replacingOccurrences(of: "#helperName#", with: defaults.string(forKey: "helperName")  ?? NSLocalizedString("#helper#", comment: ""))
    
        if defaults.bool(forKey: "hasHelper") {
            self = self.replacingOccurrences(of: "#ofPatient#", with: String(
                "\(NSLocalizedString("#of#", comment: "")) \(defaults.string(forKey: "patientName") ?? NSLocalizedString("#participant#", comment: ""))"))
            self = self.replacingOccurrences(of: "#possessivePatient#", with: "\(defaults.string(forKey: "patientName") ?? NSLocalizedString("#participant#", comment: ""))'s")
        } else {
            self = self.replacingOccurrences(of: "#ofPatient#", with: "")
            self = self.replacingOccurrences(of: "#possessivePatient#", with: NSLocalizedString("#your#", comment: ""))
        }
        
        // Additional placeholders that may have been supplied
        guard let placeholders = dict else {return}
        
        for placeholder in placeholders {
            self = self.replacingOccurrences(of: placeholder.key, with: placeholder.value)
        }
        
        // Check if any placeholder was not filled, remove it and show a warning if so
        if self.contains("#") {
            print("[STRING WARNING] unreplaced Placeholders found")
        }
    }
    
    func withFilledPlaceholders(withOptionalArguments dict: [String: String]? = nil) -> String {
        var string = self
        string.mutatingWithFilledPlaceholders(withOptionalArguments: dict)
        return string
    }
}

/// via https://stackoverflow.com/questions/24336187/how-to-present-a-modal-atop-the-current-view-in-swift, used for returning to login view in full screen.
extension UIViewController {
    func presentOnRoot(`with` viewController : UIViewController){
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        self.present(navigationController, animated: false, completion: nil)
    }
}
