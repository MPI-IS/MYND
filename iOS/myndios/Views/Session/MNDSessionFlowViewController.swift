//
//  MNDSessionFlowViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 25.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit

/// this is instantiated by either questionnare or recording container views to transition between the sequental steps of the scenario. It is essentially a page view controller without user input.
class MNDSessionFlowViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    /////////////////////////
    // MARK: - Dependencies
    
    var sessionFlow = [MNDSessionStep: UIViewController]()
    var currentPhase: MNDSessionStep!
    
    /////////////////////////
    // MARK: - Internal Properties
    
    fileprivate var currentRecordingFlowIndex: Int = -1
    fileprivate var currentVCs: [UIViewController]! = nil
    
    /////////////////////////
    // MARK: - View Control
    
    override init(transitionStyle style: UIPageViewController.TransitionStyle, navigationOrientation: UIPageViewController.NavigationOrientation, options: [UIPageViewController.OptionsKey : Any]? = nil) {
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: options)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    }
    
    override func viewDidLoad() {
        dataSource = nil
        delegate = self
    }
    
    /////////////////////////
    // MARK: - User Interaction
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = currentVCs.index(of: viewController) else {
            return nil
        }
        let previousIndex = viewControllerIndex - 1
        guard previousIndex >= 0 else {
            return nil
        }
        guard currentVCs.count > previousIndex else {
            return nil
        }
        return currentVCs[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = currentVCs.index(of: viewController) else {
            return nil
        }
        let nextIndex = viewControllerIndex + 1
        guard currentVCs.count != nextIndex else {
            return nil
        }
        guard currentVCs.count > nextIndex else {
            return nil
        }
        return currentVCs[nextIndex]
    }
    
    /////////////////////////
    // MARK: - Recording Flow
    
    
    func goTo(phase: MNDSessionStep, direction: UIPageViewController.NavigationDirection = .forward, completion: (() -> ())? = nil) {
        // make sure the phase exists and its different from what we currently see
        guard let vcForPhase = sessionFlow[phase],
            currentPhase != phase else {return}
        currentPhase = phase
        setViewControllers([vcForPhase],
                           direction: direction,
                           animated: true,
                           completion: {_ in completion?()})
    }
    
    /////////////////////////
    // MARK: - Internal
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

    }
}
