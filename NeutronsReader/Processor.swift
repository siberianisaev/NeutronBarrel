//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import Cocoa

protocol ProcessorDelegate: class {
    
    func incrementProgress(_ delta: Double)
    func startProcessingFile(_ fileName: String)
    
}

enum SearchType: Int {
    case fission
    case alpha
    case recoil
    case heavy
    case veto
    
    func symbol() -> String {
        switch self {
        case .fission:
            return "F"
        case .alpha, .veto:
            return "A"
        case .recoil:
            return "R"
        case .heavy:
            return "H"
        }
    }
    
    func name() -> String {
        switch self {
        case .fission:
            return "Fission"
        case .alpha:
            return "Alpha"
        case .veto:
            return "Veto"
        case .recoil:
            return "Recoil"
        case .heavy:
            return "Heavy Recoil"
        }
    }
}

enum TOFUnits {
    case channels
    case nanoseconds
}

class Processor {
    
    fileprivate let kEncoder = "encoder"
    fileprivate let kStrip0_15 = "strip_0_15"
    fileprivate let kStrip1_N = "strip_1_N"
    fileprivate let kEnergy = "energy"
    fileprivate let kValue = "value"
    fileprivate let kDeltaTime = "delta_time"
    fileprivate let kChannel = "channel"
    fileprivate let kEventNumber = "event_number"
    fileprivate let kMarker = "marker"
    fileprivate let kHeavy = "heavy"
    
    fileprivate var file: UnsafeMutablePointer<FILE>!
    fileprivate var dataProtocol: DataProtocol!
    fileprivate var stripsConfiguration = StripsConfiguration()
    fileprivate var mainCycleTimeEvent = Event()
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var startEventTime: CUnsignedLongLong = 0
    fileprivate var neutronsSummPerAct: CUnsignedLongLong = 0
    fileprivate var neutronsBackwardSummPerAct: CUnsignedLongLong = 0
    fileprivate var currentFileName: String?
    fileprivate var neutronsMultiplicityTotal = [Int : Int]()
    fileprivate var recoilsFrontPerAct = [Any]()
    fileprivate var recoilsBackPerAct = [Any]()
    fileprivate var alpha2FrontPerAct = [Any]()
    fileprivate var tofRealPerAct = [Any]()
    fileprivate var vetoPerAct = [Any]()
    fileprivate var fissionsAlphaFrontPerAct = [Any]()
    fileprivate var fissionsAlphaBackPerAct = [Any]()
    fileprivate var fissionsAlphaWelPerAct = [Any]()
    fileprivate var gammaPerAct = [Any]()
    fileprivate var specialPerAct = [Int: CUnsignedShort]()
    fileprivate var beamRelatedValuesPerAct = [Int: Float]()
    fileprivate var firstFissionAlphaInfo: [String: Any]?
    fileprivate var stoped = false
    fileprivate var logger: Logger!
    fileprivate var calibration: Calibration!
    
    var files = [String]()
    var fissionAlphaFrontMinEnergy: Double = 0
    var fissionAlphaFrontMaxEnergy: Double = 0
    var recoilFrontMinEnergy: Double = 0
    var recoilFrontMaxEnergy: Double = 0
    var minTOFValue: Double = 0
    var maxTOFValue: Double = 0
    var recoilMinTime: CUnsignedLongLong = 0
    var recoilMaxTime: CUnsignedLongLong = 0
    var recoilBackMaxTime: CUnsignedLongLong = 0
    var fissionAlphaMaxTime: CUnsignedLongLong = 0
    var maxTOFTime: CUnsignedLongLong = 0
    var maxVETOTime: CUnsignedLongLong = 0
    var maxGammaTime: CUnsignedLongLong = 0
    var maxNeutronTime: CUnsignedLongLong = 0
    var recoilFrontMaxDeltaStrips: Int = 0
    var recoilBackMaxDeltaStrips: Int = 0
    var summarizeFissionsAlphaFront = false
    var requiredFissionAlphaBack = false
    var requiredRecoilBack = false
    var requiredRecoil = false
    var requiredGamma = false
    var requiredTOF = false
    var requiredVETO = false
    var searchVETO = false
    var trackBeamEnergy = false
    var trackBeamCurrent = false
    var trackBeamBackground = false
    var trackBeamIntegral = false
    var searchNeutrons = false
    var searchAlpha2 = false
    var alpha2MinEnergy: Double = 0
    var alpha2MaxEnergy: Double = 0
    var alpha2MinTime: CUnsignedLongLong = 0
    var alpha2MaxTime: CUnsignedLongLong = 0
    var alpha2MaxDeltaStrips: Int = 0
    var searchSpecialEvents = false
    var specialEventIds = [Int]()
    var startParticleType: SearchType = .fission
    var unitsTOF: TOFUnits = .channels
    var recoilType: SearchType = .recoil
    fileprivate var heavyType: SearchType {
        return recoilType == .recoil ? .heavy : .recoil
    }
    
    weak var delegate: ProcessorDelegate!
    
    class var singleton : Processor {
        struct Static {
            static let sharedInstance : Processor = Processor()
        }
        return Static.sharedInstance
    }
    
    init() {
        calibration = Calibration()
    }
    
    func stop() {
        stoped = true
    }
    
