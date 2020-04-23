//
//  FeedbackView.swift
//  myndios
//
//  Created by Matthias Hohmann on 07.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import RxSwift
import Surge
import Charts
import UICircularProgressRing

/**
 UNUSED: A few feedback classes were implemented to provide visual feedback during recording, but ultimately remained unused. There are left in the code to be expanded upon. The `FeedbackController` was implemented to compute necessary statistics for feedback display. `ScenarioView`calls and controls the corresponding `FeedbackView`, that displays feedback as a moving wave on the whole screen. In terms of visuals, `ProgressView`, `CountdownTimer`, and `InstructionView` provide a visual representation of the required action during a trial, and remaining trial time.
 */
class FeedbackViewController: UIViewController, FeedbackControllerDelegate {
 
    private var displayLink: CADisplayLink! = nil
    private var buffer: Double = -1.0
    private var oldPoint = 1.0
    
    var feedbackDelegate: FeedbackController?
    var disposeBag = DisposeBag()

    @IBOutlet weak var feedbackView: LineChartView!
    @IBOutlet weak var instructionView: InstructionView!
    @IBOutlet weak var progress: SignalQualityRingView!
    var currentClass = Feedback.none
    var trialLog = [(String, Double)]()

    override func viewDidLoad(){
        super.viewDidLoad()
        feedbackView.noDataText = ""
    }
    
    func startFeedback() {
        enableDrawing(true)
    }
    
    func stopFeedback() {
        enableDrawing(false)
    }
    
    func feedbackController(_ feedbackController: FeedbackController, didUpdateFeedbackValue value: CGFloat) {
        buffer = Double(value)
    }
    
    fileprivate func enableDrawing(_ enable: Bool) {
        if enable {
            progress.isHidden = false
            feedbackDelegate?.start(.calibrating)
            feedbackDelegate?.feedbackDelegate = self
            j = 1
            configChart(feedbackView)
            displayLink = CADisplayLink(target: self, selector:#selector(updateDrawing(_:)))
            displayLink.preferredFramesPerSecond = 30
            displayLink?.add(to: RunLoop.current, forMode: .common)
        } else {
            progress.isHidden = true
            progress.startProgress(to: 0.0, duration: 0.3)
            instructionView.removeImage()
            displayLink?.invalidate()
            displayLink = nil
            disposeBag = DisposeBag()
            feedbackView.data?.getDataSetByIndex(0).setColor(UIColor.white)
            feedbackView.notifyDataSetChanged()
            j = 1
        }
    }
    
    var j = 1
    @objc func updateDrawing(_ displayLink: CADisplayLink) {
        var newPoint = oldPoint + (buffer - oldPoint)/60

        if newPoint >= feedbackView.leftAxis.axisMaximum {
            newPoint = feedbackView.leftAxis.axisMaximum
        }
        if newPoint <= feedbackView.leftAxis.axisMinimum {
            newPoint = feedbackView.leftAxis.axisMinimum
        }
        
        updateProgress(newPoint)
        _ = feedbackView.data?.getDataSetByIndex(0).addEntry(ChartDataEntry(x: Double(self.j) , y: newPoint))
        feedbackView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(64))
        feedbackView.notifyDataSetChanged()
        feedbackView.moveViewToX(Double(self.j))
        //feedbackView.highlightValue(x: Double(self.j - 5), dataSetIndex: 0)
        oldPoint = newPoint
        self.j += 1
    }
    
    func updateProgress(_ newPoint: Double) {
        if currentClass == .up {
            if newPoint > 4 {
                progress.startProgress(to: progress.currentValue! + 0.2, duration: 0.0)
            }
        }
        if currentClass == .down {
            if newPoint < 2 {
                progress.startProgress(to: progress.currentValue! + 0.2, duration: 0.0)
            }
        }
        if !instructionView.wasSucessful &&  progress.currentValue! >= 100 {
            instructionView.success(withDelay: 0, blocking: false)
        }
    }
    
    func updateClass(_ classLabel: Feedback, withTimeout timeout: TimeInterval) {
        trialLog.append((String(describing: currentClass), Double(progress.currentValue!)))
        currentClass = classLabel
        instructionView.stopCountdown()
        progress.startProgress(to: 0.0, duration: 0.3)
        switch classLabel {
        case .wait:
            instructionView.setInstruction(named: "wait", withImageNamed: "Wait", withTimeout: timeout)
            feedbackView.data?.getDataSetByIndex(0).setColor(UIColor.MP_Grey)
            feedbackDelegate?.start(.calibrating)
        case .up:
            instructionView.setInstruction(named: "up", withImageNamed: "Up", withTimeout: timeout)
            feedbackView.data?.getDataSetByIndex(0).setColor(Constants.appTint)
            feedbackDelegate?.start(.giving)
        case .down:
            instructionView.setInstruction(named: "down", withImageNamed: "Down", withTimeout: timeout)
            feedbackView.data?.getDataSetByIndex(0).setColor(Constants.appTint)
            feedbackDelegate?.start(.giving)
        case .none:
            instructionView.setInstruction(named: "none")
            feedbackView.data?.getDataSetByIndex(0).setColor(UIColor.MP_Grey)
            feedbackDelegate?.stop()
        }
    }
    
    // Private function to configure the linecharts
    func configChart(_ chart: LineChartView) {
        progress.isCheckboxActivated = false
        chart.isUserInteractionEnabled = false
        let initDataValue = ChartDataEntry(x: 0.0, y: 0.0)
        var dataEntry = [ChartDataEntry]()
        dataEntry.append(initDataValue)
        
        let dataSet = LineChartDataSet(values: dataEntry, label: "Values")
        dataSet.highlightLineWidth = 10.0
        let data = LineChartData(dataSet: dataSet)
        data.highlightEnabled = true
        
        dataSet.colors = [Constants.appTint]
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.lineWidth = 4.0
        
        //Chart config
        chart.setVisibleYRange(minYRange: 0, maxYRange: 6, axis: .left)
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.axisMaximum = 6
        chart.chartDescription?.text = ""
        chart.drawGridBackgroundEnabled = false
        chart.dragEnabled = true
        chart.rightAxis.enabled = false
        chart.leftAxis.enabled = false
        chart.drawBordersEnabled = false
        chart.drawGridBackgroundEnabled = false
        chart.xAxis.enabled = false
        chart.doubleTapToZoomEnabled = false
        chart.legend.enabled = false
        chart.autoScaleMinMaxEnabled = true
        chart.data = data //Add empty set
    }
}
