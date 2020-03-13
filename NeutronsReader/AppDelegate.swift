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
    @IBOutlet weak var labelVersion: NSTextField!
    @IBOutlet weak var labelBranch: NSTextField!
    @IBOutlet weak var labelTotalTime: NSTextField!
    @IBOutlet weak var labelProcessingFileName: NSTextField!
    @IBOutlet weak var labelFirstDataFileName: NSTextField!
    @IBOutlet weak var labelCalibrationFileName: NSTextField!
    @IBOutlet weak var labelStripsConfigurationFileName: NSTextField!
    @IBOutlet weak var labelTask: NSTextField!
    @IBOutlet weak var startParticleControl: NSSegmentedControl!
    @IBOutlet weak var startParticleBackControl: NSSegmentedControl!
    @IBOutlet weak var secondParticleFrontControl: NSSegmentedControl!
    @IBOutlet weak var secondParticleBackControl: NSSegmentedControl!
    @IBOutlet weak var wellParticleBackControl: NSSegmentedControl!
    @IBOutlet weak var tofUnitsControl: NSSegmentedControl!
    @IBOutlet weak var indicatorData: NSTextField!
    @IBOutlet weak var indicatorCalibration: NSTextField!
    @IBOutlet weak var indicatorStripsConfig: NSTextField!
    @IBOutlet weak var buttonRun: NSButton!
    @IBOutlet weak var recoilFrontView: NSView!
    @IBOutlet weak var fissionAlpha2View: NSView!
    @IBOutlet weak var fissionAlpha2FormView: NSView!
    @IBOutlet weak var searchExtraView: NSView!
    @IBOutlet weak var vetoView: NSView!
    @IBOutlet weak var wellView: NSView!
    @IBOutlet weak var fissionAlpha1View: NSView!
    @IBOutlet weak var requiredRecoilButton: NSButton!
    @IBOutlet weak var recoilTypeButton: NSPopUpButton!
    @IBOutlet weak var recoilTypeArrayController: NSArrayController!
    @IBOutlet weak var fissionAlpha1TextField: NSTextField!
    @IBOutlet weak var fissionAlpha2Button: NSButton!
    @IBOutlet weak var buttonRemoveCalibration: NSButton!
    @IBOutlet weak var buttonRemoveStripsConfiguration: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    @IBOutlet weak var fissionAlpha1BackEnergyView: NSView!
    @IBOutlet weak var fissionAlpha2BackEnergyView: NSView!
    @IBOutlet weak var recoilBackEnergyView: NSView!
    
    fileprivate var viewerController: ViewerController?
    fileprivate var startDate: Date?
    fileprivate var timer: Timer?
    
    @IBInspectable var sResultsFolderName = ""
    @IBInspectable var sMinFissionEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionEnergy)) // MeV
    @IBInspectable var sMaxFissionEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionEnergy)) // MeV
    @IBInspectable var sMinFissionBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionBackEnergy)) // MeV
    @IBInspectable var sMaxFissionBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionBackEnergy)) // MeV
    @IBInspectable var sMinRecoilFrontEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinRecoilFrontEnergy)) // MeV
    @IBInspectable var sMaxRecoilFrontEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilFrontEnergy)) // MeV
    @IBInspectable var sMinRecoilBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinRecoilBackEnergy)) // MeV
    @IBInspectable var sMaxRecoilBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilBackEnergy)) // MeV
    @IBInspectable var sMinTOFValue = String(format: "%d", Settings.getIntSetting(.MinTOFValue)) // channel or ns
    @IBInspectable var sMaxTOFValue = String(format: "%d", Settings.getIntSetting(.MaxTOFValue)) // channel or ns
    @IBInspectable var sMinRecoilTime = String(format: "%d", Settings.getIntSetting(.MinRecoilTime)) // mks
    @IBInspectable var sMaxRecoilTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilTime)) // mks
    @IBInspectable var sMaxRecoilBackTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackTime)) // mks
    @IBInspectable var sMaxRecoilBackBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackBackwardTime)) // mks
    @IBInspectable var sMaxFissionTime = String(format: "%d", Settings.getIntSetting(.MaxFissionTime)) // mks
    @IBInspectable var sMaxFissionBackBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionBackBackwardTime)) // mks
    @IBInspectable var sMaxFissionWellBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionWellBackwardTime)) // mks
    @IBInspectable var sMaxTOFTime = String(format: "%d", Settings.getIntSetting(.MaxTOFTime)) // mks
    @IBInspectable var sMaxVETOTime = String(format: "%d", Settings.getIntSetting(.MaxVETOTime)) // mks
    @IBInspectable var sMaxGammaTime = String(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
    @IBInspectable var sMaxNeutronTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
    @IBInspectable var sMaxRecoilFrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilFrontDeltaStrips))
    @IBInspectable var sMaxRecoilBackDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackDeltaStrips))
    @IBInspectable var summarizeFissionsFront: Bool = Settings.getBoolSetting(.SummarizeFissionsFront)
    @IBInspectable var summarizeFissionsFront2: Bool = Settings.getBoolSetting(.SummarizeFissionsFront2)
    @IBInspectable var requiredFissionAlphaBack: Bool = Settings.getBoolSetting(.RequiredFissionAlphaBack)
    @IBInspectable var requiredRecoilBack: Bool = Settings.getBoolSetting(.RequiredRecoilBack)
    @IBInspectable var requiredRecoil: Bool = Settings.getBoolSetting(.RequiredRecoil)
    @IBInspectable var requiredGamma: Bool = Settings.getBoolSetting(.RequiredGamma)
    @IBInspectable var requiredWell: Bool = Settings.getBoolSetting(.RequiredWell)
    @IBInspectable var wellRecoilsAllowed: Bool = Settings.getBoolSetting(.WellRecoilsAllowed)
    @IBInspectable var searchExtraFromParticle2: Bool = Settings.getBoolSetting(.SearchExtraFromParticle2)
    @IBInspectable var requiredTOF: Bool = Settings.getBoolSetting(.RequiredTOF)
    @IBInspectable var useTOF2: Bool = Settings.getBoolSetting(.UseTOF2)
    @IBInspectable var requiredVETO: Bool = Settings.getBoolSetting(.RequiredVETO)
    @IBInspectable var searchNeutrons: Bool = Settings.getBoolSetting(.SearchNeutrons)
    @IBInspectable var searchFissionAlpha2: Bool = Settings.getBoolSetting(.SearchFissionAlpha2) {
        didSet {
            secondParticleFrontChanged(nil)
            setupAlpha2FormView()
        }
    }
    @IBInspectable var sBeamEnergyMin = String(format: "%.1f", Settings.getDoubleSetting(.BeamEnergyMin)) // MeV
    @IBInspectable var sBeamEnergyMax = String(format: "%.1f", Settings.getDoubleSetting(.BeamEnergyMax)) // MeV
    @IBInspectable var sMinFissionAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha2Energy)) // MeV
    @IBInspectable var sMaxFissionAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha2Energy)) // MeV
    @IBInspectable var sMinFissionAlpha2BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha2BackEnergy)) // MeV
    @IBInspectable var sMaxFissionAlpha2BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha2BackEnergy)) // MeV
    @IBInspectable var sMinFissionAlpha2Time = String(format: "%d", Settings.getIntSetting(.MinFissionAlpha2Time)) // mks
    @IBInspectable var sMaxFissionAlpha2Time = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha2Time)) // mks
    @IBInspectable var sMaxFissionAlpha2FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha2FrontDeltaStrips))
    @IBInspectable var sMaxConcurrentOperations = String(format: "%d", Settings.getIntSetting(.MaxConcurrentOperations)) {
        didSet {
            operationQueue.maxConcurrentOperationCount = maxConcurrentOperationCount
        }
    }
    @IBInspectable var searchSpecialEvents: Bool = Settings.getBoolSetting(.SearchSpecialEvents)
    @IBInspectable var specialEventIds = Settings.getStringSetting(.SpecialEventIds) ?? ""
    @IBInspectable var searchVETO: Bool = Settings.getBoolSetting(.SearchVETO) {
        didSet {
            setupVETOView()
        }
    }
    @IBInspectable var searchWell: Bool = Settings.getBoolSetting(.SearchWell) {
        didSet {
            setupWellView()
        }
    }
    @IBInspectable var trackBeamEnergy: Bool = Settings.getBoolSetting(.TrackBeamEnergy)
    @IBInspectable var trackBeamCurrent: Bool = Settings.getBoolSetting(.TrackBeamCurrent)
    @IBInspectable var trackBeamBackground: Bool = Settings.getBoolSetting(.TrackBeamBackground)
    @IBInspectable var trackBeamIntegral: Bool = Settings.getBoolSetting(.TrackBeamIntegral)
    @IBInspectable var searchFissionBackByFact: Bool = Settings.getBoolSetting(.SearchFissionBackByFact) {
        didSet {
            setupFissionAlpha1BackEnergyView()
        }
    }
    @IBInspectable var searchFissionBack2ByFact: Bool = Settings.getBoolSetting(.SearchFissionBack2ByFact) {
        didSet {
            setupFissionAlpha2BackEnergyView()
        }
    }
    @IBInspectable var searchRecoilBackByFact: Bool = Settings.getBoolSetting(.SearchRecoilBackByFact) {
        didSet {
            setupRecoilBackEnergyView()
        }
    }
    
    fileprivate let recoilTypes: [SearchType] = [.recoil, .heavy]
    fileprivate var selectedRecoilType: SearchType {
        return recoilTypes[recoilTypeArrayController.selectionIndex]
    }
    
    fileprivate var formColor: CGColor {
        return NSColor.lightGray.withAlphaComponent(0.2).cgColor
    }
    
    fileprivate func setupAlpha2FormView() {
        fissionAlpha2FormView.isHidden = !searchFissionAlpha2
        fissionAlpha2FormView.wantsLayer = true
        fissionAlpha2FormView.layer?.backgroundColor = formColor
    }
    
    fileprivate func setupSearchExtraView() {
        searchExtraView.wantsLayer = true
        searchExtraView.layer?.backgroundColor = formColor
    }
    
    fileprivate func setupRecoilTypes() {
        let array = recoilTypes.map { (t: SearchType) -> String in
            return t.name()
        }
        var index = 0
        if let t = SearchType(rawValue: Settings.getIntSetting(.SelectedRecoilType)), let i = recoilTypes.firstIndex(of: t) {
            index = i
        }
        recoilTypeArrayController.content = array
        recoilTypeArrayController.setSelectedObjects([array[index]])
    }
    
    fileprivate func setupFissionAlpha1BackEnergyView() {
        fissionAlpha1BackEnergyView.isHidden = searchFissionBackByFact
    }
    
    fileprivate func setupFissionAlpha2BackEnergyView() {
        fissionAlpha2BackEnergyView.isHidden = searchFissionBack2ByFact
    }
    
    fileprivate func setupRecoilBackEnergyView() {
        recoilBackEnergyView.isHidden = searchRecoilBackByFact
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupRecoilTypes()
        startParticleControl.selectedSegment = Settings.getIntSetting(.StartSearchType)
        startParticleBackControl.selectedSegment = Settings.getIntSetting(.StartBackSearchType)
        secondParticleFrontControl.selectedSegment = Settings.getIntSetting(.SecondFrontSearchType)
        secondParticleBackControl.selectedSegment = Settings.getIntSetting(.SecondBackSearchType)
        wellParticleBackControl.selectedSegment = Settings.getIntSetting(.WellBackSearchType)
        startParticleChanged(nil)
        secondParticleFrontChanged(nil)
        secondParticleBackChanged(nil)
        setupVETOView()
        setupWellView()
        setupAlpha2FormView()
        setupSearchExtraView()
        setupFissionAlpha1BackEnergyView()
        setupFissionAlpha2BackEnergyView()
        setupRecoilBackEnergyView()
        tofUnitsControl.selectedSegment = Settings.getIntSetting(.TOFUnits)
        for i in [indicatorData, indicatorCalibration, indicatorStripsConfig] {
            setSelected(false, indicator: i)
        }
        showAppVersion()
        updateRunState()
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
    
    @IBAction func startParticleChanged(_ sender: Any?) {
        if let type = SearchType(rawValue: startParticleControl.selectedSegment) {
            let isRecoil = type == .recoil
            fissionAlpha2View.isHidden = isRecoil
            requiredRecoil = requiredRecoil || isRecoil
            recoilFrontView.isHidden = isRecoil
            requiredRecoilButton.state = NSControl.StateValue(rawValue: requiredRecoil ? 1 : 0)
            requiredRecoilButton.isEnabled = !isRecoil
            fissionAlpha1View.isHidden = isRecoil
            fissionAlpha1TextField.stringValue = (type != .alpha ? "F" : "A") + "Front 1st"
            secondParticleFrontChanged(nil)
            if sender != nil, !isRecoil {
                startParticleBackControl.selectedSegment = type.rawValue
                if !searchExtraFromParticle2 {
                    wellParticleBackControl.selectedSegment = type.rawValue
                }
            }
        }
    }
    
    @IBAction func secondParticleFrontChanged(_ sender: Any?) {
        if let type = SearchType(rawValue: secondParticleFrontControl.selectedSegment) {
            var title = "Search "
            if searchFissionAlpha2 {
                title += (type != .alpha ? "F" : "A") + "Front 2nd"
            } else {
                title += "2nd Particle"
            }
            fissionAlpha2Button.title = title
        }
    }
    
    @IBAction func secondParticleBackChanged(_ sender: Any?) {
        if let type = SearchType(rawValue: secondParticleBackControl.selectedSegment), searchExtraFromParticle2 {
            wellParticleBackControl.selectedSegment = type.rawValue
        }
    }
    
    fileprivate func setupVETOView() {
        vetoView.isHidden = !searchVETO
    }
    
    fileprivate func setupWellView() {
        wellView.isHidden = !searchWell
    }
    
    @IBAction func viewer(_ sender: Any) {
        if nil == viewerController {
            //viewerController = ViewerController(windowNibName: NSNib.Name(rawValue: "ViewerController"))
        }
        viewerController?.showWindow(nil)
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
        let sc = SearchCriteria()
        sc.resultsFolderName = sResultsFolderName
        sc.startParticleType = SearchType(rawValue: startParticleControl.selectedSegment) ?? .recoil
        sc.startParticleBackType = SearchType(rawValue: startParticleBackControl.selectedSegment) ?? .fission
        sc.secondParticleFrontType = SearchType(rawValue: secondParticleFrontControl.selectedSegment) ?? .recoil
        sc.secondParticleBackType = SearchType(rawValue: secondParticleBackControl.selectedSegment) ?? .recoil
        sc.wellParticleBackType = SearchType(rawValue: wellParticleBackControl.selectedSegment) ?? .fission
        sc.fissionAlphaFrontMinEnergy = Double(sMinFissionEnergy) ?? 0
        sc.fissionAlphaFrontMaxEnergy = Double(sMaxFissionEnergy) ?? 0
        sc.fissionAlphaBackMinEnergy = Double(sMinFissionBackEnergy) ?? 0
        sc.fissionAlphaBackMaxEnergy = Double(sMaxFissionBackEnergy) ?? 0
        sc.searchFissionAlphaBackByFact = searchFissionBackByFact
        sc.searchFissionAlphaBack2ByFact = searchFissionBack2ByFact
        sc.searchRecoilBackByFact = searchRecoilBackByFact
        sc.fissionAlphaMaxTime = UInt64(sMaxFissionTime) ?? 0
        sc.fissionAlphaBackBackwardMaxTime = UInt64(sMaxFissionBackBackwardTime) ?? 0
        sc.fissionAlphaWellBackwardMaxTime = UInt64(sMaxFissionWellBackwardTime) ?? 0
        sc.summarizeFissionsAlphaFront = summarizeFissionsFront
        sc.summarizeFissionsAlphaFront2 = summarizeFissionsFront2
        sc.searchFissionAlpha2 = searchFissionAlpha2
        sc.fissionAlpha2MinEnergy = Double(sMinFissionAlpha2Energy) ?? 0
        sc.fissionAlpha2MaxEnergy = Double(sMaxFissionAlpha2Energy) ?? 0
        sc.fissionAlpha2BackMinEnergy = Double(sMinFissionAlpha2BackEnergy) ?? 0
        sc.fissionAlpha2BackMaxEnergy = Double(sMaxFissionAlpha2BackEnergy) ?? 0
        sc.fissionAlpha2MinTime = UInt64(sMinFissionAlpha2Time) ?? 0
        sc.fissionAlpha2MaxTime = UInt64(sMaxFissionAlpha2Time) ?? 0
        sc.fissionAlpha2MaxDeltaStrips = Int(sMaxFissionAlpha2FrontDeltaStrips) ?? 0
        sc.recoilFrontMaxDeltaStrips = Int(sMaxRecoilFrontDeltaStrips) ?? 0
        sc.recoilBackMaxDeltaStrips = Int(sMaxRecoilBackDeltaStrips) ?? 0
        sc.requiredFissionAlphaBack = requiredFissionAlphaBack
        sc.requiredRecoilBack = requiredRecoilBack
        sc.requiredRecoil = requiredRecoil
        sc.recoilFrontMinEnergy = Double(sMinRecoilFrontEnergy) ?? 0
        sc.recoilFrontMaxEnergy = Double(sMaxRecoilFrontEnergy) ?? 0
        sc.recoilBackMinEnergy = Double(sMinRecoilBackEnergy) ?? 0
        sc.recoilBackMaxEnergy = Double(sMaxRecoilBackEnergy) ?? 0
        sc.recoilMinTime = UInt64(sMinRecoilTime) ?? 0
        sc.recoilMaxTime = UInt64(sMaxRecoilTime) ?? 0
        sc.recoilBackMaxTime = UInt64(sMaxRecoilBackTime) ?? 0
        sc.recoilBackBackwardMaxTime = UInt64(sMaxRecoilBackBackwardTime) ?? 0
        sc.minTOFValue = Double(sMinTOFValue) ?? 0
        sc.maxTOFValue = Double(sMaxTOFValue) ?? 0
        sc.unitsTOF = tofUnitsControl.selectedSegment == 0 ? .channels : .nanoseconds
        sc.maxTOFTime = UInt64(sMaxTOFTime) ?? 0
        sc.requiredTOF = requiredTOF
        sc.useTOF2 = useTOF2
        sc.maxVETOTime = UInt64(sMaxVETOTime) ?? 0
        sc.requiredVETO = requiredVETO
        sc.maxGammaTime = UInt64(sMaxGammaTime) ?? 0
        sc.requiredGamma = requiredGamma
        sc.requiredWell = requiredWell
        sc.wellRecoilsAllowed = wellRecoilsAllowed
        sc.searchExtraFromParticle2 = searchExtraFromParticle2
        sc.searchNeutrons = searchNeutrons
        sc.maxNeutronTime = UInt64(sMaxNeutronTime) ?? 0
        sc.searchSpecialEvents = searchSpecialEvents
        sc.searchVETO = searchVETO
        sc.trackBeamEnergy = trackBeamEnergy
        sc.trackBeamCurrent = trackBeamCurrent
        sc.trackBeamBackground = trackBeamBackground
        sc.trackBeamIntegral = trackBeamIntegral
        sc.recoilType = selectedRecoilType
        sc.searchWell = searchWell
        sc.beamEnergyMin = Float(sBeamEnergyMin) ?? 0
        sc.beamEnergyMax = Float(sBeamEnergyMax) ?? 0
        let ids = specialEventIds.components(separatedBy: ",").map({ (s: String) -> Int in
            return Int(s) ?? 0
        }).filter({ (i: Int) -> Bool in
            return i > 0
        })
        sc.specialEventIds = ids
        
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
    
    fileprivate func updateRunState() {
        let count = operations.count
        let run = count > 0
        buttonCancel.isHidden = !run
        labelTask.isHidden = !run
        let s = count == 1 ? "" : "s"
        labelTask.stringValue = "\(count) task\(s) processing"
        progressIndicator?.doubleValue = 0.0
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
    }
    
    fileprivate func showFilePaths(_ paths: [String]?, label: NSTextField?) {
        let value = paths?.sorted().map({ (s: String) -> String in
            return s.components(separatedBy: "/").last ?? ""
        }).joined(separator: ", ")
        label?.stringValue = value ?? ""
        label?.isHidden = value == nil
    }
    
    @IBAction func selectData(_ sender: AnyObject?) {
        DataLoader.load { [weak self] (success: Bool) in
            self?.setSelected(success, indicator: self?.indicatorData)
            self?.viewerController?.loadFile()
            self?.showFilePaths(DataLoader.singleton.files, label: self?.labelFirstDataFileName)
        }
    }
    
    @IBAction func selectCalibration(_ sender: AnyObject?) {
        Calibration.load { [weak self] (success: Bool, filePaths: [String]?) in
            self?.setSelected(success, indicator: self?.indicatorCalibration)
            self?.buttonRemoveCalibration?.isHidden = !success
            self?.showFilePaths(filePaths, label: self?.labelCalibrationFileName)
        }
    }
    
    @IBAction func selectStripsConfiguration(_ sender: AnyObject?) {
        StripsConfiguration.load { [weak self] (success: Bool, filePaths: [String]?) in
            self?.setSelected(success, indicator: self?.indicatorStripsConfig)
            self?.buttonRemoveStripsConfiguration?.isHidden = !success
            self?.showFilePaths(filePaths, label: self?.labelStripsConfigurationFileName)
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
    
    func endProcessingFile(_ name: String?) {
        let items = operations.values.map { (p: Processor) -> Int in
            return p.filesFinishedCount
        }
        let ready = items.reduce(0, +)
        let total = DataLoader.singleton.files.count * items.count
        let progress = 100 * Double(ready)/Double(total)
        progressIndicator?.doubleValue = progress
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
        Settings.setObject(Double(sMinFissionEnergy), forSetting: .MinFissionEnergy)
        Settings.setObject(Double(sMaxFissionEnergy), forSetting: .MaxFissionEnergy)
        Settings.setObject(Double(sMinFissionBackEnergy), forSetting: .MinFissionBackEnergy)
        Settings.setObject(Double(sMaxFissionBackEnergy), forSetting: .MaxFissionBackEnergy)
        Settings.setObject(Double(sMinRecoilFrontEnergy), forSetting: .MinRecoilFrontEnergy)
        Settings.setObject(Double(sMaxRecoilFrontEnergy), forSetting: .MaxRecoilFrontEnergy)
        Settings.setObject(Double(sMinRecoilBackEnergy), forSetting: .MinRecoilBackEnergy)
        Settings.setObject(Double(sMaxRecoilBackEnergy), forSetting: .MaxRecoilBackEnergy)
        Settings.setObject(Float(sBeamEnergyMin), forSetting: .BeamEnergyMin)
        Settings.setObject(Float(sBeamEnergyMax), forSetting: .BeamEnergyMax)
        Settings.setObject(Int(sMinTOFValue), forSetting: .MinTOFValue)
        Settings.setObject(Int(sMaxTOFValue), forSetting: .MaxTOFValue)
        Settings.setObject(tofUnitsControl.selectedSegment, forSetting: .TOFUnits)
        Settings.setObject(Int(sMinRecoilTime), forSetting: .MinRecoilTime)
        Settings.setObject(Int(sMaxRecoilTime), forSetting: .MaxRecoilTime)
        Settings.setObject(Int(sMaxRecoilBackTime), forSetting: .MaxRecoilBackTime)
        Settings.setObject(Int(sMaxRecoilBackBackwardTime), forSetting: .MaxRecoilBackBackwardTime)
        Settings.setObject(Int(sMaxFissionTime), forSetting: .MaxFissionTime)
        Settings.setObject(Int(sMaxFissionBackBackwardTime), forSetting: .MaxFissionBackBackwardTime)
        Settings.setObject(Int(sMaxFissionWellBackwardTime), forSetting: .MaxFissionWellBackwardTime)
        Settings.setObject(Int(sMaxTOFTime), forSetting: .MaxTOFTime)
        Settings.setObject(Int(sMaxVETOTime), forSetting: .MaxVETOTime)
        Settings.setObject(Int(sMaxGammaTime), forSetting: .MaxGammaTime)
        Settings.setObject(Int(sMaxNeutronTime), forSetting: .MaxNeutronTime)
        Settings.setObject(Int(sMaxRecoilFrontDeltaStrips), forSetting: .MaxRecoilFrontDeltaStrips)
        Settings.setObject(Int(sMaxRecoilBackDeltaStrips), forSetting: .MaxRecoilBackDeltaStrips)
        Settings.setObject(summarizeFissionsFront, forSetting: .SummarizeFissionsFront)
        Settings.setObject(summarizeFissionsFront2, forSetting: .SummarizeFissionsFront2)
        Settings.setObject(requiredFissionAlphaBack, forSetting: .RequiredFissionAlphaBack)
        Settings.setObject(requiredRecoilBack, forSetting: .RequiredRecoilBack)
        Settings.setObject(requiredRecoil, forSetting: .RequiredRecoil)
        Settings.setObject(requiredGamma, forSetting: .RequiredGamma)
        Settings.setObject(requiredWell, forSetting: .RequiredWell)
        Settings.setObject(wellRecoilsAllowed, forSetting: .WellRecoilsAllowed)
        Settings.setObject(searchExtraFromParticle2, forSetting: .SearchExtraFromParticle2)
        Settings.setObject(requiredTOF, forSetting: .RequiredTOF)
        Settings.setObject(useTOF2, forSetting: .UseTOF2)
        Settings.setObject(requiredVETO, forSetting: .RequiredVETO)
        Settings.setObject(searchNeutrons, forSetting: .SearchNeutrons)
        Settings.setObject(searchVETO, forSetting: .SearchVETO)
        Settings.setObject(trackBeamEnergy, forSetting: .TrackBeamEnergy)
        Settings.setObject(trackBeamCurrent, forSetting: .TrackBeamCurrent)
        Settings.setObject(trackBeamBackground, forSetting: .TrackBeamBackground)
        Settings.setObject(trackBeamIntegral, forSetting: .TrackBeamIntegral)
        Settings.setObject(startParticleControl.selectedSegment, forSetting: .StartSearchType)
        Settings.setObject(startParticleBackControl.selectedSegment, forSetting: .StartBackSearchType)
        Settings.setObject(secondParticleFrontControl.selectedSegment, forSetting: .SecondFrontSearchType)
        Settings.setObject(secondParticleBackControl.selectedSegment, forSetting: .SecondBackSearchType)
        Settings.setObject(wellParticleBackControl.selectedSegment, forSetting: .WellBackSearchType)
        Settings.setObject(searchFissionAlpha2, forSetting: .SearchFissionAlpha2)
        Settings.setObject(Double(sMinFissionAlpha2Energy), forSetting: .MinFissionAlpha2Energy)
        Settings.setObject(Double(sMaxFissionAlpha2Energy), forSetting: .MaxFissionAlpha2Energy)
        Settings.setObject(Double(sMinFissionAlpha2BackEnergy), forSetting: .MinFissionAlpha2BackEnergy)
        Settings.setObject(Double(sMaxFissionAlpha2BackEnergy), forSetting: .MaxFissionAlpha2BackEnergy)
        Settings.setObject(Int(sMinFissionAlpha2Time), forSetting: .MinFissionAlpha2Time)
        Settings.setObject(Int(sMaxFissionAlpha2Time), forSetting: .MaxFissionAlpha2Time)
        Settings.setObject(Int(sMaxFissionAlpha2FrontDeltaStrips), forSetting: .MaxFissionAlpha2FrontDeltaStrips)
        Settings.setObject(maxConcurrentOperationCount, forSetting: .MaxConcurrentOperations)
        Settings.setObject(searchSpecialEvents, forSetting: .SearchSpecialEvents)
        Settings.setObject(specialEventIds, forSetting: .SpecialEventIds)
        Settings.setObject(selectedRecoilType.rawValue, forSetting: .SelectedRecoilType)
        Settings.setObject(searchFissionBackByFact, forSetting: .SearchFissionBackByFact)
        Settings.setObject(searchFissionBack2ByFact, forSetting: .SearchFissionBack2ByFact)
        Settings.setObject(searchRecoilBackByFact, forSetting: .SearchRecoilBackByFact)
        Settings.setObject(searchWell, forSetting: .SearchWell)
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
            string += " (" + build + ")."
        }
        if let gitSHA = infoPlistStringForKey("CFBundleVersionGitSHA") {
            string += " Git SHA " + gitSHA
        }
        labelVersion?.stringValue = string
        let branch: String
        #if NEW_TIME_FORMAT
            branch = "New time format!"
        #else
            branch = "Branch: " + (infoPlistStringForKey("CFBundleVersionGitBranch") ?? "unknown")
        #endif
        labelBranch?.stringValue = branch
    }
    
}
