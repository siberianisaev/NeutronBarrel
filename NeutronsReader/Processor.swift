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
    case fission = 0
    case alpha = 1
    case recoil = 2
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
    let kEnergy = "energy"
    fileprivate let kValue = "value"
    fileprivate let kDeltaTime = "delta_time"
    fileprivate let kChannel = "channel"
    fileprivate let kEventNumber = "event_number"
    fileprivate let kMarker = "marker"
    fileprivate let kHeavy = "heavy"
    
    fileprivate var file: UnsafeMutablePointer<FILE>!
    fileprivate var dataProtocol: DataProtocol!
    fileprivate var stripsConfiguration = StripsConfiguration()
    fileprivate var currentCycle: CUnsignedLongLong = 0
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var startEventTime: CUnsignedLongLong = 0
    fileprivate var neutronsSummPerAct: CUnsignedLongLong = 0
    fileprivate var neutronsBackwardSummPerAct: CUnsignedLongLong = 0
    fileprivate var currentFileName: String?
    fileprivate var neutronsMultiplicityTotal = [Int: Int]()
    fileprivate var specialPerAct = [Int: CUnsignedShort]()
    fileprivate var beamRelatedValuesPerAct = [Int: Float]()
    
    fileprivate var fissionsAlphaPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var recoilsPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var fissionsAlpha2FrontPerAct = DetectorMatch()
    fileprivate var fissionsAlphaWellPerAct = DetectorMatch()
    fileprivate var tofRealPerAct = DetectorMatch()
    fileprivate var vetoPerAct = DetectorMatch()
    fileprivate var gammaPerAct = DetectorMatch()
    
    fileprivate var stoped = false
    fileprivate var logger: Logger!
    fileprivate var calibration = Calibration()
    
    var files = [String]()
    var criteria = SearchCriteria()
    weak var delegate: ProcessorDelegate?
    
    class var singleton : Processor {
        struct Static {
            static let sharedInstance : Processor = Processor()
        }
        return Static.sharedInstance
    }
    
    func stop() {
        stoped = true
    }
    
    func processDataWith(aDelegate: ProcessorDelegate, completion: @escaping (()->())) {
        delegate = aDelegate
        stoped = false
        processData()
        DispatchQueue.main.async {
            completion()
        }
    }
    
    func selectDataWithCompletion(_ completion: @escaping ((Bool)->())) {
        DataLoader.load { [weak self] (files: [String], dataProtocol: DataProtocol) in
            self?.files = files
            self?.dataProtocol = dataProtocol
            completion(files.count > 0)
        }
    }
    
    func selectCalibrationWithCompletion(_ completion: @escaping ((Bool, String?)->())) {
        Calibration.openCalibration { [weak self] (calibration: Calibration?, filePath: String?) in
            self?.calibration = calibration ?? Calibration()
            completion(calibration != nil, filePath)
        }
    }
    
    func removeCalibration() {
        calibration = Calibration()
    }
    
    func selectStripsConfigurationWithCompletion(_ completion: @escaping ((Bool, String?)->())) {
        StripsConfiguration.openConfiguration { [weak self] (configuration: StripsConfiguration?, filePath: String?) in
            self?.stripsConfiguration = configuration!
            completion(configuration!.loaded, filePath)
        }
    }
    
    func removeStripsConfiguration() {
        stripsConfiguration = StripsConfiguration()
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
    
    func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, maxDeltaTimeBackward: CUnsignedLongLong? = nil, useCycleTime: Bool, updateCycle: Bool, checker: @escaping ((Event, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: search over many files
        let maxBackward = maxDeltaTimeBackward ?? maxDeltaTime
        if directions.contains(.backward) {
            var initial = fpos_t()
            fgetpos(file, &initial)
            
            var cycle = currentCycle
            var current = Int(initial)
            while current > -1 {
                current -= eventSize
                fseek(file, current, SEEK_SET)
                
                var event = Event()
                fread(&event, eventSize, 1, file)
                
                let id = Int(event.eventId)
                if dataProtocol.isCycleTimeEvent(id) {
                    if cycle > 0 {
                        cycle -= 1
                    } else {
                        print("Backward search time broken!")
                    }
                    continue
                }
                
                if dataProtocol.isValidEventIdForTimeCheck(id) {
                    let relativeTime = event.param1
                    let time = useCycleTime ? absTime(relativeTime, cycle: cycle) : CUnsignedLongLong(relativeTime)
                    let deltaTime = (time < startTime) ? (startTime - time) : (time - startTime)
                    if deltaTime <= maxBackward {
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
            var cycle = currentCycle
            while feof(file) != 1 {
                var event = Event()
                fread(&event, eventSize, 1, file)
                
                let id = Int(event.eventId)
                if dataProtocol.isCycleTimeEvent(id) {
                    if updateCycle {
                        currentCycle += 1
                    }
                    cycle += 1
                    continue
                }
                
                if dataProtocol.isValidEventIdForTimeCheck(id) {
                    let relativeTime = event.param1
                    let time = useCycleTime ? absTime(relativeTime, cycle: cycle) : CUnsignedLongLong(relativeTime)
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
        
        logger = Logger(folder: criteria.resultsFolderName)
        logInput(onEnd: false)
        logCalibration()
        logResultsHeader()
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.incrementProgress(Double.ulpOfOne) // Show progress indicator
        }
        let progressForOneFile: Double = 100.0 / Double(files.count)
        
        var folders = [String: FolderStatistics]()
        
        for fp in files {
            let path = fp as NSString
            let folderName = FolderStatistics.folderNameFromPath(fp) ?? ""
            var folder = folders[folderName]
            if nil == folder {
                folder = FolderStatistics(folderName: folderName)
                folders[folderName] = folder
            }
            folder!.startFile(fp)
            
            autoreleasepool {
                file = fopen(path.utf8String, "rb")
                let name = path.lastPathComponent
                currentFileName = name
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.startProcessingFile(name)
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
                            self?.mainCycleEventCheck(event, folder: folder!)
                        }
                    })
                } else {
                    exit(-1)
                }
                
                totalEventNumber += calculateTotalEventNumberForFile(file)
                fclose(file)
                folder!.endFile(fp, secondsFromFirstFileStart: TimeInterval(absTime(0, cycle: currentCycle)) * 1e-6)
                
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.incrementProgress(progressForOneFile)
                }
            }
        }
        
        logInput(onEnd: true)
        logger.logStatistics(folders)
        if criteria.searchNeutrons {
            logger.logMultiplicity(neutronsMultiplicityTotal)
        }
        
        print("\nDone!\nTotal time took: \((NSApplication.shared.delegate as! AppDelegate).timeTook())")
    }
    
    func calculateTotalEventNumberForFile(_ file: UnsafeMutablePointer<FILE>!) -> CUnsignedLongLong {
        fseek(file, 0, SEEK_END)
        var lastNumber = fpos_t()
        fgetpos(file, &lastNumber)
        return CUnsignedLongLong(lastNumber)/CUnsignedLongLong(eventSize)
    }
    
    func mainCycleEventCheck(_ event: Event, folder: FolderStatistics) {
        if dataProtocol.isCycleTimeEvent(Int(event.eventId)) {
            currentCycle += 1
        } else if isFront(event, type: criteria.startParticleType) {
            startEventTime = UInt64(event.param1)
            
            let isRecoilSearch = criteria.startParticleType == criteria.recoilType
            if isRecoilSearch {
                if !validateRecoil(event, deltaTime: 0) {
                    return
                }
            } else { // FFron or AFron
                let energy = getEnergy(event, type: criteria.startParticleType)
                if energy < criteria.fissionAlphaFrontMinEnergy || energy > criteria.fissionAlphaFrontMaxEnergy {
                    return
                }
                storeFissionAlphaFront(event, deltaTime: 0)
            }
            
            var position = fpos_t()
            fgetpos(file, &position)
            
            if criteria.searchVETO {
                findVETO()
                fseek(file, Int(position), SEEK_SET)
                if criteria.requiredVETO && 0 == vetoPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            if criteria.searchFissionAlpha2 {
                findFissionAlpha2()
                fseek(file, Int(position), SEEK_SET)
                if 0 == fissionsAlpha2FrontPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            findGamma()
            fseek(file, Int(position), SEEK_SET)
            if criteria.requiredGamma && 0 == gammaPerAct.count {
                clearActInfo()
                return
            }
            
            if !isRecoilSearch {
                findFissionsAlphaBack()
                fseek(file, Int(position), SEEK_SET)
                if criteria.requiredFissionAlphaBack && 0 == fissionsAlphaPerAct.matchFor(side: .back).count {
                    clearActInfo()
                    return
                }
                
                // Search them only after search all FBack/ABack
                findRecoil()
                fseek(file, Int(position), SEEK_SET)
                if criteria.requiredRecoil && 0 == recoilsPerAct.matchFor(side: .front).count {
                    clearActInfo()
                    return
                }
                
                if criteria.searchWell {
                    findFissionsAlphaWell()
                    fseek(file, Int(position), SEEK_SET)
                }
            }
            
            if criteria.searchNeutrons {
                findNeutrons()
                fseek(file, Int(position), SEEK_SET)
                findNeutronsBack()
                fseek(file, Int(position), SEEK_SET)
            }
            
            if criteria.searchSpecialEvents {
                findSpecialEvents()
                fseek(file, Int(position), SEEK_SET)
            }
            
            findBeamEvents()
            fseek(file, Int(position), SEEK_SET)
            
            // Important: this search must be last because we don't do file repositioning here
            // Summ(FFron or AFron)
            if !isRecoilSearch && criteria.summarizeFissionsAlphaFront {
                findNextFissionsAlphaFront(folder)
            }
            
            if criteria.searchNeutrons {
                updateNeutronsMultiplicity()
            }
            
            logActResults()
            clearActInfo()
        } else {
            updateFolderStatistics(event, folder: folder)
        }
    }
    
    fileprivate func updateFolderStatistics(_ event: Event, folder: FolderStatistics) {
        let id = Int(event.eventId)
        if id == dataProtocol.BeamEnergy {
            let e = getFloatValueFrom(event: event)
            if e >= criteria.beamEnergyMin && e <= criteria.beamEnergyMax {
                folder.handleEnergy(e)
            }
        } else if id == dataProtocol.BeamIntegral {
            folder.handleIntergal(event)
        }
    }
    
    func findFissionsAlphaWell() {
        let directions: Set<SearchDirection> = [.backward, .forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFissionOrAlphaWell(event) {
                self.storeFissionAlphaWell(event)
            }
        }
    }
    
    func findNeutrons() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxNeutronTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.isNeutronsEvent(Int(event.eventId)) {
                self.neutronsSummPerAct += 1
            }
        }
    }
    
    func findNeutronsBack() {
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: 10, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.isNeutronsEvent(Int(event.eventId)) {
                self.neutronsBackwardSummPerAct += 1
            }
        }
    }
    
    func findNextFissionsAlphaFront(_ folder: FolderStatistics) {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, useCycleTime: false, updateCycle: true) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.isFront(event, type: self.criteria.startParticleType) && self.isFissionStripNearToFirstFissionFront(event) {
                self.storeFissionAlphaFront(event, deltaTime: deltaTime)
            } else {
                self.updateFolderStatistics(event, folder: folder)
            }
        }
    }
    
    func findVETO() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxVETOTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.isVETOEvent(Int(event.eventId)) {
                self.storeVETO(event, deltaTime: deltaTime)
            }
        }
    }
    
    func findGamma() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxGammaTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isGammaEvent(event) {
                self.storeGamma(event, deltaTime: deltaTime)
            }
        }
    }
    
    func findFissionsAlphaBack() {
        let directions: Set<SearchDirection> = [.backward, .forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let type = self.criteria.startParticleType
            if self.isBack(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if self.criteria.searchFissionAlphaBackByFact || (energy >= self.criteria.fissionAlphaFrontMinEnergy && energy <= self.criteria.fissionAlphaFrontMaxEnergy) {
                    self.storeFissionAlphaRecoilBack(event, deltaTime: deltaTime)
                }
            }
        }
        
        // TODO: move filtration logic to DetectorMatch, and remove accessors for 'items'.
        let side: StripsSide = .back
        let match = fissionsAlphaPerAct.matchFor(side: side)
        if let dict = match.itemWithMaxEnergy(), let encoder = dict[kEncoder], let strip0_15 = dict[kStrip0_15] {
            let strip1_N = stripConvertToFormat_1_N(strip0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort, side: side)
            let array = (match.getItems() as [Any]).filter( { (obj: Any) -> Bool in
                let item = obj as! [String: Any]
                if NSDictionary(dictionary: item).isEqual(to: dict) {
                    return true
                }
                let e = item[kEncoder] as! CUnsignedShort
                let s0_15 = item[kStrip0_15] as! CUnsignedShort
                let s1_N = self.stripConvertToFormat_1_N(s0_15, encoder: e, side: side)
                // TODO: new input field for _fissionBackMaxDeltaStrips
                return abs(Int32(strip1_N) - Int32(s1_N)) <= Int32(criteria.recoilBackMaxDeltaStrips)
            })
            match.setItems(array as! [[String : Any]])
        }
    }
    
    func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(startEventTime), cycle: currentCycle)
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: criteria.recoilMinTime, maxDeltaTime: criteria.recoilMaxTime, useCycleTime: true, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let isRecoil = self.isFront(event, type: self.criteria.recoilType)
            if isRecoil {
                let isNear = self.isEventFrontStripNearToFirstFissionAlphaFront(event, maxDelta: Int(self.criteria.recoilFrontMaxDeltaStrips))
                if isNear {
                    self.validateRecoil(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    @discardableResult fileprivate func validateRecoil(_ event: Event, deltaTime: CLongLong) -> Bool {
        let energy = self.getEnergy(event, type: criteria.recoilType)
        if energy >= criteria.recoilFrontMinEnergy && energy <= criteria.recoilFrontMaxEnergy {
            var position = fpos_t()
            fgetpos(self.file, &position)
            let t = CUnsignedLongLong(event.param1)
            
            let isRecoilBackFounded = self.findRecoilBack(t)
            fseek(self.file, Int(position), SEEK_SET)
            if isRecoilBackFounded {
                if criteria.startParticleType == criteria.recoilType {
                    self.storeFissionAlphaRecoilBack(event, deltaTime: deltaTime)
                }
            } else if (criteria.requiredRecoilBack) {
                return false
            }
            
            let isTOFFounded = self.findTOFForRecoil(event, timeRecoil: t)
            fseek(self.file, Int(position), SEEK_SET)
            if (criteria.requiredTOF && !isTOFFounded) {
                return false
            }
            
            let heavy = self.getEnergy(event, type: criteria.heavyType)
            self.storeRecoil(event, energy: energy, heavy: heavy, deltaTime: deltaTime)
            return true
        }
        return false
    }
    
    func findTOFForRecoil(_ eventRecoil: Event, timeRecoil: CUnsignedLongLong) -> Bool {
        var found: Bool = false
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: timeRecoil, minDeltaTime: 0, maxDeltaTime: criteria.maxTOFTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.isTOFEvent(Int(event.eventId)) {
                let value = self.valueTOF(event, eventRecoil: eventRecoil)
                if value >= self.criteria.minTOFValue && value <= self.criteria.maxTOFValue {
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
        let directions: Set<SearchDirection> = [.backward, .forward]
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: criteria.recoilBackMaxTime, maxDeltaTimeBackward: criteria.recoilBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isBack(event, type: self.criteria.recoilType) {
                if (self.criteria.requiredRecoilBack && self.criteria.startParticleType != self.criteria.recoilType) {
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
        var setIds = Set<Int>(criteria.specialEventIds)
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
        if criteria.trackBeamEnergy, let id = dataProtocol.BeamEnergy {
            setIds.insert(id)
        }
        if criteria.trackBeamCurrent, let id = dataProtocol.BeamCurrent {
            setIds.insert(id)
        }
        if criteria.trackBeamBackground, let id = dataProtocol.BeamBackground {
            setIds.insert(id)
        }
        if criteria.trackBeamIntegral, let id = dataProtocol.BeamIntegral {
            setIds.insert(id)
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
    
    func findFissionAlpha2() {
        let alphaTime = absTime(CUnsignedShort(startEventTime), cycle: currentCycle)
        let directions: Set<SearchDirection> = [.backward, .forward]
        search(directions: directions, startTime: alphaTime, minDeltaTime: criteria.fissionAlpha2MinTime, maxDeltaTime: criteria.fissionAlpha2MaxTime, useCycleTime: true, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let type = self.criteria.secondParticleType
            if self.isFront(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if energy >= self.criteria.fissionAlpha2MinEnergy && energy <= self.criteria.fissionAlpha2MaxEnergy && self.isEventFrontStripNearToFirstFissionAlphaFront(event, maxDelta: Int(self.criteria.fissionAlpha2MaxDeltaStrips)) {
                    self.storeFissionAlpha2(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    // MARK: - Storage
    
    func storeFissionAlphaRecoilBack(_ event: Event, deltaTime: CLongLong) {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip_0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: criteria.startParticleType)
        var info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kEventNumber: eventNumber(),
                    kDeltaTime: deltaTime,
                    kMarker: getMarker(event)] as [String : Any]
        let side: StripsSide = .back
        if isRecoil(event) {
            recoilsPerAct.append(info, side: side)
        } else {
            if fissionsAlphaPerAct.matchFor(side: side).count == 0 {
                info[kStrip1_N] = focalStripConvertToFormat_1_N(strip_0_15, eventId: id)
            }
            fissionsAlphaPerAct.append(info, side: side)
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
    
    func storeFissionAlphaFront(_ event: Event, deltaTime: CLongLong) {
        let id = event.eventId
        let channel = getChannel(event, type: criteria.startParticleType)
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip_0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: criteria.startParticleType)
        var info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kChannel: channel,
                    kEnergy: energy,
                    kEventNumber: eventNumber(),
                    kDeltaTime: deltaTime,
                    kMarker: getMarker(event)] as [String : Any]
        let side: StripsSide = .front
        if fissionsAlphaPerAct.matchFor(side: side).count == 0 {
            info[kStrip1_N] = focalStripConvertToFormat_1_N(strip_0_15, eventId: id)
        }
        fissionsAlphaPerAct.append(info, side: side)
    }
    
    func storeGamma(_ event: Event, deltaTime: CLongLong) {
        let channel = event.param3 & Mask.gamma.rawValue
        let eventId = Int(event.eventId)
        let encoder = dataProtocol.encoderForEventId(eventId)
        let position = dataProtocol.position(eventId)
        let name = "\(position)\(encoder)"
        let energy = calibration.calibratedValueForAmplitude(Double(channel), eventName: name)
        let info = [kEnergy: energy,
                    kEncoder: encoder,
                    kDeltaTime: deltaTime] as [String : Any]
        gammaPerAct.append(info)
    }
    
    func storeRecoil(_ event: Event, energy: Double, heavy: Double, deltaTime: CLongLong) {
        let info = [kDeltaTime: deltaTime,
                    kEventNumber: eventNumber(),
                    kMarker: getMarker(event),
                    kEnergy: energy,
                    kHeavy: heavy] as [String : Any]
        recoilsPerAct.append(info, side: .front)
    }
    
    func storeFissionAlpha2(_ event: Event, deltaTime: CLongLong) {
        let energy = getEnergy(event, type: criteria.secondParticleType)
        let info = [kEnergy: energy,
                    kDeltaTime: deltaTime,
                    kEventNumber: eventNumber(),
                    kMarker: getMarker(event)] as [String : Any]
        fissionsAlpha2FrontPerAct.append(info)
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
        let energy = getEnergy(event, type: criteria.startParticleType)
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12
        let info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kMarker: getMarker(event)] as [String : Any]
        fissionsAlphaWellPerAct.append(info)
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
        fissionsAlphaPerAct.removeAll()
        gammaPerAct.removeAll()
        specialPerAct.removeAll()
        beamRelatedValuesPerAct.removeAll()
        fissionsAlphaWellPerAct.removeAll()
        recoilsPerAct.removeAll()
        fissionsAlpha2FrontPerAct.removeAll()
        tofRealPerAct.removeAll()
        vetoPerAct.removeAll()
    }
    
    // MARK: - Helpers
    
    func getFloatValueFrom(event: Event) -> Float {
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
    
    func isEventFrontStripNearToFirstFissionAlphaFront(_ event: Event, maxDelta: Int) -> Bool {
        let strip_0_15 = event.param2 >> 12
        let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId:event.eventId)
        if let n = fissionsAlphaPerAct.firstItemsFor(side: .front)?[kStrip1_N] {
            let s = CUnsignedShort(n as! Int)
            return abs(Int32(strip_1_N) - Int32(s)) <= Int32(maxDelta)
        }
        return false
    }
    
    func isRecoilBackStripNearToFissionAlphaBack(_ event: Event) -> Bool {
        if let fissionBackInfo = fissionsAlphaPerAct.matchFor(side: .back).itemWithMaxEnergy() {
            let strip_0_15 = event.param2 >> 12
            let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId:event.eventId)
            let strip_0_15_back_fission = fissionBackInfo[kStrip0_15] as! CUnsignedShort
            let encoder_back_fission = fissionBackInfo[kEncoder] as! CUnsignedShort
            let strip_1_N_back_fission = stripConvertToFormat_1_N(strip_0_15_back_fission, encoder: encoder_back_fission, side: .back)
            return abs(Int32(strip_1_N) - Int32(strip_1_N_back_fission)) <= Int32(criteria.recoilBackMaxDeltaStrips)
        } else {
            return false
        }
    }
    
    /**
     +/-1 strips check at this moment.
     */
    func isFissionStripNearToFirstFissionFront(_ event: Event) -> Bool {
        let strip_0_15 = event.param2 >> 12
        if let first = fissionsAlphaPerAct.firstItemsFor(side: .front), let n = first[kStrip0_15] {
            let s = n as! CUnsignedShort
            if strip_0_15 == s {
                return true
            }
            
            let strip_1_N = focalStripConvertToFormat_1_N(strip_0_15, eventId: event.eventId)
            if let n = first[kStrip1_N] {
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
    func absTime(_ relativeTime: CUnsignedShort, cycle: CUnsignedLongLong) -> CUnsignedLongLong {
        return (cycle << 16) + CUnsignedLongLong(relativeTime)
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
    
    func isFront(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == criteria.recoilType
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && dataProtocol.isAlphaFronEvent(eventId)
    }
    
    func isFissionOrAlphaWell(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return !isRecoil(event) && dataProtocol.isAlphaWellEvent(eventId)
    }
    
    func isBack(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == criteria.recoilType
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
        if criteria.unitsTOF == .channels {
            return Double(channel)
        } else {
            return nanosecondsForTOFChannel(channel, eventRecoil: eventRecoil)
        }
    }
    
    // MARK: - Output
    
    func logInput(onEnd: Bool) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let image = appDelegate.window.screenshot()
        logger.logInput(image, onEnd: onEnd)
    }
    
    func logCalibration() {
        logger.logCalibration(calibration.stringValue ?? "")
    }
    
    fileprivate var columns = [String]()
    fileprivate var keyColumnRecoilEvent: String {
        let name = criteria.recoilType == .recoil ? "Recoil" : "Heavy Recoil"
        return "Event(\(name))"
    }
    fileprivate var keyRecoil: String {
        return  criteria.recoilType == .recoil ? "R" : "HR"
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
        return criteria.heavyType == .heavy ? "HR" : "R"
    }
    fileprivate var keyColumnRecoilHeavyEnergy: String {
        return "E(\(keyRecoilHeavy)Fron)"
    }
    fileprivate var keyColumnTof = "TOF"
    fileprivate var keyColumnTofDeltaTime = "dT(TOF-RFron)"
    fileprivate var keyColumnStartEvent = "Event($)"
    fileprivate var keyColumnStartFrontSumm = "Summ($Fron)"
    fileprivate var keyColumnStartBackSumm = "Summ($Back)"
    fileprivate var keyColumnStartFrontEnergy = "$Fron"
    fileprivate var keyColumnStartFrontMarker = "$FronMarker"
    fileprivate var keyColumnStartFrontDeltaTime = "dT($FronFirst-Next)"
    fileprivate var keyColumnStartFrontStrip = "Strip($Fron)"
    fileprivate var keyColumnStartBackEnergy = "$Back"
    fileprivate var keyColumnStartBackMarker = "$BackMarker"
    fileprivate var keyColumnStartBackDeltaTime = "dT($Fron-$Back)"
    fileprivate var keyColumnStartBackStrip = "Strip($Back)"
    fileprivate var keyColumnStartWellSumm = "Summ($Well)"
    fileprivate var keyColumnStartWellEnergy = "$Well"
    fileprivate var keyColumnStartWellMarker = "$WellMarker"
    fileprivate var keyColumnStartWellPosition = "$WellPos"
    fileprivate var keyColumnNeutrons = "Neutrons"
    fileprivate var keyColumnNeutronsBackward = "Neutrons(Backward)"
    fileprivate var keyColumnGammaEnergy = "Gamma"
    fileprivate var keyColumnGammaEncoder = "GammaEncoder"
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
    fileprivate var keyColumnFissionAlpha2Event = "Event($2)"
    fileprivate var keyColumnFissionAlpha2Energy = "E($2)"
    fileprivate var keyColumnFissionAlpha2Marker = "$2Marker"
    fileprivate var keyColumnFissionAlpha2DeltaTime = "dT($1-$2)"
    
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
            keyColumnStartBackSumm,
            keyColumnStartBackEnergy,
            keyColumnStartBackMarker,
            keyColumnStartBackDeltaTime,
            keyColumnStartBackStrip
        ]
        if criteria.searchWell {
            columns.append(contentsOf: [
                keyColumnStartWellSumm,
                keyColumnStartWellEnergy,
                keyColumnStartWellMarker,
                keyColumnStartWellPosition
                ])
        }
        if criteria.searchNeutrons {
            columns.append(contentsOf: [
                keyColumnNeutrons,
                keyColumnNeutronsBackward
                ])
        }
        columns.append(contentsOf: [
            keyColumnGammaEnergy,
            keyColumnGammaEncoder,
            keyColumnGammaDeltaTime
            ])
        if criteria.searchSpecialEvents {
            let values = criteria.specialEventIds.map({ (i: Int) -> String in
                return keyColumnSpecialFor(eventId: i)
            })
            columns.append(contentsOf: values)
        }
        if criteria.trackBeamEnergy {
            columns.append(keyColumnBeamEnergy)
        }
        if criteria.trackBeamCurrent {
            columns.append(keyColumnBeamCurrent)
        }
        if criteria.trackBeamBackground {
            columns.append(keyColumnBeamBackground)
        }
        if criteria.trackBeamIntegral {
            columns.append(keyColumnBeamIntegral)
        }
        if criteria.searchVETO {
            columns.append(contentsOf: [
                keyColumnVetoEvent,
                keyColumnVetoEnergy,
                keyColumnVetoStrip,
                keyColumnVetoDeltaTime
                ])
        }
        if criteria.searchFissionAlpha2 {
            columns.append(contentsOf: [
                keyColumnFissionAlpha2Event,
                keyColumnFissionAlpha2Energy,
                keyColumnFissionAlpha2Marker,
                keyColumnFissionAlpha2DeltaTime
                ])
        }
        
        let symbol = criteria.startParticleType.symbol()
        let headers = columns.map { (s: String) -> String in
            return s.replacingOccurrences(of: "$", with: symbol)
            } as [AnyObject]
        logger.writeResultsLineOfFields(headers)
        logger.finishResultsLine() // +1 line padding
    }
    
    func logActResults() {
        let rowsMax = max(max(max(1, [gammaPerAct, vetoPerAct, fissionsAlphaWellPerAct].max(by: { $0.count < $1.count })!.count), fissionsAlphaPerAct.count), recoilsPerAct.count)
        for row in 0 ..< rowsMax {
            for column in columns {
                var field = ""
                switch column {
                case keyColumnRecoilEvent:
                    if let eventNumberObject = recoilsPerAct.matchFor(side: .front).getValueAt(index: row, key: kEventNumber) {
                        field = currentFileEventNumber(eventNumberObject as! CUnsignedLongLong)
                    }
                case keyColumnRecoilEnergy:
                    if let recoilEnergy = recoilsPerAct.matchFor(side: .front).getValueAt(index: row, key: kEnergy) {
                        field = String(format: "%.7f", recoilEnergy as! Double)
                    }
                case keyColumnRecoilHeavyEnergy:
                    if let recoilHeavy = recoilsPerAct.matchFor(side: .front).getValueAt(index: row, key: kHeavy) {
                        field = String(format: "%.7f", recoilHeavy as! Double)
                    }
                case keyColumnRecoilFrontMarker:
                    if let marker = recoilsPerAct.matchFor(side: .front).getValueAt(index: row, key: kMarker) {
                        field = String(format: "%hu", marker as! CUnsignedShort)
                    }
                case keyColumnRecoilDeltaTime:
                    if let deltaTimeRecoilFission = recoilsPerAct.matchFor(side: .front).getValueAt(index: row, key: kDeltaTime) {
                        field = String(format: "%lld", deltaTimeRecoilFission as! CLongLong)
                    }
                case keyColumnTof:
                    if let tof = tofRealPerAct.getValueAt(index: row, key: kValue) {
                        let format = "%." + (criteria.unitsTOF == .channels ? "0" : "7") + "f"
                        field = String(format: format, tof as! Double)
                    }
                case keyColumnTofDeltaTime:
                    if let deltaTimeTOFRecoil = tofRealPerAct.getValueAt(index: row, key: kDeltaTime) {
                        field = String(format: "%lld", deltaTimeTOFRecoil as! CLongLong)
                    }
                case keyColumnStartEvent:
                    if let eventNumber = fissionsAlphaPerAct.matchFor(side: .front).getValueAt(index: row, key: kEventNumber) {
                        field = currentFileEventNumber(eventNumber as! CUnsignedLongLong)
                    }
                case keyColumnStartFrontSumm:
                    if row == 0, criteria.startParticleType != criteria.recoilType, let summ = fissionsAlphaPerAct.matchFor(side: .front).getSummEnergyFrom() {
                        field = String(format: "%.7f", summ)
                    }
                case keyColumnStartFrontEnergy:
                    if let energy = fissionsAlphaPerAct.matchFor(side: .front).getValueAt(index: row, key: kEnergy) {
                        field = String(format: "%.7f", energy as! Double)
                    }
                case keyColumnStartFrontMarker:
                    if let marker = fissionsAlphaPerAct.matchFor(side: .front).getValueAt(index: row, key: kMarker) {
                        field = String(format: "%hu", marker as! CUnsignedShort)
                    }
                case keyColumnStartFrontDeltaTime:
                    if let deltaTime = fissionsAlphaPerAct.matchFor(side: .front).getValueAt(index: row, key: kDeltaTime) {
                        field = String(format: "%lld", deltaTime as! CLongLong)
                    }
                case keyColumnStartFrontStrip:
                    if let info = fissionsAlphaPerAct.matchFor(side: .front).itemAt(index: row), let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                        let strip = stripConvertToFormat_1_N(strip_0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort, side: .front)
                        field = String(format: "%d", strip)
                    }
                case keyColumnStartBackSumm:
                    if row == 0, criteria.startParticleType != criteria.recoilType, let summ = fissionsAlphaPerAct.matchFor(side: .back).getSummEnergyFrom() {
                        field = String(format: "%.7f", summ)
                    }
                case keyColumnStartBackEnergy:
                    let side: StripsSide = .back
                    let match = criteria.startParticleType == criteria.recoilType ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let energy = match.getValueAt(index: row, key: kEnergy) {
                        field = String(format: "%.7f", energy as! Double)
                    }
                case keyColumnStartBackMarker:
                    let side: StripsSide = .back
                    let match = criteria.startParticleType == criteria.recoilType ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let marker = match.getValueAt(index: row, key: kMarker) {
                        field = String(format: "%hu", marker as! CUnsignedShort)
                    }
                case keyColumnStartBackDeltaTime:
                    let side: StripsSide = .back
                    let match = criteria.startParticleType == criteria.recoilType ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let deltaTime = match.getValueAt(index: row, key: kDeltaTime) {
                        field = String(format: "%lld", deltaTime as! CLongLong)
                    }
                case keyColumnStartBackStrip:
                    let side: StripsSide = .back
                    let match = criteria.startParticleType == criteria.recoilType ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let info = match.itemAt(index: row), let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                        let strip = stripConvertToFormat_1_N(strip_0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort, side: .back)
                        field = String(format: "%d", strip)
                    }
                case keyColumnStartWellSumm:
                    if row == 0, criteria.startParticleType != criteria.recoilType, let summ = fissionsAlphaWellPerAct.getSummEnergyFrom() {
                        field = String(format: "%.7f", summ)
                    }
                case keyColumnStartWellEnergy:
                    if let energy = fissionsAlphaWellPerAct.getValueAt(index: row, key: kEnergy) {
                        field = String(format: "%.7f", energy as! Double)
                    }
                case keyColumnStartWellMarker:
                    if let marker = fissionsAlphaWellPerAct.getValueAt(index: row, key: kMarker) {
                        field = String(format: "%hu", marker as! CUnsignedShort)
                    }
                case keyColumnStartWellPosition:
                    if let info = fissionsAlphaWellPerAct.itemAt(index: row), let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                        field = String(format: "FWell%d.%d", encoder as! CUnsignedShort, (strip_0_15  as! CUnsignedShort) + 1)
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
                    if let energy = gammaPerAct.getValueAt(index: row, key: kEnergy) {
                        field = String(format: "%.7f", energy as! Double)
                    }
                case keyColumnGammaEncoder:
                    if let encoder = gammaPerAct.getValueAt(index: row, key: kEncoder) {
                        field = String(format: "%hu", encoder as! CUnsignedShort)
                    }
                case keyColumnGammaDeltaTime:
                    if let deltaTime = gammaPerAct.getValueAt(index: row, key: kDeltaTime) {
                        field = String(format: "%lld", deltaTime as! CLongLong)
                    }
                case _ where column.hasPrefix(keyColumnSpecial):
                    if row == 0 {
                        if let eventId = Int(column.replacingOccurrences(of: keyColumnSpecial, with: "")), let v = specialPerAct[eventId] {
                            field = String(format: "%hu", v)
                        }
                    }
                case keyColumnBeamEnergy:
                    if row == 0 {
                        if let id = dataProtocol.BeamEnergy, let f = beamRelatedValuesPerAct[id] {
                            field = String(format: "%.1f", f)
                        }
                    }
                case keyColumnBeamCurrent:
                    if row == 0 {
                        if let id = dataProtocol.BeamCurrent, let f = beamRelatedValuesPerAct[id] {
                            field = String(format: "%.2f", f)
                        }
                    }
                case keyColumnBeamBackground:
                    if row == 0 {
                        if let id = dataProtocol.BeamBackground, let f = beamRelatedValuesPerAct[id] {
                            field = String(format: "%.1f", f)
                        }
                    }
                case keyColumnBeamIntegral:
                    if row == 0 {
                        if let id = dataProtocol.BeamIntegral, let f = beamRelatedValuesPerAct[id] {
                            field = String(format: "%.1f", f)
                        }
                    }
                case keyColumnVetoEvent:
                    if let eventNumber = vetoPerAct.getValueAt(index: row, key: kEventNumber) {
                        field = currentFileEventNumber(eventNumber as! CUnsignedLongLong)
                    }
                case keyColumnFissionAlpha2Event:
                    field = fissionAlpha2EventNumber(row)
                case keyColumnVetoEnergy:
                    if let energy = vetoPerAct.getValueAt(index: row, key: kEnergy) {
                        field = String(format: "%.7f", energy as! Double)
                    }
                case keyColumnFissionAlpha2Energy:
                    field = fissionAlpha2Energy(row)
                case keyColumnVetoStrip:
                    if let strip_0_15 = vetoPerAct.getValueAt(index: row, key: kStrip0_15) {
                        field = String(format: "%hu", (strip_0_15 as! CUnsignedShort) + 1)
                    }
                case keyColumnFissionAlpha2Marker:
                    field = fissionAlpha2Marker(row)
                case keyColumnVetoDeltaTime:
                    if let deltaTime = vetoPerAct.getValueAt(index: row, key: kDeltaTime) {
                        field = String(format: "%lld", deltaTime as! CLongLong)
                    }
                case keyColumnFissionAlpha2DeltaTime:
                    field = fissionAlphs2DeltaTime(row)
                default:
                    break
                }
                logger.writeResultsField(field as AnyObject)
            }
            logger.finishResultsLine()
        }
    }
    
    fileprivate func fissionAlpha2EventNumber(_ row: Int) -> String {
        if let eventNumber = fissionsAlpha2FrontPerAct.getValueAt(index: row, key: kEventNumber) {
            return currentFileEventNumber(eventNumber as! CUnsignedLongLong)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Energy(_ row: Int) -> String {
        if let energy = fissionsAlpha2FrontPerAct.getValueAt(index: row, key: kEnergy) {
            return String(format: "%.7f", energy as! Double)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Marker(_ row: Int) -> String {
        if let marker = fissionsAlpha2FrontPerAct.getValueAt(index: row, key: kMarker) {
            return String(format: "%hu", marker as! CUnsignedShort)
        }
        return ""
    }
    
    fileprivate func fissionAlphs2DeltaTime(_ row: Int) -> String {
        if let deltaTime = fissionsAlpha2FrontPerAct.getValueAt(index: row, key: kDeltaTime) {
            return String(format: "%lld", deltaTime as! CLongLong)
        }
        return ""
    }
    
}

