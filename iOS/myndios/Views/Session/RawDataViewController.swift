//
//  ConnectionViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 17.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import RxSwift
import UIKit
import Charts
import Surge
import AccelerateWatch

class CustomDataSet: LineChartDataSet {
    override init(values: [ChartDataEntry]?, label: String?) {
        super.init(values: values, label: label)
        colors = [Constants.appTint]
        drawCirclesEnabled = false
        drawValuesEnabled = false
        lineWidth = 2.0
    }

    func replaceValues(with entries: [ChartDataEntry]) {
        values = entries
    }

    func flushValues() {
        values.removeAll()
    }

    required init() {
        super.init()
    }
}

class RawDataCell: UITableViewCell {
    
    @IBOutlet weak var rawDataView: LineChartView!
    @IBOutlet weak var channelLabel: UILabel!
    @IBOutlet weak var signalQuality: UILabel!
    
    private var rawDataBuffer = DSBuffer(8,fftIsSupported: false)
    private var displayMode: ProcessingMode = .signalQuality
    var spectrum = [Float]()

    
    func pushValue(_ value: Float) {
        rawDataBuffer.push(value)
    }
    
    func setSpectrum(to spectrum: [Float], withRate rate: Float) {
        if self.spectrum.count != spectrum.count {
            self.spectrum = spectrum
            return
        }
        
        for (c, _) in self.spectrum.enumerated() {
            self.spectrum[c] = self.spectrum[c] + ((spectrum[c] - self.spectrum[c]) / rate)
            //self.spectrum = spectrum
        }
    }
    
    func setDisplayMode(to mode: ProcessingMode) {
        configChart()
        displayMode = mode
        j = 1
        rawDataView.moveViewToX(0)
    }
    
    func updatePlot() {
        switch displayMode {
        case .signalQuality:
            updateRawData()
        case .noiseDetection:
            updateSpectrum()
        }
    }
    
    private var j = 1
    private func updateRawData() {
        if rawDataView.data!.getDataSetByIndex(0).entryCount > 128 {
            _ = rawDataView.data?.getDataSetByIndex(0).removeFirst()
        }
        
        _ = rawDataView.data?.getDataSetByIndex(0).addEntry(ChartDataEntry(x: Double(j) , y: Double(rawDataBuffer.mean)))
        //rawDataView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(128))
        //rawDataView.notifyDataSetChanged()
        rawDataView.moveViewToX(Double(self.j))
        self.j += 1
    }
    
    private func updateSpectrum() {
        guard let d = rawDataView.data?.getDataSetByIndex(0) as? CustomDataSet else {return}
        
        
        var newSpectrum = [ChartDataEntry]()
        for (c,n) in spectrum.enumerated() {
//            if channelLabel.text! == "Right Ear" {
//                print("\(channelLabel.text!) \(c) Hz: \(n) logBP")
//            }
            newSpectrum.append(ChartDataEntry(x: Double(c), y: Double(n)))
        }
        d.replaceValues(with: newSpectrum)
        rawDataView.moveViewToX(1)
    }
    
    // function to configure the linecharts
    func configChart() {
        rawDataBuffer.clear()
        j = 1
        
        guard let chart = rawDataView else {return}
        chart.isUserInteractionEnabled = false
        let initDataValue = ChartDataEntry(x: 0.0, y: 0.0)
        var dataEntry = [ChartDataEntry]()
        dataEntry.append(initDataValue)
        
        let dataSet = CustomDataSet(values: dataEntry, label: "Values")
        let data = LineChartData(dataSet: dataSet)
        
        dataSet.colors = [Constants.appTint]
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.lineWidth = 2.0
        
        //Chart config
        chart.setVisibleXRange(minXRange: 1.0, maxXRange: 128.0)
        chart.chartDescription?.text = ""
        chart.drawGridBackgroundEnabled = false
        chart.dragEnabled = true
        chart.rightAxis.enabled = false
        chart.leftAxis.enabled = true
        chart.drawBordersEnabled = false
        chart.drawGridBackgroundEnabled = false
        chart.xAxis.enabled = true
        chart.doubleTapToZoomEnabled = false
        chart.legend.enabled = false
        chart.autoScaleMinMaxEnabled = true
        chart.data = data //Add empty set
    }
}

