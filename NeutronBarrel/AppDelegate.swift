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
    @IBOutlet weak var sfSourceControl: NSSegmentedControl!
    @IBOutlet weak var indicatorData: NSTextField!
    @IBOutlet weak var indicatorCalibration: NSTextField!
    @IBOutlet weak var indicatorStripsConfig: NSTextField!
    @IBOutlet weak var buttonRun: NSButton!
    @IBOutlet weak var recoilView: NSView!
    @IBOutlet weak var fissionAlphaView: NSView!
    @IBOutlet weak var fissionAlpha1View: NSView!
    @IBOutlet weak var fissionAlpha2View: NSView!
    @IBOutlet weak var fissionAlpha2FormView: NSView!
    @IBOutlet weak var fissionAlpha3FormView: NSView!
    @IBOutlet weak var fissionAlpha4FormView: NSView!
    @IBOutlet weak var searchExtraView: NSView!
    @IBOutlet weak var wellView: NSView!
    @IBOutlet weak var requiredRecoilButton: NSButton!
    @IBOutlet weak var fissionAlpha1Button: NSButton!
    @IBOutlet weak var fissionAlpha2Button: NSButton!
    @IBOutlet weak var fissionAlpha3Button: NSButton!
    @IBOutlet weak var fissionAlpha4Button: NSButton!
    @IBOutlet weak var buttonRemoveCalibration: NSButton!
    @IBOutlet weak var buttonRemoveStripsConfiguration: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    @IBOutlet weak var fissionAlpha1BackEnergyView: NSView!
    @IBOutlet weak var fissionAlpha2BackEnergyView: NSView!
    @IBOutlet weak var fissionAlpha3BackEnergyView: NSView!
    @IBOutlet weak var fissionAlpha4BackEnergyView: NSView!
    @IBOutlet weak var recoilBackEnergyView: NSView!
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
        sMaxFissionWellAngle = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionWellAngle)) // degree
        sMinRecoilTime = String(format: "%d", Settings.getUInt64Setting(.MinRecoilTime)) // mks
        sMaxRecoilTime = String(format: "%d", Settings.getUInt64Setting(.MaxRecoilTime)) // mks
        sMaxRecoilBackTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackTime)) // mks
        sMaxRecoilBackBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackBackwardTime)) // mks
        sMaxFissionTime = String(format: "%d", Settings.getIntSetting(.MaxFissionTime)) // mks
        sMaxFissionBackBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionBackBackwardTime)) // mks
        sMaxFissionWellBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxFissionWellBackwardTime)) // mks
        sMaxGammaTime = String(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
        sMaxGammaBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxGammaBackwardTime)) // mks
        sMinNeutronTime = String(format: "%d", Settings.getIntSetting(.MinNeutronTime)) // mks
        sMaxNeutronTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
        sMaxNeutronBackwardTime = String(format: "%d", Settings.getIntSetting(.MaxNeutronBackwardTime)) // mks
        sMaxRecoilFrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilFrontDeltaStrips))
        sMaxRecoilBackDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxRecoilBackDeltaStrips))
        sMaxFrontBackEnergyDelta = String(format: "%d", Settings.getIntSetting(.MaxFrontBackEnergyDelta)) // keV
        summarizeFissionsFront = Settings.getBoolSetting(.SummarizeFissionsFront)
        summarizeFissionsFront2 = Settings.getBoolSetting(.SummarizeFissionsFront2)
        summarizeFissionsFront3 = Settings.getBoolSetting(.SummarizeFissionsFront3)
        summarizeFissionsFront4 = Settings.getBoolSetting(.SummarizeFissionsFront4)
        requiredFissionAlphaBack = Settings.getBoolSetting(.RequiredFissionAlphaBack)
        searchFirstRecoilOnly = Settings.getBoolSetting(.SearchFirstRecoilOnly)
        requiredRecoilBack = Settings.getBoolSetting(.RequiredRecoilBack)
        requiredRecoil = Settings.getBoolSetting(.RequiredRecoil)
        requiredGamma = Settings.getBoolSetting(.RequiredGamma)
        requiredGammaOrWell = Settings.getBoolSetting(.RequiredGammaOrWell)
        simplifyGamma = Settings.getBoolSetting(.SimplifyGamma)
        requiredWell = Settings.getBoolSetting(.RequiredWell)
        wellRecoilsAllowed = Settings.getBoolSetting(.WellRecoilsAllowed)
        searchExtraFromLastParticle = Settings.getBoolSetting(.SearchExtraFromLastParticle)
        inBeamOnly = Settings.getBoolSetting(.InBeamOnly)
        outBeamOnly = Settings.getBoolSetting(.OutBeamOnly)
        useOverflow = Settings.getBoolSetting(.UseOverflow)
        usePileUp = Settings.getBoolSetting(.UsePileUp)
        searchNeutrons = Settings.getBoolSetting(.SearchNeutrons)
        neutronsBackground = Settings.getBoolSetting(.NeutronsBackground)
        simultaneousDecaysFilterForNeutrons = Settings.getBoolSetting(.SimultaneousDecaysFilterForNeutrons)
        collapseNeutronOverlays = Settings.getBoolSetting(.CollapseNeutronOverlays)
        neutronsPositions = Settings.getBoolSetting(.NeutronsPositions)
        sfSourcePlaced = Settings.getBoolSetting(.SFSourcePlaced)
        searchFissionAlpha1 = Settings.getBoolSetting(.SearchFissionAlpha1)
        searchFissionAlpha2 = Settings.getBoolSetting(.SearchFissionAlpha2)
        searchFissionAlpha3 = Settings.getBoolSetting(.SearchFissionAlpha3)
        searchFissionAlpha4 = Settings.getBoolSetting(.SearchFissionAlpha4)
        sMinFissionAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha2Energy)) // MeV
        sMaxFissionAlpha2Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha2Energy)) // MeV
        sMinFissionAlpha2BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha2BackEnergy)) // MeV
        sMaxFissionAlpha2BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha2BackEnergy)) // MeV
        sMinFissionAlpha2Time = String(format: "%d", Settings.getUInt64Setting(.MinFissionAlpha2Time)) // mks
        sMaxFissionAlpha2Time = String(format: "%d", Settings.getUInt64Setting(.MaxFissionAlpha2Time)) // mks
        sMaxFissionAlpha2FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha2FrontDeltaStrips))
        sMinFissionAlpha3Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha3Energy)) // MeV
        sMaxFissionAlpha3Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha3Energy)) // MeV
        sMinFissionAlpha3BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha3BackEnergy)) // MeV
        sMaxFissionAlpha3BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha3BackEnergy)) // MeV
        sMinFissionAlpha3Time = String(format: "%d", Settings.getUInt64Setting(.MinFissionAlpha3Time)) // mks
        sMaxFissionAlpha3Time = String(format: "%d", Settings.getUInt64Setting(.MaxFissionAlpha3Time)) // mks
        sMaxFissionAlpha3FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha3FrontDeltaStrips))
        sMinFissionAlpha4Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha4Energy)) // MeV
        sMaxFissionAlpha4Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha4Energy)) // MeV
        sMinFissionAlpha4BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha4BackEnergy)) // MeV
        sMaxFissionAlpha4BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha4BackEnergy)) // MeV
        sMinFissionAlpha4Time = String(format: "%d", Settings.getUInt64Setting(.MinFissionAlpha4Time)) // mks
        sMaxFissionAlpha4Time = String(format: "%d", Settings.getUInt64Setting(.MaxFissionAlpha4Time)) // mks
        sMaxFissionAlpha4FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha4FrontDeltaStrips))
        sMaxConcurrentOperations = String(format: "%d", Settings.getIntSetting(.MaxConcurrentOperations))
        gammaEncodersOnly = Settings.getBoolSetting(.GammaEncodersOnly)
        gammaEncoderIds = Settings.getStringSetting(.GammaEncoderIds) ?? ""
        searchWell = Settings.getBoolSetting(.SearchWell)
        searchRecoils = Settings.getBoolSetting(.SearchRecoils)
        trackBeamEnergy = Settings.getBoolSetting(.TrackBeamEnergy)
        trackBeamCurrent = Settings.getBoolSetting(.TrackBeamCurrent)
        trackBeamBackground = Settings.getBoolSetting(.TrackBeamBackground)
        trackBeamIntegral = Settings.getBoolSetting(.TrackBeamIntegral)
        searchFissionBackByFact = Settings.getBoolSetting(.SearchFissionBackByFact)
        searchFissionBack2ByFact = Settings.getBoolSetting(.SearchFissionBack2ByFact)
        searchFissionBack3ByFact = Settings.getBoolSetting(.SearchFissionBack3ByFact)
        searchFissionBack4ByFact = Settings.getBoolSetting(.SearchFissionBack4ByFact)
        searchRecoilBackByFact = Settings.getBoolSetting(.SearchRecoilBackByFact)
        
        startParticleChanged(nil)
        setupWellView()
        recoilView.setupForm()
        fissionAlphaView.setupForm()
        searchExtraView.setupForm()
        setupAlpha1FormView()
        setupAlpha2FormView()
        setupAlpha3FormView()
        setupAlpha4FormView()
        setupFissionAlpha1BackEnergyView()
        setupFissionAlpha2BackEnergyView()
        setupFissionAlpha3BackEnergyView()
        setupFissionAlpha4BackEnergyView()
        setupRecoilBackEnergyView()
        sfSourceControl.selectedSegment = Settings.getIntSetting(.SFSource)
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
    @IBInspectable dynamic var sMaxFissionWellAngle: String = ""
    @IBInspectable dynamic var sMinRecoilTime: String = ""
    @IBInspectable dynamic var sMaxRecoilTime: String = ""
    @IBInspectable dynamic var sMaxRecoilBackTime: String = ""
    @IBInspectable dynamic var sMaxRecoilBackBackwardTime: String = ""
    @IBInspectable dynamic var sMaxFissionTime: String = ""
    @IBInspectable dynamic var sMaxFissionBackBackwardTime: String = ""
    @IBInspectable dynamic var sMaxFissionWellBackwardTime: String = ""
    @IBInspectable dynamic var sMaxGammaTime: String = ""
    @IBInspectable dynamic var sMaxGammaBackwardTime: String = ""
    @IBInspectable dynamic var sMinNeutronTime: String = ""
    @IBInspectable dynamic var sMaxNeutronTime: String = ""
    @IBInspectable dynamic var sMaxNeutronBackwardTime: String = ""
    @IBInspectable dynamic var sMaxRecoilFrontDeltaStrips: String = ""
    @IBInspectable dynamic var sMaxRecoilBackDeltaStrips: String = ""
    @IBInspectable dynamic var sMaxFrontBackEnergyDelta: String = ""
    @IBInspectable dynamic var summarizeFissionsFront: Bool = false
    @IBInspectable dynamic var summarizeFissionsFront2: Bool = false
    @IBInspectable dynamic var summarizeFissionsFront3: Bool = false
    @IBInspectable dynamic var summarizeFissionsFront4: Bool = false
    @IBInspectable dynamic var summarizeFissionsBack: Bool = false
    @IBInspectable dynamic var requiredFissionAlphaBack: Bool = false
    @IBInspectable dynamic var searchFirstRecoilOnly: Bool = false
    @IBInspectable dynamic var requiredRecoilBack: Bool = false
    @IBInspectable dynamic var requiredRecoil: Bool = false
    @IBInspectable dynamic var requiredGamma: Bool = false
    @IBInspectable dynamic var requiredGammaOrWell: Bool = false
    @IBInspectable dynamic var simplifyGamma: Bool = false
    @IBInspectable dynamic var requiredWell: Bool = false
    @IBInspectable dynamic var wellRecoilsAllowed: Bool = false
    @IBOutlet weak var searchExtraFromLastParticleButton: NSButton!
    @IBInspectable dynamic var searchExtraFromLastParticle: Bool = false
    @IBInspectable dynamic var inBeamOnly: Bool = false
    @IBInspectable dynamic var outBeamOnly: Bool = false
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
    @IBInspectable dynamic var sfSourcePlaced: Bool = false {
        didSet {
            sfSourceControl.isHidden = !sfSourcePlaced
        }
    }
    @IBInspectable dynamic var searchRecoils: Bool = true {
        didSet {
            recoilView.isHidden = !searchRecoils
        }
    }
    @IBInspectable dynamic var searchFissionAlpha1: Bool = false {
        didSet {
            startParticleChanged(nil)
            setupAlpha1FormView()
            if !searchFissionAlpha1 {
                searchFissionAlpha2 = false
            }
        }
    }
    @IBInspectable dynamic var searchFissionAlpha2: Bool = false {
        didSet {
            setupAlpha2FormView()
            if !searchFissionAlpha2 {
                searchFissionAlpha3 = false
            }
            searchExtraFromLastParticle = searchFissionAlpha2
            searchExtraFromLastParticleButton.state = searchExtraFromLastParticle ? .on : .off
            searchExtraFromLastParticleButton.isHidden = !searchFissionAlpha2
        }
    }
    @IBInspectable dynamic var searchFissionAlpha3: Bool = false {
        didSet {
            setupAlpha3FormView()
            if !searchFissionAlpha3 {
                searchFissionAlpha4 = false
            }
        }
    }
    @IBInspectable dynamic var searchFissionAlpha4: Bool = false {
        didSet {
            setupAlpha4FormView()
        }
    }
    @IBInspectable dynamic var sMinFissionAlpha2Energy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2Energy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha2BackEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2BackEnergy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha2Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha2FrontDeltaStrips: String = ""
    @IBInspectable dynamic var sMinFissionAlpha3Energy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha3Energy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha3BackEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha3BackEnergy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha3Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha3Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha3FrontDeltaStrips: String = ""
    @IBInspectable dynamic var sMinFissionAlpha4Energy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha4Energy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha4BackEnergy: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha4BackEnergy: String = ""
    @IBInspectable dynamic var sMinFissionAlpha4Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha4Time: String = ""
    @IBInspectable dynamic var sMaxFissionAlpha4FrontDeltaStrips: String = ""
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
    @IBInspectable dynamic var searchFissionBack3ByFact: Bool = false {
        didSet {
            setupFissionAlpha3BackEnergyView()
        }
    }
    @IBInspectable dynamic var searchFissionBack4ByFact: Bool = false {
        didSet {
            setupFissionAlpha4BackEnergyView()
        }
    }
    @IBInspectable dynamic var searchRecoilBackByFact: Bool = false {
        didSet {
            setupRecoilBackEnergyView()
        }
    }
    
    fileprivate func setupGammaEncodersView() {
        gammaEncodersView.isHidden = !gammaEncodersOnly
    }
    
    fileprivate func setupAlpha1FormView() {
        fissionAlpha1View.isHidden = !searchFissionAlpha1
    }
    
    fileprivate func setupAlpha2FormView() {
        fissionAlpha2FormView.isHidden = !searchFissionAlpha2
    }
    
    fileprivate func setupAlpha3FormView() {
        fissionAlpha3FormView.isHidden = !searchFissionAlpha3
    }
    
    fileprivate func setupAlpha4FormView() {
        fissionAlpha4FormView.isHidden = !searchFissionAlpha4
    }
    
    fileprivate func setupFissionAlpha1BackEnergyView() {
        fissionAlpha1BackEnergyView.isHidden = searchFissionBackByFact
    }
    
    fileprivate func setupFissionAlpha2BackEnergyView() {
        fissionAlpha2BackEnergyView.isHidden = searchFissionBack2ByFact
    }
    
    fileprivate func setupFissionAlpha3BackEnergyView() {
        fissionAlpha3BackEnergyView.isHidden = searchFissionBack3ByFact
    }
    
    fileprivate func setupFissionAlpha4BackEnergyView() {
        fissionAlpha4BackEnergyView.isHidden = searchFissionBack4ByFact
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
        buttonRemoveStripsConfiguration.isHidden = true
        showFilePaths(nil, label: labelStripsConfigurationFileName)
    }
    
    fileprivate func startType() -> SearchType {
        if searchFissionAlpha1 {
            return .alpha
        } else {
            return .recoil
        }
    }
    
    @IBAction func startParticleChanged(_ sender: Any?) {
        let type = startType()
        let isRecoil = type == .recoil
        requiredRecoil = requiredRecoil || isRecoil
        requiredRecoilButton.state = NSControl.StateValue(rawValue: requiredRecoil ? 1 : 0)
        requiredRecoilButton.isEnabled = !isRecoil
    }
    
    fileprivate func setupWellView() {
        wellView.isHidden = !searchWell
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
        let startFrontType = startType()
        let startFromRecoil = startFrontType == .recoil
        sc.neutronsDetectorEfficiency = Double(sNeutronsDetectorEfficiency) ?? 0
        sc.neutronsDetectorEfficiencyError = Double(sNeutronsDetectorEfficiencyError) ?? 0
        sc.excludeNeutronCounters = sExcludeNeutronCounters.components(separatedBy: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        }
        sc.startParticleType = startFromRecoil ? .recoil : .alpha
        sc.fissionAlphaFrontMinEnergy = Double(sMinFissionEnergy) ?? 0
        sc.fissionAlphaFrontMaxEnergy = Double(sMaxFissionEnergy) ?? 0
        sc.fissionAlphaBackMinEnergy = Double(sMinFissionBackEnergy) ?? 0
        sc.fissionAlphaBackMaxEnergy = Double(sMaxFissionBackEnergy) ?? 0
        sc.fissionAlphaWellMinEnergy = Double(sMinFissionWellEnergy) ?? 0
        sc.fissionAlphaWellMaxEnergy = Double(sMaxFissionWellEnergy) ?? 0
        sc.fissionAlphaWellMaxAngle = Double(sMaxFissionWellAngle) ?? 0
        sc.searchFissionAlphaBackByFact = searchFissionBackByFact
        sc.searchRecoilBackByFact = searchRecoilBackByFact
        sc.fissionAlphaMaxTime = UInt64(sMaxFissionTime) ?? 0
        sc.fissionAlphaBackBackwardMaxTime = UInt64(sMaxFissionBackBackwardTime) ?? 0
        sc.fissionAlphaWellBackwardMaxTime = UInt64(sMaxFissionWellBackwardTime) ?? 0
        sc.summarizeFissionsAlphaFront = summarizeFissionsFront
        sc.summarizeFissionsAlphaBack = summarizeFissionsBack
        
        var next = [Int: SearchNextCriteria]()
        if !startFromRecoil, searchFissionAlpha2 {
            let criteria2 = SearchNextCriteria(summarizeFront: summarizeFissionsFront2,
                                               frontMinEnergy: Double(sMinFissionAlpha2Energy) ?? 0,
                                               frontMaxEnergy: Double(sMaxFissionAlpha2Energy) ?? 0,
                                               backMinEnergy: Double(sMinFissionAlpha2BackEnergy) ?? 0,
                                               backMaxEnergy: Double(sMaxFissionAlpha2BackEnergy) ?? 0,
                                               minTime: UInt64(sMinFissionAlpha2Time) ?? 0,
                                               maxTime: UInt64(sMaxFissionAlpha2Time) ?? 0,
                                               maxDeltaStrips: Int(sMaxFissionAlpha2FrontDeltaStrips) ?? 0,
                                               backByFact: searchFissionBack2ByFact,
                                               frontType: .alpha,
                                               backType: .alpha)
            next[2] = criteria2
            if searchFissionAlpha3 {
                let criteria3 = SearchNextCriteria(summarizeFront: summarizeFissionsFront3,
                                                   frontMinEnergy: Double(sMinFissionAlpha3Energy) ?? 0,
                                                   frontMaxEnergy: Double(sMaxFissionAlpha3Energy) ?? 0,
                                                   backMinEnergy: Double(sMinFissionAlpha3BackEnergy) ?? 0,
                                                   backMaxEnergy: Double(sMaxFissionAlpha3BackEnergy) ?? 0,
                                                   minTime: UInt64(sMinFissionAlpha3Time) ?? 0,
                                                   maxTime: UInt64(sMaxFissionAlpha3Time) ?? 0,
                                                   maxDeltaStrips: Int(sMaxFissionAlpha3FrontDeltaStrips) ?? 0,
                                                   backByFact: searchFissionBack3ByFact,
                                                   frontType: .alpha,
                                                   backType: .alpha)
                next[3] = criteria3
                
                if searchFissionAlpha4 {
                    let criteria4 = SearchNextCriteria(summarizeFront: summarizeFissionsFront4,
                                                       frontMinEnergy: Double(sMinFissionAlpha4Energy) ?? 0,
                                                       frontMaxEnergy: Double(sMaxFissionAlpha4Energy) ?? 0,
                                                       backMinEnergy: Double(sMinFissionAlpha4BackEnergy) ?? 0,
                                                       backMaxEnergy: Double(sMaxFissionAlpha4BackEnergy) ?? 0,
                                                       minTime: UInt64(sMinFissionAlpha4Time) ?? 0,
                                                       maxTime: UInt64(sMaxFissionAlpha4Time) ?? 0,
                                                       maxDeltaStrips: Int(sMaxFissionAlpha4FrontDeltaStrips) ?? 0,
                                                       backByFact: searchFissionBack4ByFact,
                                                       frontType: .alpha,
                                                       backType: .alpha)
                    next[4] = criteria4
                }
            }
        }
        sc.next = next
        
        sc.recoilFrontMaxDeltaStrips = Int(sMaxRecoilFrontDeltaStrips) ?? 0
        sc.recoilBackMaxDeltaStrips = Int(sMaxRecoilBackDeltaStrips) ?? 0
        sc.frontBackMaxEnergyDelta = Int(sMaxFrontBackEnergyDelta) ?? 0
        sc.requiredFissionAlphaBack = requiredFissionAlphaBack
        sc.searchFirstRecoilOnly = searchFirstRecoilOnly
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
        sc.inBeamOnly = inBeamOnly
        sc.outBeamOnly = outBeamOnly
        sc.useOverflow = useOverflow
        sc.usePileUp = usePileUp
        sc.maxGammaTime = UInt64(sMaxGammaTime) ?? 0
        sc.maxGammaBackwardTime = UInt64(sMaxGammaBackwardTime) ?? 0
        sc.requiredGamma = requiredGamma
        sc.requiredGammaOrWell = requiredGammaOrWell
        sc.simplifyGamma = simplifyGamma
        sc.requiredWell = requiredWell
        sc.wellRecoilsAllowed = wellRecoilsAllowed
        sc.searchExtraFromLastParticle = searchExtraFromLastParticle
        sc.searchNeutrons = searchNeutrons
        sc.neutronsBackground = neutronsBackground
        sc.simultaneousDecaysFilterForNeutrons = simultaneousDecaysFilterForNeutrons
        sc.collapseNeutronOverlays = collapseNeutronOverlays
        sc.neutronsPositions = neutronsPositions
        sc.placedSFSource = sfSourcePlaced ? SFSource(rawValue: sfSourceControl.selectedSegment) : nil
        sc.minNeutronTime = UInt64(sMinNeutronTime) ?? 0
        sc.maxNeutronTime = UInt64(sMaxNeutronTime) ?? 0
        sc.maxNeutronBackwardTime = UInt64(sMaxNeutronBackwardTime) ?? 0
        sc.gammaEncodersOnly = gammaEncodersOnly
        sc.trackBeamEnergy = trackBeamEnergy
        sc.trackBeamCurrent = trackBeamCurrent
        sc.trackBeamBackground = trackBeamBackground
        sc.trackBeamIntegral = trackBeamIntegral
        sc.searchWell = searchWell
        sc.searchRecoils = searchRecoils
        
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
            .MaxFissionWellAngle: Double(sMaxFissionWellAngle),
            .SFSource: sfSourceControl.selectedSegment,
            .MinRecoilTime: Int(sMinRecoilTime),
            .MaxRecoilTime: Int(sMaxRecoilTime),
            .MaxRecoilBackTime: Int(sMaxRecoilBackTime),
            .MaxRecoilBackBackwardTime: Int(sMaxRecoilBackBackwardTime),
            .MaxFissionTime: Int(sMaxFissionTime),
            .MaxFissionBackBackwardTime: Int(sMaxFissionBackBackwardTime),
            .MaxFissionWellBackwardTime: Int(sMaxFissionWellBackwardTime),
            .MaxGammaTime: Int(sMaxGammaTime),
            .MaxGammaBackwardTime: Int(sMaxGammaBackwardTime),
            .MinNeutronTime: Int(sMinNeutronTime),
            .MaxNeutronTime: Int(sMaxNeutronTime),
            .MaxNeutronBackwardTime: Int(sMaxNeutronBackwardTime),
            .MaxRecoilFrontDeltaStrips: Int(sMaxRecoilFrontDeltaStrips),
            .MaxRecoilBackDeltaStrips: Int(sMaxRecoilBackDeltaStrips),
            .MaxFrontBackEnergyDelta: Int(sMaxFrontBackEnergyDelta),
            .SummarizeFissionsFront: summarizeFissionsFront,
            .SummarizeFissionsFront2: summarizeFissionsFront2,
            .SummarizeFissionsFront3: summarizeFissionsFront3,
            .SummarizeFissionsFront4: summarizeFissionsFront4,
            .SummarizeFissionsBack: summarizeFissionsBack,
            .RequiredFissionAlphaBack: requiredFissionAlphaBack,
            .SearchFirstRecoilOnly: searchFirstRecoilOnly,
            .RequiredRecoilBack: requiredRecoilBack,
            .RequiredRecoil: requiredRecoil,
            .RequiredGamma: requiredGamma,
            .RequiredGammaOrWell: requiredGammaOrWell,
            .SimplifyGamma: simplifyGamma,
            .RequiredWell: requiredWell,
            .WellRecoilsAllowed: wellRecoilsAllowed,
            .SearchExtraFromLastParticle: searchExtraFromLastParticle,
            .InBeamOnly: inBeamOnly,
            .OutBeamOnly: outBeamOnly,
            .UseOverflow: useOverflow,
            .UsePileUp: usePileUp,
            .SearchNeutrons: searchNeutrons,
            .NeutronsBackground: neutronsBackground,
            .SimultaneousDecaysFilterForNeutrons: simultaneousDecaysFilterForNeutrons,
            .CollapseNeutronOverlays: collapseNeutronOverlays,
            .NeutronsPositions: neutronsPositions,
            .SFSourcePlaced: sfSourcePlaced,
            .TrackBeamEnergy: trackBeamEnergy,
            .TrackBeamCurrent: trackBeamCurrent,
            .TrackBeamBackground: trackBeamBackground,
            .TrackBeamIntegral: trackBeamIntegral,
            .SearchFissionAlpha1: searchFissionAlpha1,
            .SearchFissionAlpha2: searchFissionAlpha2,
            .SearchFissionAlpha3: searchFissionAlpha3,
            .SearchFissionAlpha4: searchFissionAlpha4,
            .MinFissionAlpha2Energy: Double(sMinFissionAlpha2Energy),
            .MaxFissionAlpha2Energy: Double(sMaxFissionAlpha2Energy),
            .MinFissionAlpha2BackEnergy: Double(sMinFissionAlpha2BackEnergy),
            .MaxFissionAlpha2BackEnergy: Double(sMaxFissionAlpha2BackEnergy),
            .MinFissionAlpha2Time: Int(sMinFissionAlpha2Time),
            .MaxFissionAlpha2Time: Int(sMaxFissionAlpha2Time),
            .MaxFissionAlpha2FrontDeltaStrips: Int(sMaxFissionAlpha2FrontDeltaStrips),
            .MinFissionAlpha3Energy: Double(sMinFissionAlpha3Energy),
            .MaxFissionAlpha3Energy: Double(sMaxFissionAlpha3Energy),
            .MinFissionAlpha3BackEnergy: Double(sMinFissionAlpha3BackEnergy),
            .MaxFissionAlpha3BackEnergy: Double(sMaxFissionAlpha3BackEnergy),
            .MinFissionAlpha3Time: Int(sMinFissionAlpha3Time),
            .MaxFissionAlpha3Time: Int(sMaxFissionAlpha3Time),
            .MaxFissionAlpha3FrontDeltaStrips: Int(sMaxFissionAlpha3FrontDeltaStrips),
            .MinFissionAlpha4Energy: Double(sMinFissionAlpha4Energy),
            .MaxFissionAlpha4Energy: Double(sMaxFissionAlpha4Energy),
            .MinFissionAlpha4BackEnergy: Double(sMinFissionAlpha4BackEnergy),
            .MaxFissionAlpha4BackEnergy: Double(sMaxFissionAlpha4BackEnergy),
            .MinFissionAlpha4Time: Int(sMinFissionAlpha4Time),
            .MaxFissionAlpha4Time: Int(sMaxFissionAlpha4Time),
            .MaxFissionAlpha4FrontDeltaStrips: Int(sMaxFissionAlpha4FrontDeltaStrips),
            .MaxConcurrentOperations: maxConcurrentOperationCount,
            .GammaEncodersOnly: gammaEncodersOnly,
            .GammaEncoderIds: gammaEncoderIds,
            .SearchFissionBackByFact: searchFissionBackByFact,
            .SearchFissionBack2ByFact: searchFissionBack2ByFact,
            .SearchFissionBack3ByFact: searchFissionBack3ByFact,
            .SearchFissionBack4ByFact: searchFissionBack4ByFact,
            .SearchRecoilBackByFact: searchRecoilBackByFact,
            .SearchWell: searchWell,
            .SearchRecoils: searchRecoils,
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
