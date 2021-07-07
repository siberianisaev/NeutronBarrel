//
//  AppDelegate.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 08.01.15.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, ProcessorDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var activity: NSProgressIndicator!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var correlationsView: CorrelationsView!
    @IBOutlet weak var labelVersion: NSTextField!
    @IBOutlet weak var labelBranch: NSTextField!
    @IBOutlet weak var viewBranchStatus: NSView!
    @IBOutlet weak var labelTotalTime: NSTextField!
    @IBOutlet weak var labelProcessingFileName: NSTextField!
    @IBOutlet weak var labelFirstDataFileName: NSTextField!
    @IBOutlet weak var labelCalibrationFileName: NSTextField!
    @IBOutlet weak var labelStripsConfigurationFileName: NSTextField!
    @IBOutlet weak var labelTask: NSTextField!
    @IBOutlet weak var sfSourceControl: NSSegmentedControl!
    @IBOutlet weak var indicatorData: NSTextField!
    @IBOutlet weak var indicatorCalibration: NSTextField!
    @IBOutlet weak var indicatorStripsConfig: NSTextField!
    @IBOutlet weak var buttonRun: NSButton!
    @IBOutlet weak var recoilTypeArrayController: NSArrayController!
    @IBOutlet weak var recoilBackTypeArrayController: NSArrayController!
    @IBOutlet weak var buttonRemoveCalibration: NSButton!
    @IBOutlet weak var buttonRemoveStripsConfiguration: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    @IBOutlet weak var actionsView: NSView!
    @IBOutlet weak var resultsFolderButton: NSButton!
    
    fileprivate var viewerController: ViewerController?
    fileprivate var calculationsController: CalculationsController?
    fileprivate var startDate: Date?
    fileprivate var timer: Timer?
    
    func readSettings() {
        sResultsFolderName = Settings.getStringSetting(.ResultsFolderName) ?? ""
        gammaStart = Settings.getBoolSetting(.GammaStart)
        gammaRequired = Settings.getBoolSetting(.RequiredGamma)
        sMinGammaEnergy = String(format: "%d", Settings.getIntSetting(.MinGammaEnergy)) // channel
        sMaxGammaEnergy = String(format: "%d", Settings.getIntSetting(.MaxGammaEnergy)) // channel
        sMaxGammaTime = String(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
        sMaxGammaBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxGammaBackwardTime)) // mks
        sMaxNeutronTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
        sMaxNeutronBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronBackwardTime)) // mks
        neutronsPositions = Settings.getBoolSetting(.NeutronsPositions)
        sfSourceControl.selectedSegment = Settings.getIntSetting(.SFSource)
    }
    
    @IBInspectable dynamic var sResultsFolderName = "" {
        didSet {
            resultsFolderButton.isHidden = sResultsFolderName.isEmpty
        }
    }
    
    @IBInspectable dynamic var gammaStart: Bool = false
    @IBInspectable dynamic var gammaRequired: Bool = false
    @IBInspectable dynamic var sMinGammaEnergy: String = ""
    @IBInspectable dynamic var sMaxGammaEnergy: String = ""
    @IBInspectable dynamic var neutronsPositions: Bool = false
    @IBInspectable dynamic var sMaxGammaTime: String = ""
    @IBInspectable dynamic var sMaxGammaBackwardTime: String = ""
    @IBInspectable dynamic var sMaxNeutronTime: String = ""
    @IBInspectable dynamic var sMaxNeutronBackwardTime: String = ""
    @IBInspectable dynamic var sfSourcePlaced: Bool = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        readSettings()
        for i in [indicatorData, indicatorCalibration, indicatorStripsConfig] {
            setSelected(false, indicator: i)
        }
        showAppVersion()
        updateRunState(withDockTitle: false)
    }
    
    @IBAction func removeCalibration(_ sender: Any) {
        setSelected(false, indicator: indicatorCalibration)
        Calibration.clean()
        buttonRemoveCalibration.isHidden = true
        showFilePaths(nil, label: labelCalibrationFileName)
    }
    
    @IBAction func removeStripsConfiguration(_ sender: Any) {
        setSelected(false, indicator: indicatorStripsConfig)
        StripDetectorManager.cleanStripConfigs()
        buttonRemoveStripsConfiguration.isHidden = true
        showFilePaths(nil, label: labelStripsConfigurationFileName)
    }
    
    @IBAction func calculations(_ sender: Any) {
        if nil == calculationsController {
            calculationsController = CalculationsController(windowNibName: NSNib.Name("CalculationsController"))
        }
        calculationsController?.showWindow(nil)
    }
    
    @IBAction func viewer(_ sender: Any) {
        if nil == viewerController {
            viewerController = ViewerController(windowNibName: NSNib.Name("ViewerController"))
        }
        viewerController?.showWindow(nil)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDockTitleBadge("")
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        saveSettings()
    }
    
    fileprivate func setSelected(_ selected: Bool, indicator: NSTextField?) {
        indicator?.textColor = selected ? NSColor.green : NSColor.red
        indicator?.stringValue = selected ? "✓" : "×"
    }
    
    @IBAction func cancel(_ sender: Any) {
        operationQueue.cancelAllOperations()
        for (_, value) in operations {
            value.stop()
        }
        operations.removeAll()
        updateRunState()
    }
    
    @IBAction func start(_ sender: AnyObject?) {
        correlationsView.reset()
        
        let sc = SearchCriteria()
        sc.resultsFolderName = sResultsFolderName
        sc.neutronsPositions = neutronsPositions
        sc.placedSFSource = SFSource(rawValue: sfSourceControl.selectedSegment)
        sc.minGammaEnergy = UInt64(sMinGammaEnergy) ?? 0
        sc.maxGammaEnergy = UInt64(sMaxGammaEnergy) ?? 0
        sc.maxGammaTime = UInt64(sMaxGammaTime) ?? 0
        sc.maxGammaBackwardTime = UInt64(sMaxGammaBackwardTime) ?? 0
        sc.maxNeutronTime = UInt64(sMaxNeutronTime) ?? 0
        sc.maxNeutronBackwardTime = UInt64(sMaxNeutronBackwardTime) ?? 0
        sc.gammaStart = gammaStart
        sc.requiredGamma = gammaRequired
        
        let id = UUID().uuidString
        let processor = Processor(criteria: sc, delegate: self)
        operations[id] = processor
        updateRunState()
        
        let operation = BlockOperation()
        operation.queuePriority = .high
        operation.name = id
        weak var weakOperation = operation
        operation.addExecutionBlock({
            if weakOperation?.isCancelled == false {
                processor.processDataWith(completion: { [weak self] in
                    self?.operations[id] = nil
                    self?.updateRunState()
                })
            } else {
                DispatchQueue.main.async(execute: { [weak self] in
                    self?.operations[id] = nil
                    self?.updateRunState()
                })
            }
        })
        operationQueue.addOperation(operation)
    }
    
    fileprivate var operations = [String: Processor]()
    
    fileprivate var _operationQueue: OperationQueue?
    fileprivate var operationQueue: OperationQueue {
        if let oq = self._operationQueue {
            return oq
        }
        let op = OperationQueue()
        op.maxConcurrentOperationCount = 1
        op.name = "Processing queue"
        self._operationQueue = op
        return op
    }
    
    fileprivate func updateRunState(withDockTitle: Bool = true) {
        let count = operations.count
        let run = count > 0
        buttonCancel.isHidden = !run
        labelTask.isHidden = !run
        let s = count == 1 ? "" : "s"
        labelTask.stringValue = "\(count) task\(s) processing"
        progressIndicator?.doubleValue = 0.0
        progressIndicator?.isHidden = !run
        if run {
            activity?.startAnimation(self)
            startTimer()
            progressIndicator?.startAnimation(self)
            saveSettings()
        } else {
            activity?.stopAnimation(self)
            stopTimer()
            progressIndicator.stopAnimation(self)
        }
        if withDockTitle {
            showDockTitleBadge((run || NSApplication.shared.isActive) ? "" : "1")
        }
    }
    
    fileprivate func showDockTitleBadge(_ badge: String) {
        NSApplication.shared.dockTile.badgeLabel = badge
    }
    
    fileprivate func showFilePaths(_ paths: [String]?, label: NSTextField?) {
        let value = paths?.sorted().map({ (s: String) -> String in
            return s.components(separatedBy: "/").last ?? ""
        }).joined(separator: ", ")
        label?.stringValue = value ?? ""
        label?.isHidden = value == nil
    }
    
    @IBAction func selectSettings(_ sender: AnyObject?) {
        Settings.readFromFile { [weak self] (success: Bool) in
            self?.readSettings()
        }
    }
    
    @IBAction func selectData(_ sender: AnyObject?) {
        DataLoader.load { [weak self] (success: Bool, urls: [URL]) in
            self?.setSelected(success, indicator: self?.indicatorData)
            self?.viewerController?.loadFile()
            self?.showFilePaths(DataLoader.singleton.files, label: self?.labelFirstDataFileName)
            // Try load calibration and strips config from data folder
            Calibration.handle(urls: urls) { (s: Bool, filePaths: [String]?) in
                if s {
                    self?.didSelectCalibration(s, filePaths: filePaths)
                }
            }
            StripsConfiguration.handle(urls: urls) { (s: Bool, filePaths: [String]?) in
                if s {
                    self?.didSelectStripsConfiguration(s, filePaths: filePaths)
                }
            }
        }
    }
    
    fileprivate func didSelectCalibration(_ success: Bool, filePaths: [String]?) {
        setSelected(success, indicator: indicatorCalibration)
        buttonRemoveCalibration?.isHidden = !success
        showFilePaths(filePaths, label: labelCalibrationFileName)
    }
    
    @IBAction func selectCalibration(_ sender: AnyObject?) {
        Calibration.load { [weak self] (success: Bool, filePaths: [String]?) in
            self?.didSelectCalibration(success, filePaths: filePaths)
        }
    }
    
    fileprivate func didSelectStripsConfiguration(_ success: Bool, filePaths: [String]?) {
        setSelected(success, indicator: indicatorStripsConfig)
        buttonRemoveStripsConfiguration?.isHidden = !success
        showFilePaths(filePaths, label: labelStripsConfigurationFileName)
    }
    
    @IBAction func selectStripsConfiguration(_ sender: AnyObject?) {
        StripsConfiguration.load { [weak self] (success: Bool, filePaths: [String]?) in
            self?.didSelectStripsConfiguration(success, filePaths: filePaths)
        }
    }
    
    @IBAction func showResultsFolder(_ sender: AnyObject?) {
        if !sResultsFolderName.isEmpty, let path = FileManager.pathForDesktopFolder(sResultsFolderName) {
            NSWorkspace.shared.openFile(path as String)
        }
    }
    
    // MARK: - ProcessorDelegate
    
    func startProcessingFile(_ name: String?) {
        labelProcessingFileName?.stringValue = name ?? ""
        let progress = progressIndicator.doubleValue
        if progress <= 0 {
            progressIndicator.doubleValue = Double.ulpOfOne // show indicator
        }
    }
    
    func endProcessingFile(_ name: String?, correlationsFound: CUnsignedLongLong) {
        let items = operations.values.map { (p: Processor) -> Int in
            return p.filesFinishedCount
        }
        let ready = items.sum()
        let total = DataLoader.singleton.files.count * items.count
        let progress = 100 * Double(ready)/Double(total)
        progressIndicator?.doubleValue = progress
        correlationsView.set(correlations: correlationsFound, at: progress)
    }
    
    // MARK: - Timer
    
    fileprivate func startTimer() {
        if timer?.isValid == true {
            return
        }
        startDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(AppDelegate.incrementTotalTime), userInfo: nil, repeats: true)
        labelTotalTime?.stringValue = ""
        labelTotalTime?.isHidden = false
        labelProcessingFileName?.stringValue = ""
        labelProcessingFileName?.isHidden = false
    }
    
    func timeTook() -> String {
        return abs(startDate?.timeIntervalSince(Date()) ?? 0).stringFromSeconds()
    }
    
    @objc func incrementTotalTime() {
        labelTotalTime?.stringValue = timeTook()
    }
    
    fileprivate func stopTimer() {
        timer?.invalidate()
        labelProcessingFileName?.isHidden = true
    }
    
    // MARK: - Settings
    
    fileprivate func saveSettings() {
        let dict: [Setting: Any?] = [
            .SFSource: sfSourceControl.selectedSegment,
            .MinGammaEnergy: Int(sMinGammaEnergy),
            .MaxGammaEnergy: Int(sMaxGammaEnergy),
            .MaxGammaTime: Int(sMaxGammaTime),
            .MaxGammaBackwardTime: Int(sMaxGammaBackwardTime),
            .MaxNeutronTime: Int(sMaxNeutronTime),
            .MaxNeutronBackwardTime: Int(sMaxNeutronBackwardTime),
            .NeutronsPositions: neutronsPositions,
            .SFSourcePlaced: sfSourcePlaced,
            .GammaStart: gammaStart,
            .RequiredGamma: gammaRequired,
            .ResultsFolderName: sResultsFolderName
        ]
        Settings.change(dict)
    }
    
    // MARK: - App Version
    
    fileprivate func infoPlistStringForKey(_ key: String) -> String? {
        return Bundle.main.infoDictionary![key] as? String
    }
    
    fileprivate func showAppVersion() {
        var string = ""
        if let version = infoPlistStringForKey("CFBundleShortVersionString") {
            string += "Version " + version
        }
        if let build = infoPlistStringForKey("CFBundleVersion") {
            string += " (" + build + ")"
        }
        if let gitSHA = infoPlistStringForKey("CFBundleVersionGitSHA") {
            string += "\nGit SHA " + gitSHA
        }
        labelVersion?.stringValue = string
        let branch = infoPlistStringForKey("CFBundleVersionGitBranch") ?? "unknown"
        labelBranch?.stringValue = "Branch: " + branch
        viewBranchStatus.wantsLayer = true
        viewBranchStatus.layer?.cornerRadius = viewBranchStatus.frame.width/2
        viewBranchStatus.layer?.backgroundColor = (branch == "master" ? NSColor.systemGreen : NSColor.systemRed).cgColor
    }
    
}
