//
//  AppDelegate.swift
//  NeutronBarrel
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
    @IBOutlet weak var indicatorData: NSTextField!
    @IBOutlet weak var indicatorCalibration: NSTextField!
    @IBOutlet weak var indicatorStripsConfig: NSTextField!
    @IBOutlet weak var buttonRun: NSButton!
    @IBOutlet weak var searchExtraView: NSView!
    @IBOutlet weak var wellView: NSView!
    @IBOutlet weak var buttonRemoveCalibration: NSButton!
    @IBOutlet weak var buttonRemoveStripsConfiguration: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    @IBOutlet weak var actionsView: NSView!
    @IBOutlet weak var resultsFolderButton: NSButton!
    @IBOutlet weak var maxWellAngleView: NSView!
    
    fileprivate var viewerController: ViewerController?
    fileprivate var calculationsController: CalculationsController?
    fileprivate var sorterController: EventSorterController?
    fileprivate var startDate: Date?
    fileprivate var timer: Timer?
    
    func readSettings() {
        sResultsFolderName = Settings.getStringSetting(.ResultsFolderName) ?? ""
        sNeutronsDetectorEfficiency = String(format: "%.1f", Settings.getDoubleSetting(.NeutronsDetectorEfficiency)) // %
        sNeutronsDetectorEfficiencyError = String(format: "%.1f", Settings.getDoubleSetting(.NeutronsDetectorEfficiencyError)) // %
        sExcludeNeutronCounters = Settings.getStringSetting(.ExcludeNeutronCounters) ?? ""
        sMinFissionWellEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionWellEnergy)) // MeV
        sMaxFissionWellEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionWellEnergy)) // MeV
        sMaxFissionWellAngle = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionWellAngle)) // degree
        sMaxFissionWellBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionWellBackwardTime)) // mks
        sMaxGammaTime = String(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
        sMaxGammaBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxGammaBackwardTime)) // mks
        sMinNeutronTime = String(format: "%d", Settings.getIntSetting(.MinNeutronTime)) // mks
        sMaxNeutronTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
        sMaxNeutronBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronBackwardTime)) // mks
        requiredGamma = Settings.getBoolSetting(.RequiredGamma)
        simplifyGamma = Settings.getBoolSetting(.SimplifyGamma)
        inBeamOnly = Settings.getBoolSetting(.InBeamOnly)
        useOverflow = Settings.getBoolSetting(.UseOverflow)
        usePileUp = Settings.getBoolSetting(.UsePileUp)
        searchNeutrons = Settings.getBoolSetting(.SearchNeutrons)
        neutronsBackground = Settings.getBoolSetting(.NeutronsBackground)
        simultaneousDecaysFilterForNeutrons = Settings.getBoolSetting(.SimultaneousDecaysFilterForNeutrons)
        collapseNeutronOverlays = Settings.getBoolSetting(.CollapseNeutronOverlays)
        neutronsPositions = Settings.getBoolSetting(.NeutronsPositions)
        sMaxConcurrentOperations = String(format: "%d", Settings.getIntSetting(.MaxConcurrentOperations))
        gammaEncodersOnly = Settings.getBoolSetting(.GammaEncodersOnly)
        gammaEncoderIds = Settings.getStringSetting(.GammaEncoderIds) ?? ""
        searchWell = Settings.getBoolSetting(.SearchWell)
        trackBeamEnergy = Settings.getBoolSetting(.TrackBeamEnergy)
        trackBeamCurrent = Settings.getBoolSetting(.TrackBeamCurrent)
        trackBeamBackground = Settings.getBoolSetting(.TrackBeamBackground)
        trackBeamIntegral = Settings.getBoolSetting(.TrackBeamIntegral)
        setupWellView()
        searchExtraView.setupForm()
        setupGammaEncodersView()
    }
    
    @IBInspectable dynamic var sResultsFolderName = "" {
        didSet {
            resultsFolderButton.isHidden = sResultsFolderName.isEmpty
        }
    }
    @IBInspectable dynamic var sNeutronsDetectorEfficiency: String = ""
    @IBInspectable dynamic var sNeutronsDetectorEfficiencyError: String = ""
    @IBInspectable dynamic var sExcludeNeutronCounters: String = ""
    @IBInspectable dynamic var sMinFissionWellEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionWellEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionWellAngle: String = ""
    @IBInspectable dynamic var sMaxFissionWellBackwardTime: String = ""
    @IBInspectable dynamic var sMaxGammaTime: String = ""
    @IBInspectable dynamic var sMaxGammaBackwardTime: String = ""
    @IBInspectable dynamic var sMinNeutronTime: String = ""
    @IBInspectable dynamic var sMaxNeutronTime: String = ""
    @IBInspectable dynamic var sMaxNeutronBackwardTime: String = ""
    @IBInspectable dynamic var requiredGamma: Bool = false
    @IBInspectable dynamic var requiredGammaOrWell: Bool = false
    @IBInspectable dynamic var simplifyGamma: Bool = false
    @IBInspectable dynamic var inBeamOnly: Bool = false
    @IBInspectable dynamic var useOverflow: Bool = false
    @IBInspectable dynamic var usePileUp: Bool = false
    @IBInspectable dynamic var searchNeutrons: Bool = false
    @IBInspectable dynamic var neutronsBackground: Bool = false
    @IBInspectable dynamic var simultaneousDecaysFilterForNeutrons: Bool = false
    @IBInspectable dynamic var collapseNeutronOverlays: Bool = false
    @IBInspectable dynamic var neutronsPositions: Bool = false {
        didSet {
            maxWellAngleView.isHidden = !neutronsPositions
        }
    }
    @IBInspectable dynamic var sMaxConcurrentOperations: String = "" {
        didSet {
            operationQueue.maxConcurrentOperationCount = maxConcurrentOperationCount
        }
    }
    @IBOutlet weak var gammaEncodersView: NSView!
    @IBInspectable dynamic var gammaEncodersOnly: Bool = false {
        didSet {
            setupGammaEncodersView()
        }
    }
    @IBInspectable dynamic var gammaEncoderIds: String = ""
    @IBInspectable dynamic var searchWell: Bool = false {
        didSet {
            setupWellView()
        }
    }
    @IBInspectable dynamic var trackBeamEnergy: Bool = false
    @IBInspectable dynamic var trackBeamCurrent: Bool = false
    @IBInspectable dynamic var trackBeamBackground: Bool = false
    @IBInspectable dynamic var trackBeamIntegral: Bool = false
    
    fileprivate func setupGammaEncodersView() {
        gammaEncodersView.isHidden = !gammaEncodersOnly
    }
    
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
//        StripDetectorManager.cleanStripConfigs()
        buttonRemoveStripsConfiguration.isHidden = true
        showFilePaths(nil, label: labelStripsConfigurationFileName)
    }
    
    fileprivate func setupWellView() {
        wellView.isHidden = false
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
    
    @IBAction func sorter(_ sender: Any) {
        if nil == sorterController {
            sorterController = EventSorterController(windowNibName: NSNib.Name("EventSorterController"))
        }
        sorterController?.showWindow(nil)
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
        sc.neutronsDetectorEfficiency = Double(sNeutronsDetectorEfficiency) ?? 0
        sc.neutronsDetectorEfficiencyError = Double(sNeutronsDetectorEfficiencyError) ?? 0
        sc.excludeNeutronCounters = sExcludeNeutronCounters.components(separatedBy: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        }
        sc.fissionAlphaWellMinEnergy = Double(sMinFissionWellEnergy) ?? 0
        sc.fissionAlphaWellMaxEnergy = Double(sMaxFissionWellEnergy) ?? 0
        sc.fissionAlphaWellMaxAngle = Double(sMaxFissionWellAngle) ?? 0
        sc.fissionAlphaWellBackwardMaxTime = UInt64(sMaxFissionWellBackwardTime) ?? 0
        sc.useOverflow = useOverflow
        sc.usePileUp = usePileUp
        sc.maxGammaTime = UInt64(sMaxGammaTime) ?? 0
        sc.maxGammaBackwardTime = UInt64(sMaxGammaBackwardTime) ?? 0
        sc.requiredGamma = requiredGamma
        sc.requiredGammaOrWell = requiredGammaOrWell
        sc.simplifyGamma = simplifyGamma
        sc.searchNeutrons = searchNeutrons
        sc.neutronsBackground = neutronsBackground
        sc.simultaneousDecaysFilterForNeutrons = simultaneousDecaysFilterForNeutrons
        sc.collapseNeutronOverlays = collapseNeutronOverlays
        sc.neutronsPositions = neutronsPositions
        sc.minNeutronTime = UInt64(sMinNeutronTime) ?? 0
        sc.maxNeutronTime = UInt64(sMaxNeutronTime) ?? 0
        sc.maxNeutronBackwardTime = UInt64(sMaxNeutronBackwardTime) ?? 0
        sc.gammaEncodersOnly = gammaEncodersOnly
        sc.trackBeamEnergy = trackBeamEnergy
        sc.trackBeamCurrent = trackBeamCurrent
        sc.trackBeamBackground = trackBeamBackground
        sc.trackBeamIntegral = trackBeamIntegral
        
        func idsFrom(string: String) -> Set<Int> {
            let ids = string.components(separatedBy: ",").map({ (s: String) -> Int in
                return Int(s) ?? 0
            }).filter({ (i: Int) -> Bool in
                return i > 0
            })
            return Set(ids)
        }
        sc.gammaEncoderIds = idsFrom(string: gammaEncoderIds)
        
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
        op.maxConcurrentOperationCount = maxConcurrentOperationCount
        op.name = "Processing queue"
        self._operationQueue = op
        return op
    }
    
    fileprivate var maxConcurrentOperationCount: Int {
        return max(Int(sMaxConcurrentOperations) ?? 1, 1)
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
//            StripsConfiguration.handle(urls: urls) { (s: Bool, filePaths: [String]?) in
//                if s {
//                    self?.didSelectStripsConfiguration(s, filePaths: filePaths)
//                }
//            }
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
            .NeutronsDetectorEfficiency: Double(sNeutronsDetectorEfficiency),
            .NeutronsDetectorEfficiencyError: Double(sNeutronsDetectorEfficiencyError),
            .ExcludeNeutronCounters: sExcludeNeutronCounters,
            .MinFissionWellEnergy: Double(sMinFissionWellEnergy),
            .MaxFissionWellEnergy: Double(sMaxFissionWellEnergy),
            .MaxFissionWellAngle: Double(sMaxFissionWellAngle),
            .MaxFissionWellBackwardTime: Int(sMaxFissionWellBackwardTime),
            .MaxGammaTime: Int(sMaxGammaTime),
            .MaxGammaBackwardTime: Int(sMaxGammaBackwardTime),
            .MinNeutronTime: Int(sMinNeutronTime),
            .MaxNeutronTime: Int(sMaxNeutronTime),
            .MaxNeutronBackwardTime: Int(sMaxNeutronBackwardTime),
            .RequiredGamma: requiredGamma,
            .SimplifyGamma: simplifyGamma,
            .InBeamOnly: inBeamOnly,
            .UseOverflow: useOverflow,
            .UsePileUp: usePileUp,
            .SearchNeutrons: searchNeutrons,
            .NeutronsBackground: neutronsBackground,
            .SimultaneousDecaysFilterForNeutrons: simultaneousDecaysFilterForNeutrons,
            .CollapseNeutronOverlays: collapseNeutronOverlays,
            .NeutronsPositions: neutronsPositions,
            .TrackBeamEnergy: trackBeamEnergy,
            .TrackBeamCurrent: trackBeamCurrent,
            .TrackBeamBackground: trackBeamBackground,
            .TrackBeamIntegral: trackBeamIntegral,
            .MaxConcurrentOperations: maxConcurrentOperationCount,
            .GammaEncodersOnly: gammaEncodersOnly,
            .GammaEncoderIds: gammaEncoderIds,
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
