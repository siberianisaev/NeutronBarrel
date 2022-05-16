//
//  Processor.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import Cocoa

extension Event {
    
    func getChannelFor(type: SearchType) -> CUnsignedShort {
        return (type == .fission || type == .heavy) ? (param2 & Mask.heavyOrFission.rawValue) : (param3 & Mask.recoilOrAlpha.rawValue)
    }
    
    func getMarker() -> CUnsignedShort {
        return param3 >> 13
    }
    
}

protocol ProcessorDelegate: AnyObject {
    
    func startProcessingFile(_ name: String?)
    func endProcessingFile(_ name: String?, correlationsFound: CUnsignedLongLong)
    
}

enum TOFUnits {
    case channels
    case nanoseconds
}

class Processor {
    
    fileprivate var neutronsPerAct = NeutronsMatch()
    fileprivate var neutronsMultiplicity: NeutronsMultiplicity?
    fileprivate var specialPerAct = [Int: CUnsignedShort]()
    fileprivate var beamStatePerAct = BeamState()
    fileprivate var fissionsAlphaPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var fissionsAlphaNextPerAct = [Int: DoubleSidedStripDetectorMatch]()
    fileprivate var lastFissionAlphaNextPerAct: DoubleSidedStripDetectorMatch? {
        return fissionsAlphaNextPerAct[criteria.nextMaxIndex() ?? -1]
    }
    fileprivate var currentEventTime: CUnsignedLongLong {
        return (criteria.searchExtraFromLastParticle ? lastFissionAlphaNextPerAct : firstParticlePerAct)?.currentEventTime ?? 0
    }
    fileprivate var recoilsPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var firstParticlePerAct: DoubleSidedStripDetectorMatch {
        return criteria.startFromRecoil() ? recoilsPerAct : fissionsAlphaPerAct
    }
    fileprivate var fissionsAlphaWellPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var vetoPerAct = DetectorMatch()
    
    fileprivate var stoped = false
    fileprivate var logger: Logger!
    fileprivate var resultsTable: ResultsTable!
    
    fileprivate var calibration: Calibration {
        return Calibration.singleton
    }
    
    fileprivate func stripsConfiguration(detector: StripDetector) -> StripsConfiguration {
        return StripDetectorManager.singleton.getStripConfigurations(detector)
    }
    
    fileprivate var dataProtocol: DataProtocol! {
        return DataLoader.singleton.dataProtocol
    }
    
    fileprivate var files: [String] {
        return DataLoader.singleton.files
    }
    
    var filesFinishedCount: Int = 0
    fileprivate var file: UnsafeMutablePointer<FILE>!
    fileprivate var currentFileName: String?
    fileprivate var currentCycle: CUnsignedLongLong = 0
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var correlationsPerFile: CUnsignedLongLong = 0
    
    fileprivate var criteria = SearchCriteria()
    fileprivate weak var delegate: ProcessorDelegate?
    
    init(criteria: SearchCriteria, delegate: ProcessorDelegate) {
        self.criteria = criteria
        self.delegate = delegate
    }
    
    func stop() {
        stoped = true
    }
    
    func processDataWith(completion: @escaping (()->())) {
        stoped = false
        processData()
        DispatchQueue.main.async {
            completion()
        }
    }
    
    // MARK: - Algorithms
    
    enum SearchDirection {
        case forward, backward
    }
    
    fileprivate func forwardSearch(checker: @escaping ((Event, UnsafeMutablePointer<Bool>)->())) {
        while feof(file) != 1 {
            var event = Event()
            fread(&event, Event.size, 1, file)
            
            var stop: Bool = false
            checker(event, &stop)
            if stop {
                return
            }
        }
    }
    
