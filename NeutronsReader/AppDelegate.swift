//
//  AppDelegate.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 08.01.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
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
    @IBOutlet weak var startParticleControl: NSSegmentedControl!
    @IBOutlet weak var tofUnitsControl: NSSegmentedControl!
    @IBOutlet weak var indicatorData: NSTextField!
    @IBOutlet weak var indicatorCalibration: NSTextField!
    @IBOutlet weak var indicatorStripsConfig: NSTextField!
    @IBOutlet weak var buttonRun: NSButton!
    @IBOutlet weak var alpha2View: NSView!
    @IBOutlet weak var vetoView: NSView!
    @IBOutlet weak var fissionAlpha1View: NSView!
    @IBOutlet weak var requiredRecoilButton: NSButton!
    @IBOutlet weak var recoilTypeButton: NSPopUpButton!
    @IBOutlet weak var recoilTypeArrayController: NSArrayController!
    
    fileprivate var viewerController: ViewerController?
    fileprivate var totalTime: TimeInterval = 0
    fileprivate var timer: Timer?
    
    @IBInspectable var sMinFissionEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionEnergy)) // MeV
    @IBInspectable var sMaxFissionEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionEnergy)) // MeV
    @IBInspectable var sMinRecoilEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinRecoilEnergy)) // MeV
    @IBInspectable var sMaxRecoilEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilEnergy)) // MeV
    @IBInspectable var sMinTOFValue = String(format: "%d", Settings.getIntSetting(.MinTOFValue)) // channel or ns
    @IBInspectable var sMaxTOFValue = String(format: "%d", Settings.getIntSetting(.MaxTOFValue)) // channel or ns
    @IBInspectable var sMinRecoilTime = String(format: "%d", Settings.getIntSetting(.MinRecoilTime)) // mks
    @IBInspectable var sMaxRecoilTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilTime)) // mks
    @IBInspectable var sMaxRecoilBackTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackTime)) // mks
    @IBInspectable var sMaxFissionTime = String(format: "%d", Settings.getIntSetting(.MaxFissionTime)) // mks
    @IBInspectable var sMaxTOFTime = String(format: "%d", Settings.getIntSetting(.MaxTOFTime)) // mks
    @IBInspectable var sMaxVETOTime = String(format: "%d", Settings.getIntSetting(.MaxVETOTime)) // mks
    @IBInspectable var sMaxGammaTime = String(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
    @IBInspectable var sMaxNeutronTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
    @IBInspectable var sMaxRecoilFrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilFrontDeltaStrips))
    @IBInspectable var sMaxRecoilBackDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackDeltaStrips))
    @IBInspectable var summarizeFissionsFront: Bool = Settings.getBoolSetting(.SummarizeFissionsFront)
    @IBInspectable var requiredFissionAlphaBack: Bool = Settings.getBoolSetting(.RequiredFissionAlphaBack)
    @IBInspectable var requiredRecoilBack: Bool = Settings.getBoolSetting(.RequiredRecoilBack)
    @IBInspectable var requiredRecoil: Bool = Settings.getBoolSetting(.RequiredRecoil)
    @IBInspectable var requiredGamma: Bool = Settings.getBoolSetting(.RequiredGamma)
    @IBInspectable var requiredTOF: Bool = Settings.getBoolSetting(.RequiredTOF)
    @IBInspectable var requiredVETO: Bool = Settings.getBoolSetting(.RequiredVETO)
    @IBInspectable var searchNeutrons: Bool = Settings.getBoolSetting(.SearchNeutrons)
    @IBInspectable var searchAlpha2: Bool = Settings.getBoolSetting(.SearchAlpha2)
    @IBInspectable var sMinAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinAlpha2Energy)) // MeV
    @IBInspectable var sMaxAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxAlpha2Energy)) // MeV
    @IBInspectable var sMinAlpha2Time = String(format: "%d", Settings.getIntSetting(.MinAlpha2Time)) // mks
    @IBInspectable var sMaxAlpha2Time = String(format: "%d", Settings.getIntSetting(.MaxAlpha2Time)) // mks
    @IBInspectable var sMaxAlpha2FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxAlpha2FrontDeltaStrips))
    @IBInspectable var searchSpecialEvents: Bool = Settings.getBoolSetting(.SearchSpecialEvents)
    @IBInspectable var specialEventIds = Settings.getStringSetting(.SpecialEventIds) ?? ""
    @IBInspectable var searchVETO: Bool = Settings.getBoolSetting(.SearchVETO) {
        didSet {
            setupVETOView()
        }
    }
    @IBInspectable var trackBeamEnergy: Bool = Settings.getBoolSetting(.TrackBeamEnergy)
    @IBInspectable var trackBeamCurrent: Bool = Settings.getBoolSetting(.TrackBeamCurrent)
    @IBInspectable var trackBeamBackground: Bool = Settings.getBoolSetting(.TrackBeamBackground)
    @IBInspectable var trackBeamIntegral: Bool = Settings.getBoolSetting(.TrackBeamIntegral)
    
    fileprivate let recoilTypes: [SearchType] = [.recoil, .heavy]
    fileprivate var selectedRecoilType: SearchType {
        return recoilTypes[recoilTypeArrayController.selectionIndex]
    }
    
    fileprivate func setupRecoilTypes() {
        let array = recoilTypes.map { (t: SearchType) -> String in
            return t.name()
        }
        var index = 0
        if let t = SearchType(rawValue: Settings.getIntSetting(.SelectedRecoilType)), let i = recoilTypes.index(of: t) {
            index = i
        }
        recoilTypeArrayController.content = array
        recoilTypeArrayController.setSelectedObjects([array[index]])
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupRecoilTypes()
        startParticleControl.selectedSegment = Settings.getIntSetting(.SearchType)
        startParticleChanged(nil)
        setupVETOView()
        tofUnitsControl.selectedSegment = Settings.getIntSetting(.TOFUnits)
        for i in [indicatorData, indicatorCalibration, indicatorStripsConfig] {
            setSelected(false, indicator: i)
        }
        showAppVersion()
        run = false
    }
    
    @IBAction func startParticleChanged(_ sender: Any?) {
        if let type = SearchType(rawValue: startParticleControl.selectedSegment) {
            alpha2View.isHidden = type != .alpha
            requiredRecoil = requiredRecoil || type == .recoil
            requiredRecoilButton.state = NSControl.StateValue(rawValue: requiredRecoil ? 1 : 0)
            requiredRecoilButton.isEnabled = type != .recoil
            fissionAlpha1View.isHidden = type == .recoil
        }
    }
    
    fileprivate func setupVETOView() {
        vetoView.isHidden = !searchVETO
    }
    
    @IBAction func viewer(_ sender: Any) {
        if nil == viewerController {
            viewerController = ViewerController(windowNibName: NSNib.Name(rawValue: "ViewerController"))
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
    
    @IBAction func start(_ sender: AnyObject?) {
        let processor = Processor.singleton
        if run {
            processor.stop()
            run = false
        } else {
            run = true
            
            var startType: SearchType
            switch startParticleControl.selectedSegment {
            case 0:
                startType = .fission
            case 1:
                startType = .alpha
            default:
                startType = .recoil
            }
            processor.startParticleType = startType
            processor.fissionAlphaFrontMinEnergy = Double(sMinFissionEnergy) ?? 0
            processor.fissionAlphaFrontMaxEnergy = Double(sMaxFissionEnergy) ?? 0
            processor.fissionAlphaMaxTime = UInt64(sMaxFissionTime) ?? 0
            processor.summarizeFissionsAlphaFront = summarizeFissionsFront
            processor.searchAlpha2 = searchAlpha2
            processor.alpha2MinEnergy = Double(sMinAlpha2Energy) ?? 0
            processor.alpha2MaxEnergy = Double(sMaxAlpha2Energy) ?? 0
            processor.alpha2MinTime = UInt64(sMinAlpha2Time) ?? 0
            processor.alpha2MaxTime = UInt64(sMaxAlpha2Time) ?? 0
            processor.alpha2MaxDeltaStrips = Int(sMaxAlpha2FrontDeltaStrips) ?? 0
            processor.recoilFrontMaxDeltaStrips = Int(sMaxRecoilFrontDeltaStrips) ?? 0
            processor.recoilBackMaxDeltaStrips = Int(sMaxRecoilBackDeltaStrips) ?? 0
            processor.requiredFissionAlphaBack = requiredFissionAlphaBack
            processor.requiredRecoilBack = requiredRecoilBack
            processor.requiredRecoil = requiredRecoil
            processor.recoilFrontMinEnergy = Double(sMinRecoilEnergy) ?? 0
            processor.recoilFrontMaxEnergy = Double(sMaxRecoilEnergy) ?? 0
            processor.recoilMinTime = UInt64(sMinRecoilTime) ?? 0
            processor.recoilMaxTime = UInt64(sMaxRecoilTime) ?? 0
            processor.recoilBackMaxTime = UInt64(sMaxRecoilBackTime) ?? 0
            processor.minTOFValue = Double(sMinTOFValue) ?? 0
            processor.maxTOFValue = Double(sMaxTOFValue) ?? 0
            processor.unitsTOF = tofUnitsControl.selectedSegment == 0 ? .channels : .nanoseconds
            processor.maxTOFTime = UInt64(sMaxTOFTime) ?? 0
            processor.requiredTOF = requiredTOF
            processor.maxVETOTime = UInt64(sMaxVETOTime) ?? 0
            processor.requiredVETO = requiredVETO
            processor.maxGammaTime = UInt64(sMaxGammaTime) ?? 0
            processor.requiredGamma = requiredGamma
            processor.searchNeutrons = searchNeutrons
            processor.maxNeutronTime = UInt64(sMaxNeutronTime) ?? 0
            processor.searchSpecialEvents = searchSpecialEvents
            processor.searchVETO = searchVETO
            processor.trackBeamEnergy = trackBeamEnergy
            processor.trackBeamCurrent = trackBeamCurrent
            processor.trackBeamBackground = trackBeamBackground
            processor.trackBeamIntegral = trackBeamIntegral
            processor.recoilType = selectedRecoilType
            let ids = specialEventIds.components(separatedBy: ",").map({ (s: String) -> Int in
                return Int(s) ?? 0
            }).filter({ (i: Int) -> Bool in
                return i > 0
            })
            processor.specialEventIds = ids
            processor.delegate = self
            processor.processDataWithCompletion({ [weak self] in
                self?.run = false
            })
        }
    }
    
    fileprivate var run: Bool = false {
        didSet {
            buttonRun.title = run ? "Stop" : "Start"
            if run {
                activity?.startAnimation(self)
                startTimer()
                progressIndicator?.startAnimation(self)
                saveSettings()
            } else {
                activity?.stopAnimation(self)
                stopTimer()
                progressIndicator.stopAnimation(self)
                progressIndicator?.doubleValue = 0.0
            }
            startParticleControl?.isEnabled = !run
            tofUnitsControl?.isEnabled = !run
        }
    }
    
    @IBAction func selectData(_ sender: AnyObject?) {
        Processor.singleton.selectDataWithCompletion { [weak self] (success: Bool) in
            self?.setSelected(success, indicator: self?.indicatorData)
            self?.viewerController?.loadFile()
        }
    }
    
    @IBAction func selectCalibration(_ sender: AnyObject?) {
        Processor.singleton.selectCalibrationWithCompletion { [weak self] (success: Bool) in
            self?.setSelected(success, indicator: self?.indicatorCalibration)
        }
    }
    
    @IBAction func selectStripsConfiguration(_ sender: AnyObject?) {
        Processor.singleton.selectStripsConfigurationWithCompletion { [weak self] (success: Bool) in
            self?.setSelected(success, indicator: self?.indicatorStripsConfig)
        }
    }
    
    // MARK: - ProcessorDelegate
    
    func incrementProgress(_ delta: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progressIndicator?.increment(by: delta)
        }
    }
    
    func startProcessingFile(_ fileName: String) {
        labelProcessingFileName?.stringValue = fileName
    }
    
    // MARK: - Timer
    
    fileprivate func startTimer() {
        totalTime = 0
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(AppDelegate.incrementTotalTime), userInfo: nil, repeats: true)
        labelTotalTime?.stringValue = ""
        labelTotalTime?.isHidden = false
        labelProcessingFileName?.stringValue = ""
        labelProcessingFileName?.isHidden = false
    }
    
    fileprivate func stringTotalTime() -> String {
        let seconds = Int(totalTime.truncatingRemainder(dividingBy: 60))
        let minutes = Int((totalTime / 60).truncatingRemainder(dividingBy: 60))
        let hours = Int(totalTime / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    @objc func incrementTotalTime() {
        totalTime += 1
        labelTotalTime?.stringValue = stringTotalTime()
    }
    
    fileprivate func stopTimer() {
        timer?.invalidate()
        labelProcessingFileName?.isHidden = true
    }
    
    // MARK: - Settings
    
    fileprivate func saveSettings() {
        Settings.setObject(Double(sMinFissionEnergy), forSetting: .MinFissionEnergy)
        Settings.setObject(Double(sMaxFissionEnergy), forSetting: .MaxFissionEnergy)
        Settings.setObject(Double(sMinRecoilEnergy), forSetting: .MinRecoilEnergy)
        Settings.setObject(Double(sMaxRecoilEnergy), forSetting: .MaxRecoilEnergy)
        Settings.setObject(Int(sMinTOFValue), forSetting: .MinTOFValue)
        Settings.setObject(Int(sMaxTOFValue), forSetting: .MaxTOFValue)
        Settings.setObject(tofUnitsControl.selectedSegment, forSetting: .TOFUnits)
        Settings.setObject(Int(sMinRecoilTime), forSetting: .MinRecoilTime)
        Settings.setObject(Int(sMaxRecoilTime), forSetting: .MaxRecoilTime)
        Settings.setObject(Int(sMaxRecoilBackTime), forSetting: .MaxRecoilBackTime)
        Settings.setObject(Int(sMaxFissionTime), forSetting: .MaxFissionTime)
        Settings.setObject(Int(sMaxTOFTime), forSetting: .MaxTOFTime)
        Settings.setObject(Int(sMaxVETOTime), forSetting: .MaxVETOTime)
        Settings.setObject(Int(sMaxGammaTime), forSetting: .MaxGammaTime)
        Settings.setObject(Int(sMaxNeutronTime), forSetting: .MaxNeutronTime)
        Settings.setObject(Int(sMaxRecoilFrontDeltaStrips), forSetting: .MaxRecoilFrontDeltaStrips)
        Settings.setObject(Int(sMaxRecoilBackDeltaStrips), forSetting: .MaxRecoilBackDeltaStrips)
        Settings.setObject(summarizeFissionsFront, forSetting: .SummarizeFissionsFront)
        Settings.setObject(requiredFissionAlphaBack, forSetting: .RequiredFissionAlphaBack)
        Settings.setObject(requiredRecoilBack, forSetting: .RequiredRecoilBack)
        Settings.setObject(requiredRecoil, forSetting: .RequiredRecoil)
        Settings.setObject(requiredGamma, forSetting: .RequiredGamma)
        Settings.setObject(requiredTOF, forSetting: .RequiredTOF)
        Settings.setObject(requiredVETO, forSetting: .RequiredVETO)
        Settings.setObject(searchNeutrons, forSetting: .SearchNeutrons)
        Settings.setObject(searchVETO, forSetting: .SearchVETO)
        Settings.setObject(trackBeamEnergy, forSetting: .TrackBeamEnergy)
        Settings.setObject(trackBeamCurrent, forSetting: .TrackBeamCurrent)
        Settings.setObject(trackBeamBackground, forSetting: .TrackBeamBackground)
        Settings.setObject(trackBeamIntegral, forSetting: .TrackBeamIntegral)
        Settings.setObject(startParticleControl.selectedSegment, forSetting: .SearchType)
        Settings.setObject(searchAlpha2, forSetting: .SearchAlpha2)
        Settings.setObject(Double(sMinAlpha2Energy), forSetting: .MinAlpha2Energy)
        Settings.setObject(Double(sMaxAlpha2Energy), forSetting: .MaxAlpha2Energy)
        Settings.setObject(Int(sMinAlpha2Time), forSetting: .MinAlpha2Time)
        Settings.setObject(Int(sMaxAlpha2Time), forSetting: .MaxAlpha2Time)
        Settings.setObject(Int(sMaxAlpha2FrontDeltaStrips), forSetting: .MaxAlpha2FrontDeltaStrips)
        Settings.setObject(searchSpecialEvents, forSetting: .SearchSpecialEvents)
        Settings.setObject(specialEventIds, forSetting: .SpecialEventIds)
        Settings.setObject(selectedRecoilType.rawValue, forSetting: .SelectedRecoilType)
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
        let branch = infoPlistStringForKey("CFBundleVersionGitBranch") ?? "unknown"
        labelBranch?.stringValue = "Branch: " + branch
    }
    
}