    func processDataWithCompletion(_ completion: @escaping (()->())) {
        stoped = false
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            self?.processData()
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    func selectDataWithCompletion(_ completion: @escaping ((Bool)->())) {
        DataLoader.load { [weak self] (files: [String], dataProtocol: DataProtocol) in
            self?.files = files
            self?.dataProtocol = dataProtocol
            completion(files.count > 0)
        }
    }
    
    func selectCalibrationWithCompletion(_ completion: @escaping ((Bool)->())) {
        Calibration.openCalibration { [weak self] (calibration: Calibration?) in
            self?.calibration = calibration!
            completion(true)
        }
    }
    
    func selectStripsConfigurationWithCompletion(_ completion: @escaping ((Bool)->())) {
        StripsConfiguration.openConfiguration { [weak self] (configuration: StripsConfiguration?) in
            self?.stripsConfiguration = configuration!
            completion(configuration!.loaded)
        }
    }
    
    // MARK: - Algorithms
    
    enum SearchDirection {
        case forward, backward
    }
    
    @objc func forwardSearch(checker: @escaping ((Event, UnsafeMutablePointer<Bool>)->())) {
        while feof(file) != 1 {
            var event = Event()
            fread(&event, eventSize, 1, file)
            
            var stop: Bool = false
            checker(event, &stop)
            if stop {
                return
            }
        }
    }
    
    func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((Event, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: search over many files
        if directions.contains(.backward) {
            var initial = fpos_t()
            fgetpos(file, &initial)
            
            var cycleEvent = mainCycleTimeEvent
            var current = Int(initial)
            while current > -1 {
                current -= eventSize
                fseek(file, current, SEEK_SET)
                
                var event = Event()
                fread(&event, eventSize, 1, file)
                
                let id = Int(event.eventId)
                if id == dataProtocol.CycleTime {
                    cycleEvent = event
                    continue
                }
                
                if dataProtocol.isValidEventIdForTimeCheck(id) {
                    let relativeTime = event.param1
                    let time = useCycleTime ? absTime(relativeTime, cycleEvent: cycleEvent) : CUnsignedLongLong(relativeTime)
                    let deltaTime = (time < startTime) ? (startTime - time) : (time - startTime)
                    if deltaTime <= maxDeltaTime {
                        if deltaTime < minDeltaTime {
                            continue
                        }
                        
                        var stop: Bool = false
                        checker(event, time, -(CLongLong)(deltaTime), &stop)
                        if stop {
                            return
                        }
                    } else {
                        break
                    }
                }
            }
            
            fseek(file, Int(initial), SEEK_SET)
        }
        
        if directions.contains(.forward) {
            var cycleEvent = mainCycleTimeEvent
            while feof(file) != 1 {
                var event = Event()
                fread(&event, eventSize, 1, file)
                
                let id = Int(event.eventId)
                if id == dataProtocol.CycleTime {
                    if updateCycleEvent {
                        mainCycleTimeEvent = event
                    }
                    cycleEvent = event
                    continue
                }
                
                if dataProtocol.isValidEventIdForTimeCheck(id) {
                    let relativeTime = event.param1
                    let time = useCycleTime ? absTime(relativeTime, cycleEvent: cycleEvent) : CUnsignedLongLong(relativeTime)
                    let deltaTime = (time < startTime) ? (startTime - time) : (time - startTime)
                    if deltaTime <= maxDeltaTime {
                        if deltaTime < minDeltaTime {
                            continue
                        }
                        
                        var stop: Bool = false
                        checker(event, time, CLongLong(deltaTime), &stop)
                        if stop {
                            return
                        }
                    } else {
                        return
                    }
                }
            }
        }
    }
    
    // MARK: - Search
    
    func showNoDataAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Please select some data files to start analysis!"
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    func processData() {
        if 0 == files.count {
            showNoDataAlert()
            return
        }
        
        neutronsMultiplicityTotal = [:]
        totalEventNumber = 0
        clearActInfo()
        
        logger = Logger()
        logInput()
        logCalibration()
        logResultsHeader()
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate.incrementProgress(Double.ulpOfOne) // Show progress indicator
        }
        let progressForOneFile: Double = 100.0 / Double(files.count)
        
        for fp in files {
            let path = fp as NSString
            autoreleasepool {
                file = fopen(path.utf8String, "rb")
                let name = path.lastPathComponent
                currentFileName = name
                DispatchQueue.main.async { [weak self] in
                    self?.delegate.startProcessingFile(name)
                }
                
                if let file = file {
                    setvbuf(file, nil, _IONBF, 0) // disable buffering
                    forwardSearch(checker: { [weak self] (event: Event, stop: UnsafeMutablePointer<Bool>) in
                        autoreleasepool {
                            if let file = self?.file, let currentFileName = self?.currentFileName, let stoped = self?.stoped {
                                if ferror(file) != 0 {
                                    print("\nError while reading file \(currentFileName)\n")
                                    exit(-1)
                                }
                                if stoped {
                                    stop.initialize(to: true)
                                }
                            }
                            self?.mainCycleEventCheck(event)
                        }
                    })
                } else {
                    exit(-1)
                }
                
                totalEventNumber += calculateTotalEventNumberForFile(file)
                fclose(file)
                
                DispatchQueue.main.async { [weak self] in
                    self?.delegate.incrementProgress(progressForOneFile)
                }
            }
        }
        
        if searchNeutrons {
            logger.logMultiplicity(neutronsMultiplicityTotal)
        }
    }
    
    func calculateTotalEventNumberForFile(_ file: UnsafeMutablePointer<FILE>!) -> CUnsignedLongLong {
        fseek(file, 0, SEEK_END)
        var lastNumber = fpos_t()
        fgetpos(file, &lastNumber)
        return CUnsignedLongLong(lastNumber)/CUnsignedLongLong(eventSize)
    }
    
    func mainCycleEventCheck(_ event: Event) {
        if Int(event.eventId) == dataProtocol.CycleTime {
            mainCycleTimeEvent = event
        }
        
        if isFront(event, type: startParticleType) {
            startEventTime = UInt64(event.param1)
            
            let isRecoilSearch = startParticleType == recoilType
            if isRecoilSearch {
                if !validateRecoil(event, deltaTime: 0) {
                    return
                }
            } else { // FFron or AFron
                let energy = getEnergy(event, type: startParticleType)
                if energy < fissionAlphaFrontMinEnergy || energy > fissionAlphaFrontMaxEnergy {
                    return
                }
                storeFissionAlphaFront(event, isFirst: true, deltaTime: 0)
            }
            
            var position = fpos_t()
            fgetpos(file, &position)
            
            if searchVETO {
                findVETO()
                fseek(file, Int(position), SEEK_SET)
                if requiredVETO && 0 == vetoPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            if searchAlpha2 {
                findAlpha2()
                fseek(file, Int(position), SEEK_SET)
                if 0 == alpha2FrontPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            findGamma()
            fseek(file, Int(position), SEEK_SET)
            if requiredGamma && 0 == gammaPerAct.count {
                clearActInfo()
                return
            }
            
            if !isRecoilSearch {
                findFissionsAlphaBack()
                fseek(file, Int(position), SEEK_SET)
                if requiredFissionAlphaBack && 0 == fissionsAlphaBackPerAct.count {
                    clearActInfo()
                    return
                }
                
                // Search them only after search all FBack/ABack
                findRecoil()
                fseek(file, Int(position), SEEK_SET)
                if requiredRecoil && 0 == recoilsFrontPerAct.count {
                    clearActInfo()
                    return
                }
                
                findFissionsAlphaWel()
                fseek(file, Int(position), SEEK_SET)
            }
            
            if searchNeutrons {
                findNeutrons()
                fseek(file, Int(position), SEEK_SET)
                findNeutronsBack()
                fseek(file, Int(position), SEEK_SET)
            }
            
            if searchSpecialEvents {
                findSpecialEvents()
                fseek(file, Int(position), SEEK_SET)
            }
            
            findBeamEvents()
            fseek(file, Int(position), SEEK_SET)
            
            // Important: this search must be last because we don't do file repositioning here
            // Summ(FFron or AFron)
            if !isRecoilSearch && summarizeFissionsAlphaFront {
                findNextFissionsAlphaFront()
            }
            
            if searchNeutrons {
                updateNeutronsMultiplicity()
            }
            
            logActResults()
            clearActInfo()
        }
    }
    
    func findFissionsAlphaWel() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFissionOrAlphaWel(event) {
                self.storeFissionAlphaWell(event)
            }
        }
    }
    
    func findNeutrons() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: maxNeutronTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.Neutrons == Int(event.eventId) {
                self.neutronsSummPerAct += 1
            }
        }
    }
    
    func findNeutronsBack() {
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: 10, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.Neutrons == Int(event.eventId) {
                self.neutronsBackwardSummPerAct += 1
            }
        }
    }
    
    func findNextFissionsAlphaFront() {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: true) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.isFront(event, type: self.startParticleType) && self.isFissionStripNearToFirstFissionFront(event) {
                self.storeFissionAlphaFront(event, isFirst: false, deltaTime: deltaTime)
            }
        }
    }
    
    func findVETO() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: maxVETOTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isVETOEvent(event) {
                self.storeVETO(event, deltaTime: deltaTime)
            }
        }
    }
    
    func findGamma() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: maxGammaTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isGammaEvent(event) {
                self.storeGamma(event, deltaTime: deltaTime)
            }
        }
    }
    
    func findFissionsAlphaBack() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let type = self.startParticleType
            if self.isBack(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if energy >= self.fissionAlphaFrontMinEnergy && energy <= self.fissionAlphaFrontMaxEnergy {
                    self.storeFissionAlphaRecoilBack(event, deltaTime: deltaTime)
                }
            }
        }
        
        if fissionsAlphaBackPerAct.count > 1 {
            let dict = fissionsAlphaBackPerAct.sorted(by: { (obj1: Any, obj2: Any) -> Bool in
                func energy(_ o: Any) -> Double {
                    if let e = (o as! [String: Any])[kEnergy] {
                        return e as! Double
                    }
                    return 0
                }
                return energy(obj1) > energy(obj2)
            }).first as? [String: Any]
            if let dict = dict, let encoder = dict[kEncoder], let strip0_15 = dict[kStrip0_15] {
                let strip1_N = stripConvertToFormat_1_N(strip0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort, side: .back)
                let array = (fissionsAlphaBackPerAct as [Any]).filter( { (obj: Any) -> Bool in
                    let item = obj as! [String: Any]
                    if NSDictionary(dictionary: item).isEqual(to: dict) {
                        return true
                    }
                    let e = item[kEncoder] as! CUnsignedShort
                    let s0_15 = item[kStrip0_15] as! CUnsignedShort
                    let s1_N = self.stripConvertToFormat_1_N(s0_15, encoder: e, side: .back)
                    // TODO: new input field for _fissionBackMaxDeltaStrips
                    return abs(Int32(strip1_N) - Int32(s1_N)) <= Int32(recoilBackMaxDeltaStrips)
                })
                fissionsAlphaBackPerAct = array
            }
        }
    }
    
    func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(startEventTime), cycleEvent:mainCycleTimeEvent)
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: recoilMinTime, maxDeltaTime: recoilMaxTime, useCycleTime: true, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let isRecoil = self.isFront(event, type: self.recoilType)
            if isRecoil {
                let isNear = self.isEventFrontStripNearToFirstFissionAlphaFront(event, maxDelta: Int(self.recoilFrontMaxDeltaStrips))
                if isNear {
                    self.validateRecoil(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    @discardableResult fileprivate func validateRecoil(_ event: Event, deltaTime: CLongLong) -> Bool {
        let energy = self.getEnergy(event, type: recoilType)
        if energy >= self.recoilFrontMinEnergy && energy <= self.recoilFrontMaxEnergy {
            var position = fpos_t()
            fgetpos(self.file, &position)
            let t = CUnsignedLongLong(event.param1)
            
            let isRecoilBackFounded = self.findRecoilBack(t)
            fseek(self.file, Int(position), SEEK_SET)
            if isRecoilBackFounded {
                if self.startParticleType == recoilType {
                    self.storeFissionAlphaRecoilBack(event, deltaTime: deltaTime)
                }
            } else if (self.requiredRecoilBack) {
                return false
            }
            
            let isTOFFounded = self.findTOFForRecoil(event, timeRecoil: t)
            fseek(self.file, Int(position), SEEK_SET)
            if (self.requiredTOF && !isTOFFounded) {
                return false
            }
            
            let heavy = self.getEnergy(event, type: heavyType)
            self.storeRecoil(event, energy: energy, heavy: heavy, deltaTime: deltaTime)
            return true
        }
        return false
    }
    
    func findTOFForRecoil(_ eventRecoil: Event, timeRecoil: CUnsignedLongLong) -> Bool {
        var found: Bool = false
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: timeRecoil, minDeltaTime: 0, maxDeltaTime: maxTOFTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.TOF == Int(event.eventId) {
                let value = self.valueTOF(event, eventRecoil: eventRecoil)
                if value >= self.minTOFValue && value <= self.maxTOFValue {
                    self.storeRealTOFValue(value, deltaTime: deltaTime)
                    found = true
                    stop.initialize(to: true)
                }
            }
        }
        return found
    }
    
    func findRecoilBack(_ timeRecoilFront: CUnsignedLongLong) -> Bool {
        var found: Bool = false
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: recoilBackMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isBack(event, type: self.recoilType) {
                if (self.requiredRecoilBack && self.startParticleType != self.recoilType) {
                    found = self.isRecoilBackStripNearToFissionAlphaBack(event)
                } else {
                    found = true
                }
                stop.initialize(to: true)
            }
        }
        return found
    }
    
    func findSpecialEvents() {
        var setIds = Set<Int>(specialEventIds)
        if setIds.count == 0 {
            return
        }
        
        forwardSearch { (event: Event, stop: UnsafeMutablePointer<Bool>) in
            let id = Int(event.eventId)
            if setIds.contains(id) {
                self.storeSpecial(event, id: id)
                setIds.remove(id)
            }
            if setIds.count == 0 {
                stop.initialize(to: true)
            }
        }
    }
    
    func findBeamEvents() {
        var setIds = Set<Int>()
        if trackBeamEnergy {
            setIds.insert(dataProtocol.BeamEnergy)
        }
        if trackBeamCurrent {
            setIds.insert(dataProtocol.BeamCurrent)
        }
        if trackBeamBackground {
            setIds.insert(dataProtocol.BeamBackground)
        }
        if trackBeamIntegral {
            setIds.insert(dataProtocol.BeamIntegral)
        }
        if setIds.count == 0 {
            return
        }
        
        forwardSearch { (event: Event, stop: UnsafeMutablePointer<Bool>) in
            let id = Int(event.eventId)
            if setIds.contains(id) {
                self.storeBeamRelated(event)
                setIds.remove(id)
            }
            if setIds.count == 0 {
                stop.initialize(to: true)
            }
        }
    }
    
    func findAlpha2() {
        let alphaTime = absTime(CUnsignedShort(startEventTime), cycleEvent: mainCycleTimeEvent)
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: alphaTime, minDeltaTime: alpha2MinTime, maxDeltaTime: alpha2MaxTime, useCycleTime: true, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: .alpha) {
                let energy = self.getEnergy(event, type: .alpha)
                if energy >= self.alpha2MinEnergy && energy <= self.alpha2MaxEnergy && self.isEventFrontStripNearToFirstFissionAlphaFront(event, maxDelta: Int(self.alpha2MaxDeltaStrips)) {
                    self.storeAlpha2(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    // MARK: - Storage
    
    func storeFissionAlphaRecoilBack(_ event: Event, deltaTime: CLongLong) {
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: startParticleType)
        let info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kEventNumber: eventNumber(),
                    kDeltaTime: deltaTime,
                    kMarker: getMarker(event)] as [String : Any]
        if isRecoil(event) {
            recoilsBackPerAct.append(info)
        } else {
            fissionsAlphaBackPerAct.append(info)
        }
    }
    
    /**
     Summar multiplicity of neutrons calculation over all files
     */
    func updateNeutronsMultiplicity() {
        let key = neutronsSummPerAct
        var summ = neutronsMultiplicityTotal[Int(key)] ?? 0
        summ += 1 // One event for all neutrons in one act of fission
        neutronsMultiplicityTotal[Int(key)] = summ
    }
    
    func storeFissionAlphaFront(_ event: Event, isFirst: Bool, deltaTime: CLongLong) {
        let channel = getChannel(event, type: startParticleType)
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: startParticleType)
        let info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kChannel: channel,
                    kEnergy: energy,
                    kEventNumber: eventNumber(),
                    kDeltaTime: deltaTime,
                    kMarker: getMarker(event)] as [String : Any]
        fissionsAlphaFrontPerAct.append(info)
        
        if isFirst {
            let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId: event.eventId)
            var extraInfo = info
            extraInfo[kStrip1_N] = strip_1_N
            firstFissionAlphaInfo = extraInfo
        }
    }
    
    func storeGamma(_ event: Event, deltaTime: CLongLong) {
        let channel = event.param3 & Mask.gamma.rawValue
        let energy = calibration.calibratedValueForAmplitude(Double(channel), eventName: "Gam1") // TODO: Gam2, Gam
        let info = [kEnergy: energy,
                    kDeltaTime: deltaTime] as [String : Any]
        gammaPerAct.append(info)
    }
    
    func storeRecoil(_ event: Event, energy: Double, heavy: Double, deltaTime: CLongLong) {
        let info = [kDeltaTime: deltaTime,
                    kEventNumber: eventNumber(),
                    kMarker: getMarker(event),
                    kEnergy: energy,
                    kHeavy: heavy] as [String : Any]
        recoilsFrontPerAct.append(info)
    }
    
    func storeAlpha2(_ event: Event, deltaTime: CLongLong) {
        let energy = getEnergy(event, type: .alpha)
        let info = [kEnergy: energy,
                    kDeltaTime: deltaTime,
                    kEventNumber: eventNumber(),
                    kMarker: getMarker(event)] as [String : Any]
        alpha2FrontPerAct.append(info)
    }
    
    func storeRealTOFValue(_ value: Double, deltaTime: CLongLong) {
        let info = [kValue: value,
                    kDeltaTime: deltaTime] as [String : Any]
        tofRealPerAct.append(info)
    }
    
    func storeVETO(_ event: Event, deltaTime: CLongLong) {
        let strip_0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: .veto)
        let info = [kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kEventNumber: eventNumber(),
                    kDeltaTime: deltaTime] as [String : Any]
        vetoPerAct.append(info)
    }
    
    func storeFissionAlphaWell(_ event: Event) {
        let energy = getEnergy(event, type: startParticleType)
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12
        let info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kMarker: getMarker(event)] as [String : Any]
        fissionsAlphaWelPerAct.append(info)
    }
    
    func storeSpecial(_ event: Event, id: Int) {
        let channel = event.param3 & Mask.special.rawValue
        specialPerAct[id] = channel
    }
    
    func storeBeamRelated(_ event: Event) {
        let value = getFloatValueFrom(event: event)
        beamRelatedValuesPerAct[Int(event.eventId)] = value
    }
    
    func clearActInfo() {
        neutronsSummPerAct = 0
        neutronsBackwardSummPerAct = 0
        fissionsAlphaFrontPerAct.removeAll()
        fissionsAlphaBackPerAct.removeAll()
        gammaPerAct.removeAll()
        specialPerAct.removeAll()
        beamRelatedValuesPerAct.removeAll()
        fissionsAlphaWelPerAct.removeAll()
        recoilsFrontPerAct.removeAll()
        recoilsBackPerAct.removeAll()
        alpha2FrontPerAct.removeAll()
        tofRealPerAct.removeAll()
        vetoPerAct.removeAll()
        firstFissionAlphaInfo = nil
    }
    
    // MARK: - Helpers
    
    fileprivate func getFloatValueFrom(event: Event) -> Float {
        let hi = event.param3
        let lo = event.param2
        let word = (UInt32(hi) << 16) + UInt32(lo)
        let value = Float(bitPattern: word)
        return value
    }
    
    let eventSize: Int = MemoryLayout<Event>.size
    var eventWords: Int {
        return Processor.singleton.eventSize / MemoryLayout<CUnsignedShort>.size
    }
    
    func fissionAlphaBackWithMaxEnergyInAct() -> [String: Any]? {
        var fission: [String: Any]?
        var maxE: Double = 0
        for info in fissionsAlphaBackPerAct {
            if let dict = info as? [String: Any], let n = dict[kEnergy] {
                let e = n as! Double
                if (maxE < e) {
                    maxE = e
                    fission = dict
                }
            }
        }
        return fission
    }
    
    func isEventFrontStripNearToFirstFissionAlphaFront(_ event: Event, maxDelta: Int) -> Bool {
        let strip_0_15 = event.param2 >> 12
        let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId:event.eventId)
        if let n = firstFissionAlphaInfo?[kStrip1_N] {
            let s = CUnsignedShort(n as! Int)
            return abs(Int32(strip_1_N) - Int32(s)) <= Int32(maxDelta)
        }
        return false
    }
    
    func isRecoilBackStripNearToFissionAlphaBack(_ event: Event) -> Bool {
        if let fissionBackInfo = fissionAlphaBackWithMaxEnergyInAct() {
            let strip_0_15 = event.param2 >> 12
            let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId:event.eventId)
            let strip_0_15_back_fission = fissionBackInfo[kStrip0_15] as! CUnsignedShort
            let encoder_back_fission = fissionBackInfo[kEncoder] as! CUnsignedShort
            let strip_1_N_back_fission = stripConvertToFormat_1_N(strip_0_15_back_fission, encoder: encoder_back_fission, side: .back)
            return abs(Int32(strip_1_N) - Int32(strip_1_N_back_fission)) <= Int32(recoilBackMaxDeltaStrips)
        } else {
            return false
        }
    }
    
    /**
     +/-1 strips check at this moment.
     */
    func isFissionStripNearToFirstFissionFront(_ event: Event) -> Bool {
        let strip_0_15 = event.param2 >> 12
        if let n = firstFissionAlphaInfo?[kStrip0_15] {
            let s = n as! CUnsignedShort
            if strip_0_15 == s {
                return true
            }
            
            let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId: event.eventId)
            if let n = firstFissionAlphaInfo?[kStrip1_N] {
                let s = CUnsignedShort(n as! Int)
                return Int(abs(Int32(strip_1_N) - Int32(s))) <= 1
            }
        }
        return false
    }
    
    /**
     Time stored in events are relative time (timer from 0x0000 to xFFFF mks resettable on overflow).
     We use special event 'dataProtocol.CycleTime' to calculate time from file start.
     */
    func absTime(_ relativeTime: CUnsignedShort, cycleEvent: Event) -> CUnsignedLongLong {
        return (CUnsignedLongLong(cycleEvent.param3) << 16) + CUnsignedLongLong(cycleEvent.param1) + CUnsignedLongLong(relativeTime)
    }
    
    func focalStripConvertToFormat_1_N(_ strip_0_15: CUnsignedShort, eventId: CUnsignedShort) -> Int {
        let encoder = dataProtocol.encoderForEventId(Int(eventId))
        return stripConvertToFormat_1_N(strip_0_15, encoder: encoder, side: .front)
    }
    
    func stripConvertToFormat_1_N(_ strip_0_15: CUnsignedShort, encoder: CUnsignedShort, side: StripsSide) -> Int {
        return stripsConfiguration.strip_1_N_For(side: side, encoder: Int(encoder), strip_0_15: strip_0_15)
    }
    
    func getMarker(_ event: Event) -> CUnsignedShort {
        return event.param3 >> 13
    }
    
    /**
     First bit from param3 used to separate recoil and fission/alpha events:
     0 - fission fragment,
     1 - recoil
     */
    func isRecoil(_ event: Event) -> Bool {
        return (event.param3 >> 15) == 1
    }
    
    func isGammaEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.isGammaEvent(eventId)
    }
    
    func isVETOEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.AVeto == eventId
    }
    
    func isFront(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == recoilType
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && dataProtocol.isAlphaFronEvent(eventId)
    }
    
    func isFissionOrAlphaWel(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return !isRecoil(event) && dataProtocol.isAlphaWelEvent(eventId)
    }
    
    func isBack(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == recoilType
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && dataProtocol.isAlphaBackEvent(eventId)
    }
    
    func eventNumber() -> CUnsignedLongLong {
        var position = fpos_t()
        fgetpos(file, &position)
        let value = CUnsignedLongLong(position/Int64(eventSize)) + totalEventNumber + 1
        return value
    }
    
    func channelForTOF(_ event :Event) -> CUnsignedShort {
        return event.param3 & Mask.TOF.rawValue
    }
    
    fileprivate func getChannel(_ event: Event, type: SearchType) -> CUnsignedShort {
        return (type == .fission || type == .heavy) ? (event.param2 & Mask.heavyOrFission.rawValue) : (event.param3 & Mask.recoilOrAlpha.rawValue)
    }
    
    fileprivate func getEnergy(_ event: Event, type: SearchType) -> Double {
        let channel = getChannel(event, type: type)
        let eventId = Int(event.eventId)
        let strip_0_15 = event.param2 >> 12
        let encoder = dataProtocol.encoderForEventId(eventId)
        let position = dataProtocol.position(eventId)
        var name = type.symbol() + position
        if encoder != 0 {
            name += "\(encoder)."
        }
        name += String(strip_0_15+1)
        
        return calibration.calibratedValueForAmplitude(Double(channel), eventName: name)
    }
    
    func currentFileEventNumber(_ number: CUnsignedLongLong) -> String {
        return String(format: "%@_%llu", currentFileName ?? "", number)
    }
    
    func nanosecondsForTOFChannel(_ channelTOF: CUnsignedShort, eventRecoil: Event) -> Double {
        let eventId = Int(eventRecoil.eventId)
        let strip_0_15 = eventRecoil.param2 >> 12
        let encoder = dataProtocol.encoderForEventId(eventId)
        var position: String
        if dataProtocol.isAlphaFronEvent(eventId) {
            position = "Fron"
        } else {
            position = "Back"
        }
        let name = String(format: "T%@%d.%d", position, encoder, strip_0_15+1)
        return calibration.calibratedValueForAmplitude(Double(channelTOF), eventName: name)
    }
    
    func valueTOF(_ eventTOF: Event, eventRecoil: Event) -> Double {
        let channel = channelForTOF(eventTOF)
        if unitsTOF == .channels {
            return Double(channel)
        } else {
            return nanosecondsForTOFChannel(channel, eventRecoil: eventRecoil)
        }
    }
    
    // MARK: - Output
    
    func logInput() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let image = appDelegate.window.screenshot()
        logger.logInput(image)
    }
    
    func logCalibration() {
        logger.logCalibration(calibration.stringValue ?? "")
    }
    
    fileprivate var columns = [String]()
    fileprivate var keyColumnRecoilEvent: String {
        let name = recoilType == .recoil ? "Recoil" : "Heavy Recoil"
        return "Event(\(name))"
    }
    fileprivate var keyRecoil: String {
        return  recoilType == .recoil ? "R" : "HR"
    }
    fileprivate var keyColumnRecoilEnergy: String {
        return "E(\(keyRecoil)Fron)"
    }
    fileprivate var keyColumnRecoilFrontMarker: String {
        return "\(keyRecoil)FronMarker"
    }
    fileprivate var keyColumnRecoilDeltaTime: String {
        return "dT(\(keyRecoil)Fron-$Fron)"
    }
    fileprivate var keyRecoilHeavy: String {
        return heavyType == .heavy ? "HR" : "R"
    }
    fileprivate var keyColumnRecoilHeavyEnergy: String {
        return "E(\(keyRecoilHeavy)Fron)"
    }
    fileprivate var keyColumnTof = "TOF"
    fileprivate var keyColumnTofDeltaTime = "dT(TOF-RFron)"
    fileprivate var keyColumnStartEvent = "Event($)"
    fileprivate var keyColumnStartFrontSumm = "Summ($Fron)"
    fileprivate var keyColumnStartFrontEnergy = "$Fron"
    fileprivate var keyColumnStartFrontMarker = "$FronMarker"
    fileprivate var keyColumnStartFrontDeltaTime = "dT($FronFirst-Next)"
    fileprivate var keyColumnStartFrontStrip = "Strip($Fron)"
    fileprivate var keyColumnStartBackEnergy = "$Back"
    fileprivate var keyColumnStartBackMarker = "$BackMarker"
    fileprivate var keyColumnStartBackDeltaTime = "dT($Fron-$Back)"
    fileprivate var keyColumnStartBackStrip = "Strip($Back)"
    fileprivate var keyColumnStartWelSumm = "Summ($Wel)"
    fileprivate var keyColumnStartWelEnergy = "$Wel"
    fileprivate var keyColumnStartWelMarker = "$WelMarker"
    fileprivate var keyColumnStartWelPosition = "$WelPos"
    fileprivate var keyColumnNeutrons = "Neutrons"
    fileprivate var keyColumnNeutronsBackward = "Neutrons(Backward)"
    fileprivate var keyColumnGammaEnergy = "Gamma"
    fileprivate var keyColumnGammaDeltaTime = "dT($Fron-Gamma)"
    fileprivate var keyColumnSpecial = "Special"
    fileprivate func keyColumnSpecialFor(eventId: Int) -> String {
        return keyColumnSpecial + String(eventId)
    }
    fileprivate var keyColumnBeamEnergy = "BeamEnergy"
    fileprivate var keyColumnBeamCurrent = "BeamCurrent"
    fileprivate var keyColumnBeamBackground = "BeamBackground"
    fileprivate var keyColumnBeamIntegral = "BeamIntegral"
    fileprivate var keyColumnVetoEvent = "Event(VETO)"
    fileprivate var keyColumnVetoEnergy = "E(VETO)"
    fileprivate var keyColumnVetoStrip = "Strip(VETO)"
    fileprivate var keyColumnVetoDeltaTime = "dT($Fron-VETO)"
    fileprivate var keyColumnAlpha2Event = "Event(Alpha2)"
    fileprivate var keyColumnAlpha2Energy = "E(Alpha2)"
    fileprivate var keyColumnAlpha2Marker = "Alpha2Marker"
    fileprivate var keyColumnAlpha2DeltaTime = "dT(Alpha1-Alpha2)"
    
    func logResultsHeader() {
        columns = [
            keyColumnRecoilEvent,
            keyColumnRecoilEnergy,
            keyColumnRecoilHeavyEnergy,
            keyColumnRecoilFrontMarker,
            keyColumnRecoilDeltaTime,
            keyColumnTof,
            keyColumnTofDeltaTime,
            keyColumnStartEvent,
            keyColumnStartFrontSumm,
            keyColumnStartFrontEnergy,
            keyColumnStartFrontMarker,
            keyColumnStartFrontDeltaTime,
            keyColumnStartFrontStrip,
            keyColumnStartBackEnergy,
            keyColumnStartBackMarker,
            keyColumnStartBackDeltaTime,
            keyColumnStartBackStrip,
            keyColumnStartWelSumm,
            keyColumnStartWelEnergy,
            keyColumnStartWelMarker,
            keyColumnStartWelPosition
        ]
        if searchNeutrons {
            columns.append(contentsOf: [
                keyColumnNeutrons,
                keyColumnNeutronsBackward
                ])
        }
        columns.append(contentsOf: [
            keyColumnGammaEnergy,
            keyColumnGammaDeltaTime
            ])
        if searchSpecialEvents {
            let values = specialEventIds.map({ (i: Int) -> String in
                return keyColumnSpecialFor(eventId: i)
            })
            columns.append(contentsOf: values)
        }
        if trackBeamEnergy {
            columns.append(keyColumnBeamEnergy)
        }
        if trackBeamCurrent {
            columns.append(keyColumnBeamCurrent)
        }
        if trackBeamBackground {
            columns.append(keyColumnBeamBackground)
        }
        if trackBeamIntegral {
            columns.append(keyColumnBeamIntegral)
        }
        if searchVETO {
            columns.append(contentsOf: [
                keyColumnVetoEvent,
                keyColumnVetoEnergy,
                keyColumnVetoStrip,
                keyColumnVetoDeltaTime
                ])
        }
        if searchAlpha2 {
            columns.append(contentsOf: [
                keyColumnAlpha2Event,
                keyColumnAlpha2Energy,
                keyColumnAlpha2Marker,
                keyColumnAlpha2DeltaTime
                ])
        }
        
        let symbol = startParticleType.symbol()
        let headers = columns.map { (s: String) -> String in
            return s.replacingOccurrences(of: "$", with: symbol)
            } as [AnyObject]
        logger.writeLineOfFields(headers)
        logger.finishLine() // +1 line padding
    }
    
    func logActResults() {
        let rowsMax = max(1, [gammaPerAct, fissionsAlphaWelPerAct, recoilsFrontPerAct, fissionsAlphaBackPerAct, fissionsAlphaFrontPerAct, vetoPerAct, recoilsBackPerAct].max(by: { $0.count < $1.count })!.count)
        for row in 0 ..< rowsMax {
            for column in columns {
                var field = ""
                switch column {
                case keyColumnRecoilEvent:
                    if row < recoilsFrontPerAct.count {
                        if let eventNumberObject = getValueFrom(array: recoilsFrontPerAct, row: row, key: kEventNumber) {
                            field = currentFileEventNumber(eventNumberObject as! CUnsignedLongLong)
                        }
                    }
                case keyColumnRecoilEnergy:
                    if row < recoilsFrontPerAct.count {
                        if let recoilEnergy = getValueFrom(array: recoilsFrontPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", recoilEnergy as! Double)
                        }
                    }
                case keyColumnRecoilHeavyEnergy:
                    if row < recoilsFrontPerAct.count {
                        if let recoilHeavy = getValueFrom(array: recoilsFrontPerAct, row: row, key: kHeavy) {
                            field = String(format: "%.7f", recoilHeavy as! Double)
                        }
                    }
                case keyColumnRecoilFrontMarker:
                    if row < recoilsFrontPerAct.count {
                        if let marker = getValueFrom(array: recoilsFrontPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case keyColumnRecoilDeltaTime:
                    if row < recoilsFrontPerAct.count {
                        if let deltaTimeRecoilFission = getValueFrom(array: recoilsFrontPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTimeRecoilFission as! CLongLong)
                        }
                    }
                case keyColumnTof:
                    if row < tofRealPerAct.count {
                        if let tof = getValueFrom(array: tofRealPerAct, row: row, key: kValue) {
                            let format = "%." + (unitsTOF == .channels ? "0" : "7") + "f"
                            field = String(format: format, tof as! Double)
                        }
                    }
                case keyColumnTofDeltaTime:
                    if row < tofRealPerAct.count {
                        if let deltaTimeTOFRecoil = getValueFrom(array: tofRealPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTimeTOFRecoil as! CLongLong)
                        }
                    }
                case keyColumnStartEvent:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let eventNumber = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kEventNumber) {
                            field = currentFileEventNumber(eventNumber as! CUnsignedLongLong)
                        }
                    }
                case keyColumnStartFrontSumm:
                    if row == 0 && startParticleType != recoilType {
                        if let summ = getSummEnergyFrom(fissionsAlphaFrontPerAct) {
                            field = String(format: "%.7f", summ)
                        }
                    }
                case keyColumnStartFrontEnergy:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let energy = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case keyColumnStartFrontMarker:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let marker = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case keyColumnStartFrontDeltaTime:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let deltaTime = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case keyColumnStartFrontStrip:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let info = fissionsAlphaFrontPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                            let strip = stripConvertToFormat_1_N(strip_0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort, side: .front)
                            field = String(format: "%d", strip)
                        }
                    }
                case keyColumnStartBackEnergy:
                    let array = startParticleType == recoilType ? recoilsBackPerAct : fissionsAlphaBackPerAct
                    if row < array.count {
                        if let energy = getValueFrom(array: array, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case keyColumnStartBackMarker:
                    let array = startParticleType == recoilType ? recoilsBackPerAct : fissionsAlphaBackPerAct
                    if row < array.count {
                        if let marker = getValueFrom(array: array, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case keyColumnStartBackDeltaTime:
                    let array = startParticleType == recoilType ? recoilsBackPerAct : fissionsAlphaBackPerAct
                    if row < array.count {
                        if let deltaTime = getValueFrom(array: array, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case keyColumnStartBackStrip:
                    let array = startParticleType == recoilType ? recoilsBackPerAct : fissionsAlphaBackPerAct
                    if row < array.count {
                        if let info = array[row] as? [String: Any], let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                            let strip = stripConvertToFormat_1_N(strip_0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort, side: .back)
                            field = String(format: "%d", strip)
                        }
                    }
                case keyColumnStartWelSumm:
                    if row == 0 && startParticleType != recoilType {
                        if let summ = getSummEnergyFrom(fissionsAlphaWelPerAct) {
                            field = String(format: "%.7f", summ)
                        }
                    }
                case keyColumnStartWelEnergy:
                    if row < fissionsAlphaWelPerAct.count {
                        if let energy = getValueFrom(array: fissionsAlphaWelPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case keyColumnStartWelMarker:
                    if row < fissionsAlphaWelPerAct.count {
                        if let marker = getValueFrom(array: fissionsAlphaWelPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case keyColumnStartWelPosition:
                    if row < fissionsAlphaWelPerAct.count {
                        if let info = fissionsAlphaWelPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                            field = String(format: "FWel%d.%d", encoder as! CUnsignedShort, (strip_0_15  as! CUnsignedShort) + 1)
                        }
                    }
                case keyColumnNeutrons:
                    if row == 0 {
                        field = String(format: "%llu", neutronsSummPerAct)
                    }
                case keyColumnNeutronsBackward:
                    if row == 0 {
                        field = String(format: "%llu", neutronsBackwardSummPerAct)
                    }
                case keyColumnGammaEnergy:
                    if row < gammaPerAct.count {
                        if let energy = getValueFrom(array: gammaPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case keyColumnGammaDeltaTime:
                    if row < gammaPerAct.count {
                        if let deltaTime = getValueFrom(array: gammaPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case _ where column.hasPrefix(keyColumnSpecial):
                    if row == 0 {
                        if let eventId = Int(column.replacingOccurrences(of: keyColumnSpecial, with: "")), let v = specialPerAct[eventId] {
                            field = String(format: "%hu", v)
                        }
                    }
                case keyColumnBeamEnergy:
                    if row == 0 {
                        if let f = beamRelatedValuesPerAct[dataProtocol.BeamEnergy] {
                            field = String(format: "%.1f", f)
                        }
                    }
                case keyColumnBeamCurrent:
                    if row == 0 {
                        if let f = beamRelatedValuesPerAct[dataProtocol.BeamCurrent] {
                            field = String(format: "%.2f", f)
                        }
                    }
                case keyColumnBeamBackground:
                    if row == 0 {
                        if let f = beamRelatedValuesPerAct[dataProtocol.BeamBackground] {
                            field = String(format: "%.1f", f)
                        }
                    }
                case keyColumnBeamIntegral:
                    if row == 0 {
                        if let f = beamRelatedValuesPerAct[dataProtocol.BeamIntegral] {
                            field = String(format: "%.1f", f)
                        }
                    }
                case keyColumnVetoEvent:
                    if row < vetoPerAct.count {
                        if let eventNumber = getValueFrom(array: vetoPerAct, row: row, key: kEventNumber) {
                            field = currentFileEventNumber(eventNumber as! CUnsignedLongLong)
                        }
                    }
                case keyColumnAlpha2Event:
                    field = alpha2EventNumber(row)
                case keyColumnVetoEnergy:
                    if row < vetoPerAct.count {
                        if let energy = getValueFrom(array: vetoPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case keyColumnAlpha2Energy:
                    field = alpha2Energy(row)
                case keyColumnVetoStrip:
                    if row < vetoPerAct.count {
                        if let strip_0_15 = getValueFrom(array: vetoPerAct, row: row, key: kStrip0_15) {
                            field = String(format: "%hu", (strip_0_15 as! CUnsignedShort) + 1)
                        }
                    }
                case keyColumnAlpha2Marker:
                    field = alpha2Marker(row)
                case keyColumnVetoDeltaTime:
                    if row < vetoPerAct.count {
                        if let deltaTime = getValueFrom(array: vetoPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case keyColumnAlpha2DeltaTime:
                    field = alphs2DeltaTime(row)
                default:
                    break
                }
                logger.writeField(field as AnyObject)
            }
            logger.finishLine()
        }
    }
    
    fileprivate func getSummEnergyFrom(_ array: [Any]) -> Double? {
        if array.count == 0 {
            return nil
        }
        
        var summ: Double = 0
        for info in array {
            if let energy = (info as? [String: Any])?[kEnergy] {
                summ += energy as! Double
            }
        }
        return summ
    }
    
    fileprivate func getValueFrom(array: [Any], row: Int, key: String) -> Any? {
        return (array[row] as? [String: Any])?[key]
    }
    
    fileprivate func alpha2EventNumber(_ row: Int) -> String {
        if row < alpha2FrontPerAct.count {
            if let eventNumber = getValueFrom(array: alpha2FrontPerAct, row: row, key: kEventNumber) {
                return currentFileEventNumber(eventNumber as! CUnsignedLongLong)
            }
        }
        return ""
    }
    
    fileprivate func alpha2Energy(_ row: Int) -> String {
        if row < alpha2FrontPerAct.count {
            if let energy = getValueFrom(array: alpha2FrontPerAct, row: row, key: kEnergy) {
                return String(format: "%.7f", energy as! Double)
            }
        }
        return ""
    }
    
    fileprivate func alpha2Marker(_ row: Int) -> String {
        if row < alpha2FrontPerAct.count {
            if let marker = getValueFrom(array: alpha2FrontPerAct, row: row, key: kMarker) {
                return String(format: "%hu", marker as! CUnsignedShort)
            }
        }
        return ""
    }
    
    fileprivate func alphs2DeltaTime(_ row: Int) -> String {
        if row < alpha2FrontPerAct.count {
            if let deltaTime = getValueFrom(array: alpha2FrontPerAct, row: row, key: kDeltaTime) {
                return String(format: "%lld", deltaTime as! CLongLong)
            }
        }
        return ""
    }
    
}