    fileprivate func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, maxDeltaTimeBackward: CUnsignedLongLong? = nil, checkMaxDeltaTimeExceeded: Bool = true, useCycleTime: Bool, updateCycle: Bool, checker: @escaping ((Event, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>, Int)->())) {
        //TODO: search over many files
        let maxBackward = maxDeltaTimeBackward ?? maxDeltaTime
        if directions.contains(.backward) {
            var initial = fpos_t()
            fgetpos(file, &initial)
            
            var cycle = currentCycle
            var current = Int(initial)
            while current > -1 {
                let size = Event.size
                current -= size
                fseek(file, current, SEEK_SET)
                
                var event = Event()
                fread(&event, size, 1, file)
                
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
                        checker(event, time, -(CLongLong)(deltaTime), &stop, current)
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
                fread(&event, Event.size, 1, file)
                
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
                    if !checkMaxDeltaTimeExceeded || deltaTime <= maxDeltaTime {
                        if deltaTime < minDeltaTime {
                            continue
                        }
                        
                        var stop: Bool = false
                        var current = fpos_t()
                        fgetpos(file, &current)
                        checker(event, time, CLongLong(deltaTime), &stop, Int(current))
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
    
    fileprivate func showNoDataAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Please select some data files to start analysis!"
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    fileprivate func processData() {
        if 0 == files.count {
            showNoDataAlert()
            return
        }
        
        neutronsMultiplicity = NeutronsMultiplicity(efficiency: criteria.neutronsDetectorEfficiency, efficiencyError: criteria.neutronsDetectorEfficiencyError, placedSFSource: criteria.placedSFSource)
        totalEventNumber = 0
        clearActInfo()
        
        logger = Logger(folder: criteria.resultsFolderName)
        logger.logSettings()
        logInput(onEnd: false)
        logCalibration()
        resultsTable = ResultsTable(criteria: criteria, logger: logger, delegate: self)
        resultsTable.logResultsHeader()
        resultsTable.logGammaHeader()
        
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
                currentFileName = path.lastPathComponent
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.startProcessingFile(self?.currentFileName)
                }
                
                if let file = file {
                    setvbuf(file, nil, _IONBF, 0)
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
                
                totalEventNumber += Processor.calculateTotalEventNumberForFile(file)
                fclose(file)
                folder!.endFile(fp, secondsFromFirstFileStart: TimeInterval(absTime(0, cycle: currentCycle)) * 1e-6)
                
                filesFinishedCount += 1
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.endProcessingFile(self?.currentFileName, correlationsFound: self?.correlationsPerFile ?? 0)
                    self?.correlationsPerFile = 0
                }
            }
        }
        
        logInput(onEnd: true)
        logger.logStatistics(folders)
        if criteria.searchNeutrons, let multiplicity = neutronsMultiplicity {
            logger.log(multiplicity: multiplicity)
        }
        
        DispatchQueue.main.async {
            print("\nDone!\nTotal time took: \((NSApplication.shared.delegate as! AppDelegate).timeTook())")
        }
    }
    
    class func calculateTotalEventNumberForFile(_ file: UnsafeMutablePointer<FILE>!) -> CUnsignedLongLong {
        fseek(file, 0, SEEK_END)
        var lastNumber = fpos_t()
        fgetpos(file, &lastNumber)
        return CUnsignedLongLong(lastNumber)/CUnsignedLongLong(Event.size)
    }
    
    fileprivate var currentPosition: Int {
        var p = fpos_t()
        fgetpos(file, &p)
        let position = Int(p)
        return position
    }
    
    fileprivate func mainCycleEventCheck(_ event: Event, folder: FolderStatistics) {
        if dataProtocol.isCycleTimeEvent(Int(event.eventId)) {
            currentCycle += 1
        } else if isFront(event, type: criteria.startParticleType) {
            firstParticlePerAct.currentEventTime = UInt64(event.param1)
            
            if (criteria.inBeamOnly && !isInBeam(event)) || (criteria.overflowOnly && !isOverflow(event)) {
                clearActInfo()
                return
            }
            
            var gamma: DetectorMatch?
            let isRecoilSearch = criteria.startFromRecoil()
            if isRecoilSearch {
                if !validateRecoil(event, deltaTime: 0) {
                    clearActInfo()
                    return
                }
            } else { // FFron or AFron
                let energy = getEnergy(event, type: criteria.startParticleType)
                if energy < criteria.fissionAlphaFrontMinEnergy || energy > criteria.fissionAlphaFrontMaxEnergy {
                    clearActInfo()
                    return
                }
                
                if !criteria.searchExtraFromLastParticle {
                    gamma = findGamma(currentPosition)
                    if criteria.requiredGamma && nil == gamma {
                        clearActInfo()
                        return
                    }
                }
                
                storeFissionAlphaFront(event, deltaTime: 0, subMatches: [.gamma: gamma])
            }
            
            let position = currentPosition
            
            if criteria.searchVETO {
                findVETO()
                fseek(file, position, SEEK_SET)
                if criteria.requiredVETO && 0 == vetoPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            if !isRecoilSearch {
                findFissionAlphaBack()
                fseek(file, position, SEEK_SET)
                if criteria.requiredFissionAlphaBack && 0 == fissionsAlphaPerAct.matchFor(side: .back).count {
                    clearActInfo()
                    return
                }
                
                // Search them only after search all FBack/ABack
                findRecoil()
                fseek(file, position, SEEK_SET)
                if criteria.requiredRecoil && 0 == recoilsPerAct.matchFor(side: .front).count {
                    clearActInfo()
                    return
                }
                
                if !criteria.searchExtraFromLastParticle {
                    findFissionAlphaWell(position)
                    if wellSearchFailed() {
                        clearActInfo()
                        return
                    }
                }
            }
            
            if criteria.next[2] != nil {
                findFissionAlpha(2)
                fseek(file, position, SEEK_SET)
                guard let match = fissionsAlphaNextPerAct[2], match.matchFor(side: .front).count > 0 else {
                    clearActInfo()
                    return
                }
                
                if criteria.next[3] != nil {
                    findFissionAlpha(3)
                    fseek(file, position, SEEK_SET)
                    guard let match = fissionsAlphaNextPerAct[3], match.matchFor(side: .front).count > 0 else {
                        clearActInfo()
                        return
                    }
                }
                
                if criteria.searchExtraFromLastParticle && wellSearchFailed() {
                    clearActInfo()
                    return
                }
            }
            
            if !criteria.startFromRecoil() && criteria.requiredGammaOrWell && gamma == nil && fissionsAlphaWellPerAct.matchFor(side: .front).count == 0 {
                clearActInfo()
                return
            }
            
            if !criteria.searchExtraFromLastParticle {
                if findNeutrons(position) {
                    clearActInfo()
                    return
                }
            }
            
            if criteria.searchSpecialEvents {
                findSpecialEvents()
                fseek(file, position, SEEK_SET)
            }
            
            if criteria.trackBeamState {
                findBeamEvents()
            }
            fseek(file, position, SEEK_SET)
            
            // Important: this search must be last because we don't do file repositioning here
            // Sum(FFron or AFron)
            if !isRecoilSearch && criteria.summarizeFissionsAlphaFront {
                findAllFirstFissionsAlphaFront(folder)
            }
            
            if criteria.searchNeutrons {
                neutronsMultiplicity?.increment(multiplicity: neutronsPerAct.count)
            }
            
            correlationsPerFile += 1
            resultsTable.logActResults()
            for b in [false, true] {
                resultsTable.logGamma(GeOnly: b)
            }
            clearActInfo()
        } else {
            updateFolderStatistics(event, folder: folder)
        }
    }
    
    fileprivate func wellSearchFailed() -> Bool {
        return criteria.searchWell && criteria.requiredWell && fissionsAlphaWellPerAct.matchFor(side: .front).count == 0
    }
    
    fileprivate func updateFolderStatistics(_ event: Event, folder: FolderStatistics) {
        let id = Int(event.eventId)
        if dataProtocol.isBeamEnergy(id) {
            let e = event.getFloatValue()
            folder.handleEnergy(e)
        } else if dataProtocol.isBeamIntegral(id) {
            folder.handleIntergal(event)
        } else if dataProtocol.isBeamCurrent(id) {
            let c = event.getFloatValue()
            folder.handleCurrent(c)
        }
    }
    
    fileprivate func findFissionAlphaWell(_ position: Int) {
        if criteria.searchWell {
            let directions: Set<SearchDirection> = [.backward, .forward]
            search(directions: directions, startTime: currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                for side in [.front, .back] as [StripsSide] {
                    if self.isFissionOrAlphaWell(event, side: side) {
                        self.filterAndStoreFissionAlphaWell(event, side: side)
                    }
                }
            }
            fseek(file, position, SEEK_SET)
        }
    }
    
    fileprivate func checkIsSimultaneousDecay(_ event: Event, deltaTime: CLongLong) -> Bool {
        if criteria.simultaneousDecaysFilterForNeutrons && isBack(event, type: criteria.startParticleBackType) && abs(deltaTime) > criteria.fissionAlphaMaxTime {
            let energy = getEnergy(event, type: criteria.startParticleBackType)
            if energy >= criteria.fissionAlphaBackMinEnergy && energy <= criteria.fissionAlphaBackMaxEnergy {
                return true
            }
        }
        return false
    }
    
    fileprivate func findNeutrons(_ position: Int) -> Bool {
        var excludeSFEvent: Bool = false
        if criteria.searchNeutrons {
            let directions: Set<SearchDirection> = [.forward, .backward]
            let startTime = currentEventTime
            let maxDeltaTime = criteria.maxNeutronTime
            let checkMaxDeltaTimeExceeded = !criteria.mixingTimesFilterForNeutrons
            search(directions: directions, startTime: startTime, minDeltaTime: criteria.minNeutronTime, maxDeltaTime: maxDeltaTime, maxDeltaTimeBackward: criteria.maxNeutronBackwardTime, checkMaxDeltaTimeExceeded:checkMaxDeltaTimeExceeded, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                let id = Int(event.eventId)
                // 1) Simultaneous Decays Filter - search the events with fragment energy at the same time with current decay.
                if self.checkIsSimultaneousDecay(event, deltaTime: deltaTime) {
                    excludeSFEvent = true
                    self.neutronsMultiplicity?.incrementBroken()
                    stop.initialize(to: true)
                } else if abs(deltaTime) < maxDeltaTime {
                    // 3) Store neutron info.
                    if self.dataProtocol.isNeutronsNewEvent(id) {
                        let neutronTime = CUnsignedLongLong(event.param1)
                        let isNeutronsBkg = self.criteria.neutronsBackground
                        if (!isNeutronsBkg && neutronTime >= startTime) || (isNeutronsBkg && neutronTime < startTime) { // Effect neutrons must be after SF by time
                            self.neutronsPerAct.times.append(Float(deltaTime))
                            var encoder = self.dataProtocol.encoderForEventId(id) // 1-4
                            var channel = event.param3 & Mask.neutronsNew.rawValue // 0-31
                            // Convert to encoder 1-8 and strip 0-15 format
                            self.neutronsPerAct.encoders.append(encoder)
                            encoder *= 2
                            if channel > 15 {
                                channel -= 16
                            } else {
                                encoder -= 1
                            }
                            let counterNumber = self.stripsConfiguration(detector: .neutron).strip1_N_For(side: .front, encoder: Int(encoder), strip0_15: channel)
                            self.neutronsPerAct.counters.append(counterNumber)
                        }
                    } else if self.dataProtocol.isNeutronsOldEvent(id) {
                        let t = Float(event.param3 & Mask.neutronsOld.rawValue)
                        self.neutronsPerAct.times.append(t)
                    }
                    if self.dataProtocol.hasNeutrons_N() && self.dataProtocol.isNeutrons_N_Event(id) {
                        self.neutronsPerAct.NSum += 1
                    }
                } else if !checkMaxDeltaTimeExceeded && !self.dataProtocol.isNeutronsNewEvent(id) {
                    // 2) The Mixing Neutrons Times Filter. We don't check time for neutrons only. It's necessary to stop the search from this checker if delta-time is exceeded for other events.
                    stop.initialize(to: true)
                }
            }
            fseek(file, Int(position), SEEK_SET)
        }
        return excludeSFEvent
    }
    
    fileprivate func findAllFirstFissionsAlphaFront(_ folder: FolderStatistics) {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: firstParticlePerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, useCycleTime: false, updateCycle: true) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.isFront(event, type: self.criteria.startParticleType) && self.isFissionStripNearToFirstFissionFront(event) {
                self.storeFissionAlphaFront(event, deltaTime: deltaTime, subMatches: nil)
            } else {
                self.updateFolderStatistics(event, folder: folder)
            }
        }
    }
    
    fileprivate func findVETO() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: firstParticlePerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxVETOTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.dataProtocol.isVETOEvent(Int(event.eventId)) {
                self.storeVETO(event, deltaTime: deltaTime)
            }
        }
    }
    
    fileprivate func findGamma(_ position: Int) -> DetectorMatch? {
        let match = DetectorMatch()
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxGammaTime, maxDeltaTimeBackward: criteria.maxGammaBackwardTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.isGammaEvent(event), let item = self.gammaMatchItem(event, deltaTime: deltaTime) {
                match.append(item)
            }
        }
        fseek(file, position, SEEK_SET)
        return match.count > 0 ? match : nil
    }
    
    fileprivate func findFissionAlphaBack() {
        let match = fissionsAlphaPerAct
        let type = criteria.startParticleBackType
        let directions: Set<SearchDirection> = [.backward, .forward]
        let byFact = self.criteria.searchFissionAlphaBackByFact
        search(directions: directions, startTime: firstParticlePerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.isBack(event, type: type) {
                var store = byFact
                if !store {
                    let energy = self.getEnergy(event, type: type)
                    store = energy >= self.criteria.fissionAlphaBackMinEnergy && energy <= self.criteria.fissionAlphaBackMaxEnergy
                }
                if store {
                    self.storeFissionAlphaBack(event, match: match, type: type, deltaTime: deltaTime)
                    if byFact { // just stop on first one
                        stop.initialize(to: true)
                    }
                }
            }
        }
        if !criteria.summarizeFissionsAlphaBack {
            match.matchFor(side: .back).filterItemsByMaxEnergy(maxStripsDelta: criteria.recoilBackMaxDeltaStrips)
        }
    }
    
    fileprivate func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(firstParticlePerAct.currentEventTime), cycle: currentCycle)
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: criteria.recoilMinTime, maxDeltaTime: criteria.recoilMaxTime, useCycleTime: true, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            let isRecoil = self.isFront(event, type: self.criteria.recoilType)
            if isRecoil {
                let isNear = self.isEventStripNearToFirstParticle(event, maxDelta: Int(self.criteria.recoilFrontMaxDeltaStrips), side: .front)
                if isNear {
                    let found = self.validateRecoil(event, deltaTime: deltaTime)
                    if found && self.criteria.searchFirstRecoilOnly {
                        stop.initialize(to: true)
                    }
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
            
            let tof = findTOFForRecoil(event, timeRecoil: t, kind: .TOF)
            fseek(self.file, Int(position), SEEK_SET)
            var tof2: DetectorMatchItem? = nil
            if criteria.useTOF2 {
                tof2 = findTOFForRecoil(event, timeRecoil: t, kind: .TOF2)
                fseek(self.file, Int(position), SEEK_SET)
            }
            if (criteria.requiredTOF && !(tof != nil || tof2 != nil)) {
                return false
            }
            
            let found = findRecoilBack(t, position: Int(position))
            if (!found && criteria.requiredRecoilBack) {
                return false
            }
            
            var gamma: DetectorMatch?
            if criteria.startFromRecoil(), !criteria.searchExtraFromLastParticle {
                gamma = findGamma(Int(position))
                if criteria.requiredGamma && nil == gamma {
                    return false
                }
            }
            
            var subMatches: [SearchType : DetectorMatch?] = [:]
            if let gamma = gamma {
                subMatches[.gamma] = gamma
            }
            if let tof = tof {
                subMatches[.tof] = DetectorMatch(items: [tof])
            }
            if let tof2 = tof2 {
                subMatches[.tof2] = DetectorMatch(items: [tof2])
            }
            self.storeRecoil(event, energy: energy, deltaTime: deltaTime, subMatches: subMatches)
            return true
        }
        return false
    }
    
    fileprivate func findTOFForRecoil(_ eventRecoil: Event, timeRecoil: CUnsignedLongLong, kind: TOFKind) -> DetectorMatchItem? {
        let directions: Set<SearchDirection> = [.forward, .backward]
        var match: DetectorMatchItem?
        search(directions: directions, startTime: timeRecoil, minDeltaTime: 0, maxDeltaTime: criteria.maxTOFTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if let k = self.dataProtocol.isTOFEvent(Int(event.eventId)), k == kind {
                let value = self.valueTOF(event, eventRecoil: eventRecoil)
                if value >= self.criteria.minTOFValue && value <= self.criteria.maxTOFValue {
                    match = self.TOFValue(value, deltaTime: deltaTime)
                    stop.initialize(to: true)
                }
            }
        }
        return match
    }
    
    fileprivate func findRecoilBack(_ timeRecoilFront: CUnsignedLongLong, position: Int) -> Bool {
        var items = [DetectorMatchItem]()
        let side: StripsSide = .back
        let directions: Set<SearchDirection> = [.backward, .forward]
        let byFact = self.criteria.searchRecoilBackByFact
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: criteria.recoilBackMaxTime, maxDeltaTimeBackward: criteria.recoilBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            let type: SearchType = self.criteria.recoilBackType
            if self.isBack(event, type: type) {
                var store = self.criteria.startFromRecoil() || self.isRecoilBackStripNearToFissionAlphaBack(event)
                if !byFact && store {
                    let energy = self.getEnergy(event, type: type)
                    store = energy >= self.criteria.recoilBackMinEnergy && energy <= self.criteria.recoilBackMaxEnergy
                }
                if store {
                    let item = self.focalDetectorMatchItemFrom(event, type: type, deltaTime: deltaTime, side: side)
                    items.append(item)
                    if byFact || self.criteria.searchFirstRecoilOnly { // just stop on first one
                        stop.initialize(to: true)
                    }
                }
            }
        }
        fseek(self.file, Int(position), SEEK_SET)
        if let item = DetectorMatch.getItemWithMaxEnergy(items) {
            recoilsPerAct.append(item, side: side)
            return true
        } else {
            return false
        }
    }
    
    fileprivate func findSpecialEvents() {
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
    
    fileprivate func findBeamEvents() {
        forwardSearch { (event: Event, stop: UnsafeMutablePointer<Bool>) in
            if self.beamStatePerAct.handleEvent(event, criteria: self.criteria, dataProtocol: self.dataProtocol!) {
                stop.initialize(to: true)
            }
        }
    }
    
    fileprivate func findFissionAlpha(_ index: Int) {
        guard let c = criteria.next[index] else {
            return
        }
        let startTime = absTime(CUnsignedShort(index == 1 ? firstParticlePerAct.currentEventTime : (fissionsAlphaNextPerAct[index-1]?.currentEventTime ?? 0)), cycle: currentCycle)
        let directions: Set<SearchDirection> = [.forward]
        let isLastNext = criteria.nextMaxIndex() == index
        search(directions: directions, startTime: startTime, minDeltaTime: c.minTime, maxDeltaTime: c.maxTime, useCycleTime: true, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = c.frontType
            let isFront = self.isFront(event, type: t)
            if isFront {
                let st = UInt64(event.param1)
                self.fissionsAlphaNextPerAct[index]?.currentEventTime = st
                let energy = self.getEnergy(event, type: t)
                if self.isEventStripNearToFirstParticle(event, maxDelta: Int(c.maxDeltaStrips), side: .front) && ((!isFront && c.backByFact) || (energy >= c.frontMinEnergy && energy <= c.frontMaxEnergy)) {
                    var store = true
                    var gamma: DetectorMatch?
                    // Back
                    let back = self.findFissionAlphaBack(index, position: position, startTime: st)
                    if self.criteria.requiredFissionAlphaBack && back == nil {
                        store = false
                    } else {
                        // Extra Search
                        if isLastNext, self.criteria.searchExtraFromLastParticle {
                            self.findFissionAlphaWell(position)
                            if self.findNeutrons(position) {
                                store = false
                            }
                            gamma = self.findGamma(position)
                            if nil == gamma, self.criteria.requiredGamma {
                                store = false
                            }
                        }
                    }
                    if store {
                        self.storeFissionAlpha(index, event: event, type: t, deltaTime: deltaTime, subMatches: [.gamma: gamma], back: back)
                    }
                }
            }
        }
    }
    
    fileprivate func findFissionAlphaBack(_ index: Int, position: Int, startTime: CUnsignedLongLong) -> DetectorMatchItem? {
        guard let c = criteria.next[index] else {
            return nil
        }
        
        var items = [DetectorMatchItem]()
        let directions: Set<SearchDirection> = [.forward, .backward]
        let byFact = c.backByFact
        search(directions: directions, startTime: startTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = c.backType
            let isBack = self.isBack(event, type: t)
            if isBack {
                var store = self.isEventStripNearToFirstParticle(event, maxDelta: Int(self.criteria.recoilBackMaxDeltaStrips), side: .back)
                if !byFact && store { // check energy also
                    let energy = self.getEnergy(event, type: t)
                    store = energy >= c.backMinEnergy && energy <= c.backMaxEnergy
                }
                if store {
                    let item = self.focalDetectorMatchItemFrom(event, type: t, deltaTime: deltaTime, side: .back)
                    items.append(item)
                    if byFact { // just stop on first one
                        stop.initialize(to: true)
                    }
                }
            }
        }
        fseek(file, position, SEEK_SET)
        if let item = DetectorMatch.getItemWithMaxEnergy(items) {
            return item
        }
        return nil
    }
    
    // MARK: - Storage
    
    fileprivate func focalDetectorMatchItemFrom(_ event: Event, type: SearchType, deltaTime: CLongLong, side: StripsSide) -> DetectorMatchItem {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: type)
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: event.getMarker(),
                                     side: side)
        return item
    }
    
    fileprivate func storeFissionAlphaBack(_ event: Event, match: DoubleSidedStripDetectorMatch, type: SearchType, deltaTime: CLongLong) {
        let side: StripsSide = .back
        let item = focalDetectorMatchItemFrom(event, type: type, deltaTime: deltaTime, side: side)
        match.append(item, side: side)
    }
    
    fileprivate func storeFissionAlphaFront(_ event: Event, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?) {
        let id = event.eventId
        let type = criteria.startParticleType
        let channel = event.getChannelFor(type: type)
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: type)
        let side: StripsSide = .front
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: event.getMarker(),
                                     channel: channel,
                                     subMatches: subMatches,
                                     side: side)
        fissionsAlphaPerAct.append(item, side: side)
    }
    
    fileprivate func gammaMatchItem(_ event: Event, deltaTime: CLongLong) -> DetectorMatchItem? {
        let channel = Double(event.param3 & Mask.gamma.rawValue)
        let eventId = Int(event.eventId)
        let encoder = dataProtocol.encoderForEventId(eventId)
        
        if criteria.gammaEncodersOnly, !criteria.gammaEncoderIds.contains(Int(encoder)) {
            return nil
        }
        
        let energy: Double
        let type: SearchType = .gamma
        if calibration.hasData() {
            energy = calibration.calibratedValueForAmplitude(channel, type: type, eventId: eventId, encoder: encoder, strip0_15: nil, dataProtocol: dataProtocol)
        } else {
            energy = channel
        }
        // TODO: use marker info
        // let coincidenceWithBGO = (event.param3 >> 15) == 1
        let strip = (event.param3 << 1) >> 12
        let item = DetectorMatchItem(type: type,
                                     stripDetector: nil,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip,
                                     deltaTime: deltaTime,
                                     marker: event.getMarker(),
                                     side: nil)
        return item
    }
    
    fileprivate func storeRecoil(_ event: Event, energy: Double, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?) {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let side: StripsSide = .front
        let item = DetectorMatchItem(type: .recoil,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: event.getMarker(),
                                     subMatches: subMatches,
                                     side: side)
        recoilsPerAct.append(item, side: side)
    }
    
    fileprivate func storeFissionAlpha(_ index: Int, event: Event, type: SearchType, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?, back: DetectorMatchItem?) {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: type)
        let side: StripsSide = .front
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: event.getMarker(),
                                     subMatches: subMatches,
                                     side: side)
        let match = fissionsAlphaNextPerAct[index] ?? DoubleSidedStripDetectorMatch()
        match.append(item, side: side)
        if let back = back {
            match.append(back, side: .back)
        }
        fissionsAlphaNextPerAct[index] = match
    }
    
    fileprivate func TOFValue(_ value: Double, deltaTime: CLongLong) -> DetectorMatchItem {
        let item = DetectorMatchItem(type: .tof,
                                     stripDetector: nil,
                                     deltaTime: deltaTime,
                                     value: value,
                                     side: nil)
        return item
    }
    
    fileprivate func storeVETO(_ event: Event, deltaTime: CLongLong) {
        let strip0_15 = event.param2 >> 12
        let type: SearchType = .veto
        let energy = getEnergy(event, type: type)
        let item = DetectorMatchItem(type: type,
                                     stripDetector: nil,
                                     energy: energy,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     side: nil)
        vetoPerAct.append(item)
    }
    
    fileprivate func filterAndStoreFissionAlphaWell(_ event: Event, side: StripsSide) {
        var type: SearchType
        if side == .front {
            if criteria.searchExtraFromLastParticle, let index = criteria.nextMaxIndex(), let t = criteria.next[index]?.frontType {
                type = t
            } else {
                type = criteria.startParticleType
            }
        } else {
            type = criteria.wellParticleBackType
        }
        let energy = getEnergy(event, type: type)
        if energy < criteria.fissionAlphaWellMinEnergy || energy > criteria.fissionAlphaWellMaxEnergy {
            return
        }
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip0_15 = event.param2 >> 12
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .side,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     marker: event.getMarker(),
                                     side: side)
        fissionsAlphaWellPerAct.append(item, side: side)
        // Store only well event with max energy
        fissionsAlphaWellPerAct.matchFor(side: side).filterItemsByMaxEnergy(maxStripsDelta: criteria.recoilBackMaxDeltaStrips)
    }
    
    fileprivate func storeSpecial(_ event: Event, id: Int) {
        let channel = event.param3 & Mask.special.rawValue
        specialPerAct[id] = channel
    }
    
    fileprivate func clearActInfo() {
        neutronsPerAct = NeutronsMatch()
        fissionsAlphaPerAct.removeAll()
        specialPerAct.removeAll()
        beamStatePerAct.clean()
        fissionsAlphaWellPerAct.removeAll()
        recoilsPerAct.removeAll()
        fissionsAlphaNextPerAct.removeAll()
        vetoPerAct.removeAll()
    }
    
    // MARK: - Helpers
    
    fileprivate func isEventStripNearToFirstParticle(_ event: Event, maxDelta: Int, side: StripsSide) -> Bool {
        let strip0_15 = event.param2 >> 12
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip1_N = stripsConfiguration(detector: .focal).strip1_N_For(side: side, encoder: Int(encoder), strip0_15: strip0_15)
        if let s = firstParticlePerAct.firstItemsFor(side: side)?.strip1_N {
            return abs(Int32(strip1_N) - Int32(s)) <= Int32(maxDelta)
        }
        return false
    }
    
    fileprivate func isRecoilBackStripNearToFissionAlphaBack(_ event: Event) -> Bool {
        let side: StripsSide = .back
        if let s = fissionsAlphaPerAct.matchFor(side: side).itemWithMaxEnergy()?.strip1_N {
            let strip0_15 = event.param2 >> 12
            let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
            let strip1_N = stripsConfiguration(detector: .focal).strip1_N_For(side: side, encoder: Int(encoder), strip0_15: strip0_15)
            return abs(Int32(strip1_N) - Int32(s)) <= Int32(criteria.recoilBackMaxDeltaStrips)
        }
        return false
    }
    
    /**
     +/-1 strips check at this moment.
     */
    fileprivate func isFissionStripNearToFirstFissionFront(_ event: Event) -> Bool {
        let side: StripsSide = .front
        if let s = fissionsAlphaPerAct.firstItemsFor(side: side)?.strip1_N {
            let strip0_15 = event.param2 >> 12
            let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
            let strip1_N = stripsConfiguration(detector: .focal).strip1_N_For(side: side, encoder: Int(encoder), strip0_15: strip0_15)
            return Int(abs(Int32(strip1_N) - Int32(s))) <= 1
        }
        return false
    }
    
    /**
     Time stored in events are relative time (timer from 0x0000 to xFFFF mks resettable on overflow).
     We use special event 'dataProtocol.CycleTime' to calculate time from file start.
     */
    fileprivate func absTime(_ relativeTime: CUnsignedShort, cycle: CUnsignedLongLong) -> CUnsignedLongLong {
        return (cycle << 16) + CUnsignedLongLong(relativeTime)
    }
    
    /**
     First bit from param3 used to separate recoil and fission/alpha events:
     0 - fission fragment,
     1 - recoil
     */
    fileprivate func isRecoil(_ event: Event) -> Bool {
        return (event.param3 >> 15) == 1
    }
    
    /**
     Second bit from param3 related to beam state:
     0 - on,
     1 - off (!)
     */
    fileprivate func isInBeam(_ event: Event) -> Bool {
        // TODO: this is for SHELS separator. Handle reverse logic for GRAND separator.
        let outBeam = (event.param3 << 1) >> 15
        return outBeam != 1
    }
    
    /**
     Third bit from param3 is overflow with different signal:
     0 - no,
     1 - yes
     */
    fileprivate func isOverflow(_ event: Event) -> Bool {
        let overflow = (event.param3 << 2) >> 15
        return overflow == 1
    }
    
    fileprivate func isGammaEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.isGammaEvent(eventId)
    }
    
    fileprivate func isFront(_ event: Event, type: SearchType) -> Bool {
        let searchRecoil = type == .recoil || type == .heavy
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && isFront(event)
    }
    
    fileprivate func isFront(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.isAlphaFronEvent(eventId)
    }
    
    fileprivate func isFissionOrAlphaWell(_ event: Event, side: StripsSide) -> Bool {
        let eventId = Int(event.eventId)
        if isRecoil(event) && !criteria.wellRecoilsAllowed {
            return false
        }
        return (side == .front && dataProtocol.isAlphaWellEvent(eventId)) || (side == .back && dataProtocol.isAlphaWellBackEvent(eventId))
    }
    
    fileprivate func isBack(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == .recoil || type == .heavy
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && dataProtocol.isAlphaBackEvent(eventId)
    }
    
    fileprivate func eventNumber(_ total: Bool = false) -> CUnsignedLongLong {
        var position = fpos_t()
        fgetpos(file, &position)
        var value = CUnsignedLongLong(position/Int64(Event.size))
        if total {
            value += totalEventNumber
        }
        return value
    }
    
    fileprivate func channelForTOF(_ event :Event) -> CUnsignedShort {
        return event.param3 & Mask.TOF.rawValue
    }
    
    fileprivate func getEnergy(_ event: Event, type: SearchType) -> Double {
        let channel = Double(event.getChannelFor(type: type))
        if calibration.hasData() {
            let eventId = Int(event.eventId)
            let encoder = dataProtocol.encoderForEventId(eventId)
            let strip0_15 = event.param2 >> 12
            return calibration.calibratedValueForAmplitude(channel, type: type, eventId: eventId, encoder: encoder, strip0_15: strip0_15, dataProtocol: dataProtocol)
        } else {
            return channel
        }
    }
    
    fileprivate func valueTOF(_ eventTOF: Event, eventRecoil: Event) -> Double {
        let channel = Double(channelForTOF(eventTOF))
        if criteria.unitsTOF == .channels || !calibration.hasData() {
            return channel
        } else {
            if let value = calibration.calibratedTOFValueForAmplitude(channel) {
                return value
            } else {
                let eventId = Int(eventRecoil.eventId)
                let encoder = dataProtocol.encoderForEventId(eventId)
                let strip0_15 = eventRecoil.param2 >> 12
                return calibration.calibratedValueForAmplitude(channel, type: SearchType.tof, eventId: eventId, encoder: encoder, strip0_15: strip0_15, dataProtocol: dataProtocol)
            }
        }
    }
    
    // MARK: - Output
    
    fileprivate func logInput(onEnd: Bool) {
        DispatchQueue.main.async { [weak self] in
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            let image = appDelegate.window.screenshot()
            self?.logger.logInput(image, onEnd: onEnd)
        }
    }
    
    fileprivate func logCalibration() {
        logger.logCalibration(calibration.stringValue ?? "")
    }
    
}

