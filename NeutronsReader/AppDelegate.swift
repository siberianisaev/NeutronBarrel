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
    @IBOutlet weak var focalDetectorControl: NSSegmentedControl!
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
    @IBOutlet weak var recoilBackTypeButton: NSPopUpButton!
    @IBOutlet weak var recoilTypeArrayController: NSArrayController!
    @IBOutlet weak var recoilBackTypeArrayController: NSArrayController!
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
    
    func readSettings() {
        sResultsFolderName = Settings.getStringSetting(.ResultsFolderName) ?? ""
        sNeutronsDetectorEfficiency = String(format: "%.1f", Settings.getDoubleSetting(.NeutronsDetectorEfficiency)) // %
        sMinFissionEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionEnergy)) // MeV
        sMaxFissionEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionEnergy)) // MeV
        sMinFissionBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionBackEnergy)) // MeV
        sMaxFissionBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionBackEnergy)) // MeV
        sMinRecoilFrontEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinRecoilFrontEnergy)) // MeV
        sMaxRecoilFrontEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilFrontEnergy)) // MeV
        sMinRecoilBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinRecoilBackEnergy)) // MeV
        sMaxRecoilBackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilBackEnergy)) // MeV
        sMinFissionWellEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionWellEnergy)) // MeV
        sMaxFissionWellEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionWellEnergy)) // MeV
        sMinTOFValue = String(format: "%d", Settings.getIntSetting(.MinTOFValue)) // channel or ns
        sMaxTOFValue = String(format: "%d", Settings.getIntSetting(.MaxTOFValue)) // channel or ns
        sMinRecoilTime = String(format: "%d", Settings.getIntSetting(.MinRecoilTime)) // mks
        sMaxRecoilTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilTime)) // mks
        sMaxRecoilBackTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackTime)) // mks
        sMaxRecoilBackBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackBackwardTime)) // mks
        sMaxFissionTime = String(format: "%d", Settings.getIntSetting(.MaxFissionTime)) // mks
        sMaxFissionBackBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionBackBackwardTime)) // mks
        sMaxFissionWellBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionWellBackwardTime)) // mks
        sMaxTOFTime = String(format: "%d", Settings.getIntSetting(.MaxTOFTime)) // mks
        sMaxVETOTime = String(format: "%d", Settings.getIntSetting(.MaxVETOTime)) // mks
        sMaxGammaTime = String(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
        sMaxNeutronTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
        sMaxRecoilFrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilFrontDeltaStrips))
        sMaxRecoilBackDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackDeltaStrips))
        summarizeFissionsFront = Settings.getBoolSetting(.SummarizeFissionsFront)
        summarizeFissionsFront2 = Settings.getBoolSetting(.SummarizeFissionsFront2)
        requiredFissionAlphaBack = Settings.getBoolSetting(.RequiredFissionAlphaBack)
        requiredRecoilBack = Settings.getBoolSetting(.RequiredRecoilBack)
        requiredRecoil = Settings.getBoolSetting(.RequiredRecoil)
        requiredGamma = Settings.getBoolSetting(.RequiredGamma)
        requiredGammaOrWell = Settings.getBoolSetting(.RequiredGammaOrWell)
        simplifyGamma = Settings.getBoolSetting(.SimplifyGamma)
        requiredWell = Settings.getBoolSetting(.RequiredWell)
        wellRecoilsAllowed = Settings.getBoolSetting(.WellRecoilsAllowed)
        searchExtraFromParticle2 = Settings.getBoolSetting(.SearchExtraFromParticle2)
        requiredTOF = Settings.getBoolSetting(.RequiredTOF)
        useTOF2 = Settings.getBoolSetting(.UseTOF2)
        requiredVETO = Settings.getBoolSetting(.RequiredVETO)
        searchNeutrons = Settings.getBoolSetting(.SearchNeutrons)
        searchFissionAlpha2 = Settings.getBoolSetting(.SearchFissionAlpha2)
        sBeamEnergyMin = String(format: "%.1f", Settings.getDoubleSetting(.BeamEnergyMin)) // MeV
        sBeamEnergyMax = String(format: "%.1f", Settings.getDoubleSetting(.BeamEnergyMax)) // MeV
        sMinFissionAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha2Energy)) // MeV
        sMaxFissionAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha2Energy)) // MeV
        sMinFissionAlpha2BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha2BackEnergy)) // MeV
        sMaxFissionAlpha2BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha2BackEnergy)) // MeV
        sMinFissionAlpha2Time = String(format: "%d", Settings.getIntSetting(.MinFissionAlpha2Time)) // mks
        sMaxFissionAlpha2Time = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha2Time)) // mks
        sMaxFissionAlpha2FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha2FrontDeltaStrips))
        sMaxConcurrentOperations = String(format: "%d", Settings.getIntSetting(.MaxConcurrentOperations))
        searchSpecialEvents = Settings.getBoolSetting(.SearchSpecialEvents)
        specialEventIds = Settings.getStringSetting(.SpecialEventIds) ?? ""
        gammaEncodersOnly = Settings.getBoolSetting(.GammaEncodersOnly)
        gammaEncoderIds = Settings.getStringSetting(.GammaEncoderIds) ?? ""
        searchVETO = Settings.getBoolSetting(.SearchVETO)
        searchWell = Settings.getBoolSetting(.SearchWell)
        trackBeamEnergy = Settings.getBoolSetting(.TrackBeamEnergy)
        trackBeamCurrent = Settings.getBoolSetting(.TrackBeamCurrent)
        trackBeamBackground = Settings.getBoolSetting(.TrackBeamBackground)
        trackBeamIntegral = Settings.getBoolSetting(.TrackBeamIntegral)
        searchFissionBackByFact = Settings.getBoolSetting(.SearchFissionBackByFact)
        searchFissionBack2ByFact = Settings.getBoolSetting(.SearchFissionBack2ByFact)
        searchRecoilBackByFact = Settings.getBoolSetting(.SearchRecoilBackByFact)
        
        setupRecoilTypes()
        setupRecoilBackTypes()
        startParticleControl.selectedSegment = Settings.getIntSetting(.StartSearchType)
        startParticleBackControl.selectedSegment = Settings.getIntSetting(.StartBackSearchType)
        secondParticleFrontControl.selectedSegment = Settings.getIntSetting(.SecondFrontSearchType)
        secondParticleBackControl.selectedSegment = Settings.getIntSetting(.SecondBackSearchType)
        wellParticleBackControl.selectedSegment = Settings.getIntSetting(.WellBackSearchType)
        startParticleChanged(nil)
        secondParticleBackChanged(nil)
        setupVETOView()
        setupWellView()
        setupAlpha2FormView()
        setupSearchExtraView()
        setupFissionAlpha1BackEnergyView()
        setupFissionAlpha2BackEnergyView()
        setupRecoilBackEnergyView()
        tofUnitsControl.selectedSegment = Settings.getIntSetting(.TOFUnits)
        focalDetectorControl.selectedSegment = Settings.getIntSetting(.FocalDetectorType, defaultValue: FocalDetectorType.large.rawValue)
        setupGammaEncodersView()
    }
    
    @IBInspectable dynamic var sResultsFolderName = ""
    @IBInspectable dynamic var sNeutronsDetectorEfficiency: String = ""
    @IBInspectable dynamic var sMinFissionEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionEnergy: String = ""
    @IBInspectable dynamic var sMinFissionBackEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionBackEnergy: String = ""
    @IBInspectable dynamic var sMinRecoilFrontEnergy: String = ""
    @IBInspectable dynamic var sMaxRecoilFrontEnergy: String = ""
    @IBInspectable dynamic var sMinRecoilBackEnergy: String = ""
    @IBInspectable dynamic var sMaxRecoilBackEnergy: String = ""
    @IBInspectable dynamic var sMinFissionWellEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionWellEnergy: String = ""
    @IBInspectable dynamic var sMinTOFValue: String = ""
    @IBInspectable dynamic var sMaxTOFValue: String = ""
    @IBInspectable dynamic var sMinRecoilTime: String = ""
    @IBInspectable dynamic var sMaxRecoilTime: String = ""
    @IBInspectable dynamic var sMaxRecoilBackTime: String = ""
    @IBInspectable dynamic var sMaxRecoilBackBackwardTime: String = ""
    @IBInspectable dynamic var sMaxFissionTime: String = ""
    @IBInspectable dynamic var sMaxFissionBackBackwardTime: String = ""
    @IBInspectable dynamic var sMaxFissionWellBackwardTime: String = ""
    @IBInspectable dynamic var sMaxTOFTime: String = ""
    @IBInspectable dynamic var sMaxVETOTime: String = ""
    @IBInspectable dynamic var sMaxGammaTime: String = ""
    @IBInspectable dynamic var sMaxNeutronTime: String = ""
    @IBInspectable dynamic var sMaxRecoilFrontDeltaStrips: String = ""
    @IBInspectable dynamic var sMaxRecoilBackDeltaStrips: String = ""
    @IBInspectable dynamic var summarizeFissionsFront: Bool = false
    @IBInspectable dynamic var summarizeFissionsFront2: Bool = false
    @IBInspectable dynamic var requiredFissionAlphaBack: Bool = false
    @IBInspectable dynamic var requiredRecoilBack: Bool = false
    @IBInspectable dynamic var requiredRecoil: Bool = false
    @IBInspectable dynamic var requiredGamma: Bool = false
    @IBInspectable dynamic var requiredGammaOrWell: Bool = false
    @IBInspectable dynamic var simplifyGamma: Bool = false
    @IBInspectable dynamic var requiredWell: Bool = false
    @IBInspectable dynamic var wellRecoilsAllowed: Bool = false
    @IBOutlet weak var searchExtraFromParticle2Button: NSButton!
    @IBInspectable dynamic var searchExtraFromParticle2: Bool = false
    @IBInspectable dynamic var requiredTOF: Bool = false
    @IBInspectable dynamic var useTOF2: Bool = false
    @IBInspectable dynamic var requiredVETO: Bool = false
    @IBInspectable dynamic var searchNeutrons: Bool = false
    @IBInspectable dynamic var searchFissionAlpha2: Bool = false {
        didSet {
            setupAlpha2FormView()
            searchExtraFromParticle2 = searchFissionAlpha2
            searchExtraFromParticle2Button.state = searchExtraFromParticle2 ? .on : .off
        }
    }
    @IBInspectable dynamic var sBeamEnergyMin: String = ""
    @IBInspectable dynamic var sBeamEnergyMax: String = ""
    @IBInspectable dynamic var sMinFissionAlpha2Energy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2Energy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha2BackEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2BackEnergy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha2Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2FrontDeltaStrips: String = ""
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
    @IBInspectable dynamic var searchSpecialEvents: Bool = false
    @IBInspectable dynamic var specialEventIds: String = ""
    @IBInspectable dynamic var searchVETO: Bool = false {
        didSet {
            setupVETOView()
        }
    }
    @IBInspectable dynamic var searchWell: Bool = false {
        didSet {
            setupWellView()
        }
    }
    @IBInspectable dynamic var trackBeamEnergy: Bool = false
    @IBInspectable dynamic var trackBeamCurrent: Bool = false
    @IBInspectable dynamic var trackBeamBackground: Bool = false
    @IBInspectable dynamic var trackBeamIntegral: Bool = false
    @IBInspectable dynamic var searchFissionBackByFact: Bool = false {
        didSet {
            setupFissionAlpha1BackEnergyView()
        }
    }
    @IBInspectable dynamic var searchFissionBack2ByFact: Bool = false {
        didSet {
            setupFissionAlpha2BackEnergyView()
        }
    }
    @IBInspectable dynamic var searchRecoilBackByFact: Bool = false {
        didSet {
            setupRecoilBackEnergyView()
        }
    }
    
    fileprivate let recoilTypes: [SearchType] = [.recoil, .heavy]
    fileprivate var selectedRecoilType: SearchType {
        return recoilTypes[recoilTypeArrayController.selectionIndex]
    }
    
    fileprivate var selectedRecoilBackType: SearchType {
        return recoilTypes[recoilBackTypeArrayController.selectionIndex]
    }
    
    fileprivate var formColor: CGColor {
        return NSColor.lightGray.withAlphaComponent(0.2).cgColor
    }
    
    fileprivate func setupGammaEncodersView() {
        gammaEncodersView.isHidden = !gammaEncodersOnly
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
    
    fileprivate func setupRecoilBackTypes() {
        let array = recoilTypes.map { (t: SearchType) -> String in
            return t.name()
        }
        var index = 0
        if let t = SearchType(rawValue: Settings.getIntSetting(.SelectedRecoilBackType)), let i = recoilTypes.firstIndex(of: t) {
            index = i
        }
        recoilBackTypeArrayController.content = array
        recoilBackTypeArrayController.setSelectedObjects([array[index]])
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
    
    @IBAction func focalDetectorChanged(_ sender: Any?) {
        Settings.changeSingle(.FocalDetectorType, value: focalDetectorControl.selectedSegment)
        StripDetectorManager.singleton.reset()
        didSelectStripsConfiguration(false, filePaths: nil)
    }
    
    @IBAction func startParticleChanged(_ sender: Any?) {
        if let type = SearchType(rawValue: startParticleControl.selectedSegment) {
            let isRecoil = type == .recoil
            requiredRecoil = requiredRecoil || isRecoil
            recoilFrontView.isHidden = isRecoil
            requiredRecoilButton.state = NSControl.StateValue(rawValue: requiredRecoil ? 1 : 0)
            requiredRecoilButton.isEnabled = !isRecoil
            fissionAlpha1View.isHidden = isRecoil
            fissionAlpha1TextField.stringValue = (type != .alpha ? "F" : "A") + "Front 1st"
            if sender != nil, !isRecoil {
                startParticleBackControl.selectedSegment = type.rawValue
                if !searchExtraFromParticle2 {
                    wellParticleBackControl.selectedSegment = type.rawValue
                }
            }
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
        let sc = SearchCriteria()
        sc.resultsFolderName = sResultsFolderName
        let startFrontType = SearchType(rawValue: startParticleControl.selectedSegment) ?? .recoil
        let startFromRecoil = startFrontType == .recoil
        sc.neutronsDetectorEfficiency = Double(sNeutronsDetectorEfficiency) ?? 0
        sc.startParticleType = startFromRecoil ? selectedRecoilType : startFrontType
        sc.startParticleBackType = startFromRecoil ? selectedRecoilBackType : SearchType(rawValue: startParticleBackControl.selectedSegment) ?? .fission
        sc.secondParticleFrontType = SearchType(rawValue: secondParticleFrontControl.selectedSegment) ?? .recoil
        sc.secondParticleBackType = SearchType(rawValue: secondParticleBackControl.selectedSegment) ?? .recoil
        sc.wellParticleBackType = SearchType(rawValue: wellParticleBackControl.selectedSegment) ?? .fission
        sc.fissionAlphaFrontMinEnergy = Double(sMinFissionEnergy) ?? 0
        sc.fissionAlphaFrontMaxEnergy = Double(sMaxFissionEnergy) ?? 0
        sc.fissionAlphaBackMinEnergy = Double(sMinFissionBackEnergy) ?? 0
        sc.fissionAlphaBackMaxEnergy = Double(sMaxFissionBackEnergy) ?? 0
        sc.fissionAlphaWellMinEnergy = Double(sMinFissionWellEnergy) ?? 0
        sc.fissionAlphaWellMaxEnergy = Double(sMaxFissionWellEnergy) ?? 0
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
        sc.requiredGammaOrWell = requiredGammaOrWell
        sc.simplifyGamma = simplifyGamma
        sc.requiredWell = requiredWell
        sc.wellRecoilsAllowed = wellRecoilsAllowed
        sc.searchExtraFromParticle2 = searchExtraFromParticle2
        sc.searchNeutrons = searchNeutrons
        sc.maxNeutronTime = UInt64(sMaxNeutronTime) ?? 0
        sc.searchSpecialEvents = searchSpecialEvents
        sc.gammaEncodersOnly = gammaEncodersOnly
        sc.searchVETO = searchVETO
        sc.trackBeamEnergy = trackBeamEnergy
        sc.trackBeamCurrent = trackBeamCurrent
        sc.trackBeamBackground = trackBeamBackground
        sc.trackBeamIntegral = trackBeamIntegral
        sc.recoilType = selectedRecoilType
        sc.recoilBackType = selectedRecoilBackType
        sc.searchWell = searchWell
        sc.beamEnergyMin = Float(sBeamEnergyMin) ?? 0
        sc.beamEnergyMax = Float(sBeamEnergyMax) ?? 0
        
        func idsFrom(string: String) -> Set<Int> {
            let ids = string.components(separatedBy: ",").map({ (s: String) -> Int in
                return Int(s) ?? 0
            }).filter({ (i: Int) -> Bool in
                return i > 0
            })
            return Set(ids)
        }
        sc.specialEventIds = idsFrom(string: specialEventIds)
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
        let dict: [Setting: Any?] = [
            .NeutronsDetectorEfficiency: Double(sNeutronsDetectorEfficiency),
            .MinFissionEnergy: Double(sMinFissionEnergy),
            .MaxFissionEnergy: Double(sMaxFissionEnergy),
            .MinFissionBackEnergy: Double(sMinFissionBackEnergy),
            .MaxFissionBackEnergy: Double(sMaxFissionBackEnergy),
            .MinRecoilFrontEnergy: Double(sMinRecoilFrontEnergy),
            .MaxRecoilFrontEnergy: Double(sMaxRecoilFrontEnergy),
            .MinRecoilBackEnergy: Double(sMinRecoilBackEnergy),
            .MaxRecoilBackEnergy: Double(sMaxRecoilBackEnergy),
            .MinFissionWellEnergy: Double(sMinFissionWellEnergy),
            .MaxFissionWellEnergy: Double(sMaxFissionWellEnergy),
            .BeamEnergyMin: Float(sBeamEnergyMin),
            .BeamEnergyMax: Float(sBeamEnergyMax),
            .MinTOFValue: Int(sMinTOFValue),
            .MaxTOFValue: Int(sMaxTOFValue),
            .TOFUnits: tofUnitsControl.selectedSegment,
            .MinRecoilTime: Int(sMinRecoilTime),
            .MaxRecoilTime: Int(sMaxRecoilTime),
            .MaxRecoilBackTime: Int(sMaxRecoilBackTime),
            .MaxRecoilBackBackwardTime: Int(sMaxRecoilBackBackwardTime),
            .MaxFissionTime: Int(sMaxFissionTime),
            .MaxFissionBackBackwardTime: Int(sMaxFissionBackBackwardTime),
            .MaxFissionWellBackwardTime: Int(sMaxFissionWellBackwardTime),
            .MaxTOFTime: Int(sMaxTOFTime),
            .MaxVETOTime: Int(sMaxVETOTime),
            .MaxGammaTime: Int(sMaxGammaTime),
            .MaxNeutronTime: Int(sMaxNeutronTime),
            .MaxRecoilFrontDeltaStrips: Int(sMaxRecoilFrontDeltaStrips),
            .MaxRecoilBackDeltaStrips: Int(sMaxRecoilBackDeltaStrips),
            .SummarizeFissionsFront: summarizeFissionsFront,
            .SummarizeFissionsFront2: summarizeFissionsFront2,
            .RequiredFissionAlphaBack: requiredFissionAlphaBack,
            .RequiredRecoilBack: requiredRecoilBack,
            .RequiredRecoil: requiredRecoil,
            .RequiredGamma: requiredGamma,
            .RequiredGammaOrWell: requiredGammaOrWell,
            .SimplifyGamma: simplifyGamma,
            .RequiredWell: requiredWell,
            .WellRecoilsAllowed: wellRecoilsAllowed,
            .SearchExtraFromParticle2: searchExtraFromParticle2,
            .RequiredTOF: requiredTOF,
            .UseTOF2: useTOF2,
            .RequiredVETO: requiredVETO,
            .SearchNeutrons: searchNeutrons,
            .SearchVETO: searchVETO,
            .TrackBeamEnergy: trackBeamEnergy,
            .TrackBeamCurrent: trackBeamCurrent,
            .TrackBeamBackground: trackBeamBackground,
            .TrackBeamIntegral: trackBeamIntegral,
            .StartSearchType: startParticleControl.selectedSegment,
            .StartBackSearchType: startParticleBackControl.selectedSegment,
            .SecondFrontSearchType: secondParticleFrontControl.selectedSegment,
            .SecondBackSearchType: secondParticleBackControl.selectedSegment,
            .WellBackSearchType: wellParticleBackControl.selectedSegment,
            .SearchFissionAlpha2: searchFissionAlpha2,
            .MinFissionAlpha2Energy: Double(sMinFissionAlpha2Energy),
            .MaxFissionAlpha2Energy: Double(sMaxFissionAlpha2Energy),
            .MinFissionAlpha2BackEnergy: Double(sMinFissionAlpha2BackEnergy),
            .MaxFissionAlpha2BackEnergy: Double(sMaxFissionAlpha2BackEnergy),
            .MinFissionAlpha2Time: Int(sMinFissionAlpha2Time),
            .MaxFissionAlpha2Time: Int(sMaxFissionAlpha2Time),
            .MaxFissionAlpha2FrontDeltaStrips: Int(sMaxFissionAlpha2FrontDeltaStrips),
            .MaxConcurrentOperations: maxConcurrentOperationCount,
            .SearchSpecialEvents: searchSpecialEvents,
            .SpecialEventIds: specialEventIds,
            .GammaEncodersOnly: gammaEncodersOnly,
            .GammaEncoderIds: gammaEncoderIds,
            .SelectedRecoilType: selectedRecoilType.rawValue,
            .SelectedRecoilBackType: selectedRecoilBackType.rawValue,
            .SearchFissionBackByFact: searchFissionBackByFact,
            .SearchFissionBack2ByFact: searchFissionBack2ByFact,
            .SearchRecoilBackByFact: searchRecoilBackByFact,
            .SearchWell: searchWell,
            .ResultsFolderName: sResultsFolderName,
            .FocalDetectorType: focalDetectorControl.selectedSegment
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