/// In developer-mode, `RawDataView` can be accessed from the navigation bar once the headset was connected. It features the display of either raw EEG time series, or the EEG band-power spectrum. It is essentially a table view controller, where each table cell is a chart as defined above.
class RawDataViewController: UITableViewController {
    
    @IBOutlet weak var spectrumSwitch: UISwitch!
    
    weak var sessionVC: SessionViewController! = nil
    
    private var displayLink: CADisplayLink! = nil
    private var disposeBag = DisposeBag()
    private var chartSize = 128
    private var cells = [RawDataCell]()
    private weak var previousBarButtonItem: UIBarButtonItem! = nil
    private var mode: ProcessingMode! = nil
    
    ////
    // Factory
    ////
    
    static func make(_ sessionVC: SessionViewController) -> RawDataViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RawData") as! RawDataViewController
        viewController.sessionVC = sessionVC
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for i in 0...sessionVC.dataController.channels!.count - 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RawDataCell", for: IndexPath(row: i, section: 0)) as! RawDataCell
            cell.configChart()
            cell.channelLabel.textColor = Constants.appTint
            cell.channelLabel.text = sessionVC.dataController.channels![i]
            cells.append(cell)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.dataSource = self
        spectrumSwitch.isOn = false
        switchModes(self)
    }
    
    @IBAction func switchModes(_ sender: Any) {
        switch spectrumSwitch.isOn {
        case false:
            start(mode: .signalQuality)
            sessionVC.processingDelegate.start(mode: .signalQuality)
        case true:
            start(mode: .noiseDetection)
            sessionVC.processingDelegate.start(mode: .noiseDetection)
            
        }
    }
    
    @objc func done() {
        sessionVC.goTo(phase: sessionVC.currentPhase)
    }
    
    func start(mode: ProcessingMode = .signalQuality) {
        // just start processing if the mode is different
        //guard mode != self.mode else {return}
        stop()
        
        self.mode = mode
        cells.forEach {$0.setDisplayMode(to: mode)}
        
        switch mode {
        case .signalQuality:
            sessionVC.dataController.data.subscribe({block in self.updateCells(block.element!)}).disposed(by: disposeBag)
        case .noiseDetection:
            break
        }
        sessionVC.processingDelegate.avgSignalQuality.subscribe({data in DispatchQueue.main.async{self.updateLabels(data.element!)}}).disposed(by: disposeBag)
        
        displayLink = CADisplayLink(target: self, selector:#selector(updatePlots(_:)))
        displayLink.preferredFramesPerSecond = 30
        displayLink?.add(to: RunLoop.current, forMode: .common)
    }
    
    private func stop() {
        sessionVC.processingDelegate.stop()
        disposeBag = DisposeBag()
        displayLink?.invalidate()
        displayLink = nil
    }
    
    
    @objc func updatePlots(_ displayLink: CADisplayLink) {
        // if we look at spectra, update values in this function
        switch mode! {
        case .noiseDetection:
            for (c,n) in cells.enumerated() {
                n.setSpectrum(to: sessionVC.processingDelegate.spectrum[c], withRate: 60)
                n.updatePlot()
            }
        case .signalQuality:
            cells.forEach {$0.updatePlot()}
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }
    
    func updateCells(_ block: [Double]) {
        for (c,n) in block.enumerated() {
            cells[c].pushValue(Float(n))
        }
    }
    
    func updateLabels(_ block: [Double]) {
        for i in 0...block.count - 1 {
            cells[i].signalQuality.text = "Signal Quality: " + (String(format: "%.2f", (block[i])))
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessionVC.dataController.channels!.count
    }
}