extension Processor: ResultsTableDelegate {
    
    func rowsCountForCurrentResult() -> Int {
        return max(max(max(max(max(1, vetoPerAct.count), fissionsAlphaPerAct.count), recoilsPerAct.count), neutronsCountWithNewLine()), fissionsAlphaNextPerAct.values.map { $0.count }.max() ?? 0)
    }
    
    // Need special results block for neutron times, so we skeep one line.
    func neutronsCountWithNewLine() -> Int {
        let count = neutronsPerAct.count
        if count > 0 {
            return count + 1
        } else {
            return 0
        }
    }
    
    func neutrons() -> NeutronsMatch {
        return neutronsPerAct
    }
    
    func currentFileEventNumber(_ number: CUnsignedLongLong) -> String {
        return String(format: "%@_%llu", currentFileName ?? "", number)
    }
    
    func focalGammaContainer() -> DetectorMatch? {
        var match: DoubleSidedStripDetectorMatch?
        if criteria.searchExtraFromLastParticle {
            match = lastFissionAlphaNextPerAct
        } else if criteria.startFromRecoil() {
            match = recoilsPerAct
        } else {
            match = fissionsAlphaPerAct
        }
        return match?.matchFor(side: .front)
    }
    
    func vetoAt(index: Int) -> DetectorMatchItem? {
        return vetoPerAct.itemAt(index: index)
    }
    
    func recoilAt(side: StripsSide, index: Int) -> DetectorMatchItem? {
        return recoilsPerAct.matchFor(side: side).itemAt(index: index)
    }
    
    func fissionsAlphaWellAt(side: StripsSide, index: Int) -> DetectorMatchItem? {
        return fissionsAlphaWellPerAct.matchFor(side: side).itemAt(index: index)
    }
    
    func beamState() -> BeamState {
        return beamStatePerAct
    }
    
    func firstParticleAt(side: StripsSide) -> DetectorMatch {
        return firstParticlePerAct.matchFor(side: side)
    }
    
    func nextParticleAt(side: StripsSide, index: Int) -> DetectorMatch? {
        return fissionsAlphaNextPerAct[index]?.matchFor(side: side)
    }
    
    func specialWith(eventId: Int) -> CUnsignedShort? {
        return specialPerAct[eventId]
    }
    
}
