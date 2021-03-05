//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import Cocoa

protocol ProcessorDelegate: class {
    
    func startProcessingFile(_ name: String?)
    func endProcessingFile(_ name: String?)
    
}

enum TOFUnits {
    case channels
    case nanoseconds
}

class Processor {
    
    fileprivate var file: UnsafeMutablePointer<FILE>!
    fileprivate var currentCycle: CUnsignedLongLong = 0
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var startEventTime: CUnsignedLongLong = 0
    fileprivate var secondEventTime: CUnsignedLongLong = 0
    fileprivate var neutronsPerAct = [Float]()
    fileprivate var neutrons_N_SumPerAct: CUnsignedLongLong = 0
    fileprivate var neutronsBackwardSumPerAct: CUnsignedLongLong = 0
    fileprivate var currentFileName: String?
    fileprivate var neutronsMultiplicity: NeutronsMultiplicity?
    fileprivate var specialPerAct = [Int: CUnsignedShort]()
    fileprivate var beamStatePerAct = BeamState()
    fileprivate var fissionsAlphaPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var fissionsAlpha2PerAct = DetectorMatch()
    fileprivate var recoilsPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var firstParticlePerAct: DoubleSidedStripDetectorMatch {
        return criteria.startFromRecoil() ? recoilsPerAct : fissionsAlphaPerAct
    }
    fileprivate var fissionsAlphaWellPerAct = DoubleSidedStripDetectorSingleMatch()
    fileprivate var vetoPerAct = DetectorMatch()
    fileprivate var stoped = false
    fileprivate var logger: Logger!
    
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
    
    fileprivate var criteria = SearchCriteria()
    fileprivate weak var delegate: ProcessorDelegate?
    
    var filesFinishedCount: Int = 0
    
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
    
    fileprivate func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, maxDeltaTimeBackward: CUnsignedLongLong? = nil, useCycleTime: Bool, updateCycle: Bool, checker: @escaping ((Event, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>, Int)->())) {
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
                    if deltaTime <= maxDeltaTime {
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
        
        neutronsMultiplicity = NeutronsMultiplicity(efficiency: criteria.neutronsDetectorEfficiency, efficiencyError: criteria.neutronsDetectorEfficiencyError)
        totalEventNumber = 0
        clearActInfo()
        
        logger = Logger(folder: criteria.resultsFolderName)
        logger.logSettings()
        logInput(onEnd: false)
        logCalibration()
        logResultsHeader()
        logGammaHeader()
        
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
                    self?.delegate?.endProcessingFile(self?.currentFileName)
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
            startEventTime = UInt64(event.param1)
            
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
                
                if !criteria.searchExtraFromParticle2 {
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
                
                if !criteria.searchExtraFromParticle2 {
                    findFissionAlphaWell(position)
                    if wellSearchFailed() {
                        clearActInfo()
                        return
                    }
                }
            }
            
            if criteria.searchFissionAlpha2 {
                findFissionAlpha2()
                fseek(file, position, SEEK_SET)
                if 0 == fissionsAlpha2PerAct.count {
                    clearActInfo()
                    return
                }
                if criteria.searchExtraFromParticle2 && wellSearchFailed() {
                    clearActInfo()
                    return
                }
            }
            
            if !criteria.startFromRecoil() && criteria.requiredGammaOrWell && gamma == nil && nil == fissionsAlphaWellPerAct.itemFor(side: .front) {
                clearActInfo()
                return
            }
            
            if !criteria.searchExtraFromParticle2 {
                findAllNeutrons(position)
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
                findNextFissionsAlphaFront(folder)
            }
            
            if criteria.searchNeutrons {
                neutronsMultiplicity?.update(neutronsPerAct: neutronsPerAct)
            }
            
            logActResults()
            for b in [false, true] {
                logGamma(GeOnly: b)
            }
            clearActInfo()
        } else {
            updateFolderStatistics(event, folder: folder)
        }
    }
    
    fileprivate func wellSearchFailed() -> Bool {
        return criteria.searchWell && criteria.requiredWell && nil == fissionsAlphaWellPerAct.itemFor(side: .front)
    }
    
    fileprivate func findAllNeutrons(_ position: Int) {
        if criteria.searchNeutrons {
            findNeutrons()
            fseek(file, Int(position), SEEK_SET)
            findNeutronsBack()
            fseek(file, Int(position), SEEK_SET)
        }
    }
    
    fileprivate func updateFolderStatistics(_ event: Event, folder: FolderStatistics) {
        let id = Int(event.eventId)
        if dataProtocol.isBeamEnergy(id) {
            let e = event.getFloatValue()
            if e >= criteria.beamEnergyMin && e <= criteria.beamEnergyMax {
                folder.handleEnergy(e)
            }
        } else if dataProtocol.isBeamIntegral(id) {
            folder.handleIntergal(event)
        }
    }
    
    fileprivate func findFissionAlphaWell(_ position: Int) {
        if criteria.searchWell {
            let directions: Set<SearchDirection> = [.backward, .forward]
            let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
            search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                for side in [.front, .back] as [StripsSide] {
                    if self.isFissionOrAlphaWell(event, side: side) {
                        self.filterAndStoreFissionAlphaWell(event, side: side)
                    }
                }
            }
            fseek(file, position, SEEK_SET)
        }
    }
    
    fileprivate func findNeutrons() {
        let directions: Set<SearchDirection> = [.forward]
        let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
        search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: criteria.maxNeutronTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.dataProtocol.isNeutronsEvent(Int(event.eventId)) {
                let t = Float(event.param3 & Mask.neutrons.rawValue)
                self.neutronsPerAct.append(t)
            }
            if self.dataProtocol.hasNeutrons_N() && self.dataProtocol.isNeutrons_N_Event(Int(event.eventId)) {
                self.neutrons_N_SumPerAct += 1
            }
        }
    }
    
    fileprivate func findNeutronsBack() {
        let directions: Set<SearchDirection> = [.backward]
        let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
        search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: 10, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.dataProtocol.isNeutronsEvent(Int(event.eventId)) {
                self.neutronsBackwardSumPerAct += 1
            }
        }
    }
    
    fileprivate func findNextFissionsAlphaFront(_ folder: FolderStatistics) {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, useCycleTime: false, updateCycle: true) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
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
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxVETOTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.dataProtocol.isVETOEvent(Int(event.eventId)) {
                self.storeVETO(event, deltaTime: deltaTime)
            }
        }
    }
    
    fileprivate func findGamma(_ position: Int) -> DetectorMatch? {
        let match = DetectorMatch()
        let directions: Set<SearchDirection> = [.forward, .backward]
        let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
        search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: criteria.maxGammaTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
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
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
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
        let fissionTime = absTime(CUnsignedShort(startEventTime), cycle: currentCycle)
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
            if criteria.startFromRecoil(), !criteria.searchExtraFromParticle2 {
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
    
    fileprivate func findFissionAlpha2() {
        let alphaTime = absTime(CUnsignedShort(startEventTime), cycle: currentCycle)
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: alphaTime, minDeltaTime: criteria.fissionAlpha2MinTime, maxDeltaTime: criteria.fissionAlpha2MaxTime, useCycleTime: true, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = self.criteria.secondParticleFrontType
            let isFront = self.isFront(event, type: t)
            if isFront {
                self.secondEventTime = UInt64(event.param1)
                let energy = self.getEnergy(event, type: t)
                if self.isEventStripNearToFirstParticle(event, maxDelta: Int(self.criteria.fissionAlpha2MaxDeltaStrips), side: .front) && ((!isFront && self.criteria.searchFissionAlphaBack2ByFact) || (energy >= self.criteria.fissionAlpha2MinEnergy && energy <= self.criteria.fissionAlpha2MaxEnergy)) {
                    var store = true
                    var gamma: DetectorMatch?
                    // Back
                    let back = self.findFissionAlpha2Back(position)
                    if self.criteria.requiredFissionAlphaBack && back == nil {
                        store = false
                    } else {
                        // Extra Search
                        if self.criteria.searchExtraFromParticle2 {
                            self.findFissionAlphaWell(position)
                            self.findAllNeutrons(position)
                            gamma = self.findGamma(position)
                            if nil == gamma, self.criteria.requiredGamma {
                                store = false
                            }
                        }
                    }
                    if store {
                        self.storeFissionAlpha2(event, type: t, deltaTime: deltaTime, subMatches: [.gamma: gamma, self.criteria.secondParticleBackType: back])
                    }
                }
            }
        }
    }
    
    fileprivate func findFissionAlpha2Back(_ position: Int) -> DetectorMatch? {
        let match = DetectorMatch()
        let directions: Set<SearchDirection> = [.forward, .backward]
        let byFact = self.criteria.searchFissionAlphaBack2ByFact
        search(directions: directions, startTime: secondEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = self.criteria.secondParticleBackType
            let isBack = self.isBack(event, type: t)
            if isBack {
                var store = self.isEventStripNearToFirstParticle(event, maxDelta: Int(self.criteria.fissionAlpha2MaxDeltaStrips), side: .back)
                if !byFact && store { // check energy also
                    let energy = self.getEnergy(event, type: t)
                    store = energy >= self.criteria.fissionAlpha2BackMinEnergy && energy <= self.criteria.fissionAlpha2BackMaxEnergy
                }
                if store {
                    let item = self.focalDetectorMatchItemFrom(event, type: t, deltaTime: deltaTime, side: .back)
                    match.append(item)
                    if byFact { // just stop on first one
                        stop.initialize(to: true)
                    }
                }
            }
        }
        fseek(file, position, SEEK_SET)
        return match.count > 0 ? match : nil
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
                                     marker: getMarker(event),
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
        let channel = getChannel(event, type: type)
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
                                     marker: getMarker(event),
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
        let item = DetectorMatchItem(type: type,
                                     stripDetector: nil,
                                     energy: energy,
                                     encoder: encoder,
                                     deltaTime: deltaTime,
                                     marker: getMarker(event),
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
                                     marker: getMarker(event),
                                     subMatches: subMatches,
                                     side: side)
        recoilsPerAct.append(item, side: side)
    }
    
    fileprivate func storeFissionAlpha2(_ event: Event, type: SearchType, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?) {
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
                                     marker: getMarker(event),
                                     subMatches: subMatches,
                                     side: side)
        fissionsAlpha2PerAct.append(item)
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
        let type = side == .front ? (criteria.searchExtraFromParticle2 ? criteria.secondParticleFrontType : criteria.startParticleType) : criteria.wellParticleBackType
        let energy = getEnergy(event, type: type)
        if energy < criteria.fissionAlphaWellMinEnergy || energy > criteria.fissionAlphaWellMaxEnergy {
            return
        }
        if let e = fissionsAlphaWellPerAct.itemFor(side: side)?.energy, e >= energy { // Store only well event with max energy
            return
        }
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip0_15 = event.param2 >> 12
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .side,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     marker: getMarker(event),
                                     side: side)
        fissionsAlphaWellPerAct.setItem(item, forSide: side)
    }
    
    fileprivate func storeSpecial(_ event: Event, id: Int) {
        let channel = event.param3 & Mask.special.rawValue
        specialPerAct[id] = channel
    }
    
    fileprivate func clearActInfo() {
        neutronsPerAct.removeAll()
        neutrons_N_SumPerAct = 0
        neutronsBackwardSumPerAct = 0
        fissionsAlphaPerAct.removeAll()
        specialPerAct.removeAll()
        beamStatePerAct.clean()
        fissionsAlphaWellPerAct.removeAll()
        recoilsPerAct.removeAll()
        fissionsAlpha2PerAct.removeAll()
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
    
    fileprivate func getMarker(_ event: Event) -> CUnsignedShort {
        return event.param3 >> 13
    }
    
    /**
     First bit from param3 used to separate recoil and fission/alpha events:
     0 - fission fragment,
     1 - recoil
     */
    fileprivate func isRecoil(_ event: Event) -> Bool {
        return (event.param3 >> 15) == 1
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
    
    fileprivate func eventNumber() -> CUnsignedLongLong {
        var position = fpos_t()
        fgetpos(file, &position)
        let value = CUnsignedLongLong(position/Int64(Event.size)) + totalEventNumber + 1
        return value
    }
    
    fileprivate func channelForTOF(_ event :Event) -> CUnsignedShort {
        return event.param3 & Mask.TOF.rawValue
    }
    
    fileprivate func getChannel(_ event: Event, type: SearchType) -> CUnsignedShort {
        return (type == .fission || type == .heavy) ? (event.param2 & Mask.heavyOrFission.rawValue) : (event.param3 & Mask.recoilOrAlpha.rawValue)
    }
    
    fileprivate func getEnergy(_ event: Event, type: SearchType) -> Double {
        let channel = Double(getChannel(event, type: type))
        if calibration.hasData() {
            let eventId = Int(event.eventId)
            let encoder = dataProtocol.encoderForEventId(eventId)
            let strip0_15 = event.param2 >> 12
            return calibration.calibratedValueForAmplitude(channel, type: type, eventId: eventId, encoder: encoder, strip0_15: strip0_15, dataProtocol: dataProtocol)
        } else {
            return channel
        }
    }
    
    fileprivate func currentFileEventNumber(_ number: CUnsignedLongLong) -> String {
        return String(format: "%@_%llu", currentFileName ?? "", number)
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
    
    fileprivate func searchExtraPostfix(_ s: String) -> String {
        if criteria.searchExtraFromParticle2 {
            return s + "(2)"
        } else {
            return s
        }
    }
    
    fileprivate var columns = [String]()
    fileprivate var keyColumnRecoilFrontEvent: String {
        let name = criteria.recoilType == .recoil ? "Recoil" : "Heavy Recoil"
        return "Event(\(name))"
    }
    fileprivate var keyRecoil: String {
        return  criteria.recoilType == .recoil ? "R" : "HR"
    }
    fileprivate var keyColumnRecoilFrontEnergy: String {
        return "E(\(keyRecoil)Fron)"
    }
    fileprivate var keyColumnRecoilFrontFrontMarker: String {
        return "\(keyRecoil)FronMarker"
    }
    fileprivate var keyColumnRecoilFrontDeltaTime: String {
        return "dT(\(keyRecoil)Fron-$Fron)"
    }
    fileprivate var keyColumnRecoilBackEvent: String {
        let name = criteria.recoilBackType == .recoil ? "Recoil" : "Heavy Recoil"
        return "Event(\(name)Back)"
    }
    fileprivate let keyColumnRecoilBackEnergy: String = "E(RBack)"
    fileprivate var keyColumnTof = "TOF"
    fileprivate var keyColumnTof2 = "TOF2"
    fileprivate var keyColumnTofDeltaTime = "dT(TOF-RFron)"
    fileprivate var keyColumnTof2DeltaTime = "dT(TOF2-RFron)"
    fileprivate var keyColumnStartEvent = "Event($)"
    fileprivate var keyColumnStartFrontSum = "Sum($Fron)"
    fileprivate var keyColumnStartFrontEnergy = "$Fron"
    fileprivate var keyColumnStartFrontMarker = "$FronMarker"
    fileprivate var keyColumnStartFrontDeltaTime = "dT($FronFirst-Next)"
    fileprivate var keyColumnStartFrontStrip = "Strip($Fron)"
    fileprivate var keyColumnStartFocalPositionXYZ = "StartFocalPositionXYZ"
    fileprivate var keyColumnStartBackSum = "Sum(@Back)"
    fileprivate var keyColumnStartBackEnergy = "@Back"
    fileprivate var keyColumnStartBackMarker = "@BackMarker"
    fileprivate var keyColumnStartBackDeltaTime = "dT($Fron-@Back)"
    fileprivate var keyColumnStartBackStrip = "Strip(@Back)"
    fileprivate var keyColumnWellEnergy: String {
        return searchExtraPostfix("$Well")
    }
    fileprivate var keyColumnWellMarker = "$WellMarker"
    fileprivate var keyColumnWellPosition = "$WellPos"
    fileprivate var keyColumnWellPositionXYZ = "$WellPosXYZ"
    fileprivate var keyColumnWellAngle = "$WellAngle"
    fileprivate var keyColumnWellStrip = "Strip($Well)"
    fileprivate var keyColumnWellBackEnergy = "*WellBack"
    fileprivate var keyColumnWellBackMarker = "*WellBackMarker"
    fileprivate var keyColumnWellBackPosition = "*WellBackPos"
    fileprivate var keyColumnWellBackStrip = "Strip(*WellBack)"
    fileprivate var keyColumnNeutronsAverageTime = "NeutronsAverageTime"
    fileprivate var keyColumnNeutronTime = "NeutronTime"
    fileprivate var keyColumnNeutrons: String {
        return searchExtraPostfix("Neutrons")
    }
    fileprivate var keyColumnNeutrons_N = "N1...N4"
    fileprivate var keyColumnNeutronsBackward = "Neutrons(Backward)"
    fileprivate let keyColumnEvent: String = "Event"
    fileprivate func keyColumnGammaEnergy(_ max: Bool) -> String {
        var s = searchExtraPostfix("Gamma")
        if max {
            s += "Max"
        }
        if criteria.simplifyGamma {
            s += "_Simplified"
        }
        return s
    }
    fileprivate func keyColumnGammaEncoder(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        return s + "Encoder"
    }
    fileprivate func keyColumnGammaDeltaTime(_ max: Bool) -> String {
        var s = "dT($Fron-Gamma"
        if max {
            s += "Max"
        }
        return s + ")"
    }
    fileprivate func keyColumnGammaMarker(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        return s + "Marker"
    }
    fileprivate var keyColumnGammaCount = "GammaCount"
    fileprivate var keyColumnGammaSumEnergy = "GammaSumEnergy"
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
    fileprivate var keyColumnFissionAlphaFront2Sum = "Sum(&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Event = "Event(&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Energy = "E(&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Marker = "&Front2Marker"
    fileprivate var keyColumnFissionAlphaFront2DeltaTime = "dT($Front1-&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Strip = "Strip(&Front2)"
    fileprivate var keyColumnFissionAlphaBack2Sum = "Sum(^Back2)"
    fileprivate var keyColumnFissionAlphaBack2Energy = "^Back2"
    fileprivate var keyColumnFissionAlphaBack2Marker = "^Back2Marker"
    fileprivate var keyColumnFissionAlphaBack2DeltaTime = "dT(&Fron2-^Back2)"
    fileprivate var keyColumnFissionAlphaBack2Strip = "Strip(^Back2)"
    
    fileprivate var columnsGamma = [String]()
    
    fileprivate func logGammaHeader() {
        if !criteria.simplifyGamma {
            columnsGamma.append(contentsOf: [
                keyColumnEvent,
                keyColumnGammaEnergy(false),
                keyColumnGammaSumEnergy,
                keyColumnGammaEncoder(false),
                keyColumnGammaDeltaTime(false),
                keyColumnGammaMarker(false),
                keyColumnGammaCount
            ])
            let headers = setupHeaders(columnsGamma)
            for destination in [.gammaAll, .gammaGeOnly] as [LoggerDestination] {
                logger.writeLineOfFields(headers, destination: destination)
                logger.finishLine(destination) // +1 line padding
            }
        }
    }
    
    fileprivate func logResultsHeader() {
        columns = []
        if !criteria.startFromRecoil() {
            columns.append(contentsOf: [
                keyColumnRecoilFrontEvent,
                keyColumnRecoilFrontEnergy,
                keyColumnRecoilFrontFrontMarker,
                keyColumnRecoilFrontDeltaTime,
                keyColumnRecoilBackEvent,
                keyColumnRecoilBackEnergy
            ])
        }
        columns.append(contentsOf: [
            keyColumnTof,
            keyColumnTofDeltaTime
        ])
        if criteria.useTOF2 {
            columns.append(contentsOf: [
                keyColumnTof2,
                keyColumnTof2DeltaTime,
            ])
        }
        columns.append(contentsOf: [
            keyColumnStartEvent,
            keyColumnStartFrontSum,
            keyColumnStartFrontEnergy,
            keyColumnStartFrontMarker,
            keyColumnStartFrontDeltaTime,
            keyColumnStartFrontStrip,
            keyColumnStartFocalPositionXYZ,
            keyColumnStartBackSum,
            keyColumnStartBackEnergy,
            keyColumnStartBackMarker,
            keyColumnStartBackDeltaTime,
            keyColumnStartBackStrip])
        if criteria.searchWell {
            columns.append(contentsOf: [
                keyColumnWellEnergy,
                keyColumnWellMarker,
                keyColumnWellPosition,
                keyColumnWellPositionXYZ,
                keyColumnWellAngle,
                keyColumnWellStrip,
                keyColumnWellBackEnergy,
                keyColumnWellBackMarker,
                keyColumnWellBackPosition,
                keyColumnWellBackStrip
                ])
        }
        if criteria.searchNeutrons {
            columns.append(contentsOf: [keyColumnNeutronsAverageTime, keyColumnNeutronTime, keyColumnNeutrons])
            if dataProtocol.hasNeutrons_N() {
                columns.append(keyColumnNeutrons_N)
            }
            columns.append(keyColumnNeutronsBackward)
        }
        columns.append(contentsOf: [
            keyColumnGammaEnergy(true),
            keyColumnGammaSumEnergy,
            keyColumnGammaEncoder(true),
            keyColumnGammaDeltaTime(true),
            keyColumnGammaCount
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
            columns.append(keyColumnFissionAlphaFront2Event)
            if criteria.summarizeFissionsAlphaFront2 {
                columns.append(keyColumnFissionAlphaFront2Sum)
            }
            columns.append(contentsOf: [
                keyColumnFissionAlphaFront2Energy,
                keyColumnFissionAlphaFront2Marker,
                keyColumnFissionAlphaFront2DeltaTime,
                keyColumnFissionAlphaFront2Strip,
                keyColumnFissionAlphaBack2Sum,
                keyColumnFissionAlphaBack2Energy,
                keyColumnFissionAlphaBack2Marker,
                keyColumnFissionAlphaBack2DeltaTime,
                keyColumnFissionAlphaBack2Strip
                ])
        }
        let headers = setupHeaders(columns)
        logger.writeLineOfFields(headers, destination: .results)
        logger.finishLine(.results) // +1 line padding
    }
    
    fileprivate func setupHeaders(_ headers: [String]) -> [AnyObject] {
        let firstFront = criteria.startParticleType.symbol()
        let firstBack = criteria.startParticleBackType.symbol()
        let wellBack = criteria.wellParticleBackType.symbol()
        let secondFront = criteria.secondParticleFrontType.symbol()
        let secondBack = criteria.secondParticleBackType.symbol()
        let dict = ["$": firstFront,
                    "@": firstBack,
                    "*": wellBack,
                    "&": secondFront,
                    "^": secondBack]
        return headers.map { (s: String) -> String in
            var result = s
            for (key, value) in dict {
                result = result.replacingOccurrences(of: key, with: value)
            }
            return result
        } as [AnyObject]
    }
    
    // Need special results block for neutron times, so we skeep one line.
    fileprivate func neutronsCountWithNewLine() -> Int {
        let count = neutronsPerAct.count
        if count > 0 {
            return count + 1
        } else {
            return 0
        }
    }
    
    fileprivate func tof(row: Int, type: SearchType) -> DetectorMatch? {
        return recoilsPerAct.matchFor(side: .front).itemAt(index: row)?.subMatches?[type] ?? nil
    }
    
    fileprivate var currentStartEventNumber: CUnsignedLongLong?
    
    fileprivate var focalGammaContainer: DetectorMatch? {
        if criteria.searchExtraFromParticle2 {
            return fissionsAlpha2PerAct
        } else if criteria.startFromRecoil() {
            return recoilsPerAct.matchFor(side: .front)
        } else {
            return fissionsAlphaPerAct.matchFor(side: .front)
        }
    }
    
    fileprivate func gammaAt(row: Int) -> DetectorMatch? {
        return focalGammaContainer?.itemAt(index: row)?.subMatches?[.gamma] ?? nil
    }
    
    fileprivate func logGamma(GeOnly: Bool) {
        if !criteria.simplifyGamma, let f = focalGammaContainer {
            let count = f.count
            if count > 0 {
                for i in 0...count-1 {
                    if let item = f.itemAt(index: i), let gamma = item.subMatches?[.gamma], var g = gamma {
                        if GeOnly {
                            g = g.filteredByMarker(marker: 0)
                        }
                        let destination: LoggerDestination = GeOnly ? .gammaGeOnly : .gammaAll
                        let c = g.count
                        if c > 0 {
                            let rowsMax = c
                            for row in 0 ..< rowsMax {
                                for column in columnsGamma {
                                    var field = ""
                                    switch column {
                                    case keyColumnEvent:
                                        if row == 0, let eventNumber = item.eventNumber {
                                            field = currentFileEventNumber(eventNumber)
                                        }
                                    case keyColumnGammaEnergy(false):
                                        if let energy = g.itemAt(index: row)?.energy {
                                            field = String(format: "%.7f", energy)
                                        }
                                    case keyColumnGammaSumEnergy:
                                        if row == 0, let sum = g.getSumEnergy() {
                                            field = String(format: "%.7f", sum)
                                        }
                                    case keyColumnGammaEncoder(false):
                                        if let encoder = g.itemAt(index: row)?.encoder {
                                            field = String(format: "%hu", encoder)
                                        }
                                    case keyColumnGammaDeltaTime(false):
                                        if let deltaTime = g.itemAt(index: row)?.deltaTime {
                                            field = String(format: "%lld", deltaTime)
                                        }
                                    case keyColumnGammaMarker(false):
                                        if let marker = g.itemAt(index: row)?.marker {
                                            field = String(format: "%hu", marker)
                                        }
                                    case keyColumnGammaCount:
                                        if row == 0 {
                                            field = String(format: "%d", c)
                                        }
                                    default:
                                        break
                                    }
                                    logger.writeField(field as AnyObject, destination: destination)
                                }
                                logger.finishLine(destination)
                            }
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func logActResults() {
        let rowsMax = max(max(max(max(max(1, vetoPerAct.count), fissionsAlphaPerAct.count), recoilsPerAct.count), neutronsCountWithNewLine()), fissionsAlpha2PerAct.count)
        for row in 0 ..< rowsMax {
            for column in columns {
                var field = ""
                switch column {
                case keyColumnRecoilFrontEvent:
                    if let eventNumber = recoilsPerAct.matchFor(side: .front).itemAt(index: row)?.eventNumber {
                        field = currentFileEventNumber(eventNumber)
                    }
                case keyColumnRecoilFrontEnergy:
                    if let energy = recoilsPerAct.matchFor(side: .front).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnRecoilFrontFrontMarker:
                    if let marker = recoilsPerAct.matchFor(side: .front).itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnRecoilFrontDeltaTime:
                    if let deltaTime = recoilsPerAct.matchFor(side: .front).itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnRecoilBackEvent:
                    if let eventNumber = recoilsPerAct.matchFor(side: .back).itemAt(index: row)?.eventNumber {
                        field = currentFileEventNumber(eventNumber)
                    }
                case keyColumnRecoilBackEnergy:
                    if let energy = recoilsPerAct.matchFor(side: .back).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnTof, keyColumnTof2:
                    if let value = tof(row: row, type: column == keyColumnTof ? .tof : .tof2)?.itemAt(index: 0)?.value {
                        let format = "%." + (criteria.unitsTOF == .channels ? "0" : "7") + "f"
                        field = String(format: format, value)
                    }
                case keyColumnTofDeltaTime, keyColumnTof2DeltaTime:
                    if let deltaTime = tof(row: row, type: column == keyColumnTof ? .tof : .tof2)?.itemAt(index: 0)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartEvent:
                    if let eventNumber = firstParticlePerAct.matchFor(side: .front).itemAt(index: row)?.eventNumber {
                        field = currentFileEventNumber(eventNumber)
                        currentStartEventNumber = eventNumber
                    } else if row < neutronsCountWithNewLine(), let eventNumber = currentStartEventNumber { // Need track start event number for neutron times results
                        field = currentFileEventNumber(eventNumber)
                    }
                case keyColumnStartFrontSum:
                    if row == 0, !criteria.startFromRecoil(), let sum = fissionsAlphaPerAct.matchFor(side: .front).getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnStartFrontEnergy:
                    if let energy = firstParticlePerAct.matchFor(side: .front).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartFrontMarker:
                    if let marker = firstParticlePerAct.matchFor(side: .front).itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnStartFrontDeltaTime:
                    if let deltaTime = firstParticlePerAct.matchFor(side: .front).itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartFrontStrip:
                    if let strip = firstParticlePerAct.matchFor(side: .front).itemAt(index: row)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnStartFocalPositionXYZ:
                    let matches = firstParticlePerAct
                    if let itemFront = matches.matchFor(side: .front).itemAt(index: row), let stripFront1 = itemFront.strip1_N, let itemBack = matches.matchFor(side: .back).itemAt(index: row), let stripBack1 = itemBack.strip1_N {
                        let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0: stripFront1 - 1, stripBack0: stripBack1 - 1)
                        field = String(format: "%.1f|%.1f|%.1f", point.x, point.y, point.z)
                    }
                case keyColumnStartBackSum:
                    if row == 0, !criteria.startFromRecoil(), let sum = fissionsAlphaPerAct.matchFor(side: .back).getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnStartBackEnergy:
                    let side: StripsSide = .back
                    let match = firstParticlePerAct.matchFor(side: side)
                    if let energy = match.itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartBackMarker:
                    let side: StripsSide = .back
                    let match = firstParticlePerAct.matchFor(side: side)
                    if let marker = match.itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnStartBackDeltaTime:
                    let side: StripsSide = .back
                    let match = firstParticlePerAct.matchFor(side: side)
                    if let deltaTime = match.itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartBackStrip:
                    let side: StripsSide = .back
                    let match = firstParticlePerAct.matchFor(side: side)
                    if let strip = match.itemAt(index: row)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnWellEnergy:
                    if row == 0, let energy = fissionsAlphaWellPerAct.itemFor(side: .front)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnWellMarker:
                    if row == 0, let marker = fissionsAlphaWellPerAct.itemFor(side: .front)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnWellPosition:
                    if row == 0, let item = fissionsAlphaWellPerAct.itemFor(side: .front), let strip0_15 = item.strip0_15, let encoder = item.encoder {
                        field = String(format: "FWell%d.%d", encoder, strip0_15 + 1)
                    }
                case keyColumnWellPositionXYZ:
                    if row == 0, let itemFront = fissionsAlphaWellPerAct.itemFor(side: .front), let stripFront0 = itemFront.strip0_15, let itemBack = fissionsAlphaWellPerAct.itemFor(side: .back), let stripBack0 = itemBack.strip0_15, let encoder = itemFront.encoder {
                        let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .side, stripFront0: Int(stripFront0), stripBack0: Int(stripBack0), encoderSide: Int(encoder))
                        field = String(format: "%.1f|%.1f|%.1f", point.x, point.y, point.z)
                    }
                case keyColumnWellAngle:
                    let matches = firstParticlePerAct
                    if row == 0, let itemFocalFront = matches.matchFor(side: .front).itemAt(index: row), let stripFocalFront1 = itemFocalFront.strip1_N, let itemFocalBack = matches.matchFor(side: .back).itemAt(index: row), let stripFocalBack1 = itemFocalBack.strip1_N, let itemSideFront = fissionsAlphaWellPerAct.itemFor(side: .front), let stripSideFront0 = itemSideFront.strip0_15, let itemSideBack = fissionsAlphaWellPerAct.itemFor(side: .back), let stripSideBack0 = itemSideBack.strip0_15, let encoderSide = itemSideFront.encoder {
                        let pointFront = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0: stripFocalFront1 - 1, stripBack0: stripFocalBack1 - 1)
                        let pointSide = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .side, stripFront0: Int(stripSideFront0), stripBack0: Int(stripSideBack0), encoderSide: Int(encoderSide))
                        let hypotenuse = sqrt(pow(pointFront.x - pointSide.x, 2) + pow(pointFront.y - pointSide.y, 2) + pow(pointFront.z - pointSide.z, 2))
                        let sinus = pointSide.z / hypotenuse
                        let arcsinus = asin(sinus) * 180 / CGFloat.pi
                        field = String(format: "%.2f", arcsinus)
                    }
                case keyColumnWellStrip:
                    if row == 0, let strip = fissionsAlphaWellPerAct.itemFor(side: .front)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnWellBackEnergy:
                    if row == 0, let energy = fissionsAlphaWellPerAct.itemFor(side: .back)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnWellBackMarker:
                    if row == 0, let marker = fissionsAlphaWellPerAct.itemFor(side: .back)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnWellBackPosition:
                    if row == 0, let item = fissionsAlphaWellPerAct.itemFor(side: .back), let strip0_15 = item.strip0_15, let encoder = item.encoder {
                        field = String(format: "FWellBack%d.%d", encoder, strip0_15 + 1)
                    }
                case keyColumnWellBackStrip:
                    if row == 0, let strip = fissionsAlphaWellPerAct.itemFor(side: .back)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnNeutronsAverageTime:
                    if row == 0 {
                        let count = neutronsPerAct.count
                        if count > 0 {
                            let average = neutronsPerAct.reduce(0, +)/Float(count)
                            field = String(format: "%.1f", average)
                        } else {
                            field = "0"
                        }
                    }
                case keyColumnNeutronTime:
                    if row > 0 { // skip new line
                        let index = row - 1
                        if index < neutronsPerAct.count {
                            field = String(format: "%.1f", neutronsPerAct[index])
                        }
                    }
                case keyColumnNeutrons:
                    if row == 0 {
                        field = String(format: "%llu", neutronsPerAct.count)
                    }
                case keyColumnNeutrons_N:
                    if row == 0 {
                        field = String(format: "%llu", neutrons_N_SumPerAct)
                    }
                case keyColumnNeutronsBackward:
                    if row == 0 {
                        field = String(format: "%llu", neutronsBackwardSumPerAct)
                    }
                case keyColumnGammaEnergy(true):
                    if let energy = gammaAt(row: row)?.itemWithMaxEnergy()?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnGammaSumEnergy:
                    if row == 0, let sum = gammaAt(row: row)?.getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnGammaEncoder(true):
                    if let encoder = gammaAt(row: row)?.itemWithMaxEnergy()?.encoder {
                        field = String(format: "%hu", encoder)
                    }
                case keyColumnGammaDeltaTime(true):
                    if let deltaTime = gammaAt(row: row)?.itemWithMaxEnergy()?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnGammaCount:
                    if let count = gammaAt(row: row)?.count {
                        field = String(format: "%d", count)
                    }
                case _ where column.hasPrefix(keyColumnSpecial):
                    if row == 0 {
                        if let eventId = Int(column.replacingOccurrences(of: keyColumnSpecial, with: "")), let v = specialPerAct[eventId] {
                            field = String(format: "%hu", v)
                        }
                    }
                case keyColumnBeamEnergy:
                    if row == 0 {
                        if let e = beamStatePerAct.energy {
                            field = String(format: "%.1f", e.getFloatValue())
                        }
                    }
                case keyColumnBeamCurrent:
                    if row == 0 {
                        if let e = beamStatePerAct.current {
                            field = String(format: "%.2f", e.getFloatValue())
                        }
                    }
                case keyColumnBeamBackground:
                    if row == 0 {
                        if let e = beamStatePerAct.background {
                            field = String(format: "%.1f", e.getFloatValue())
                        }
                    }
                case keyColumnBeamIntegral:
                    if row == 0 {
                        if let e = beamStatePerAct.integral {
                            field = String(format: "%.1f", e.getFloatValue())
                        }
                    }
                case keyColumnVetoEvent:
                    if let eventNumber = vetoPerAct.itemAt(index: row)?.eventNumber {
                        field = currentFileEventNumber(eventNumber)
                    }
                case keyColumnVetoEnergy:
                    if let energy = vetoPerAct.itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnVetoStrip:
                    if let strip0_15 = vetoPerAct.itemAt(index: row)?.strip0_15 {
                        field = String(format: "%hu", strip0_15 + 1)
                    }
                case keyColumnVetoDeltaTime:
                    if let deltaTime = vetoPerAct.itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnFissionAlphaFront2Event:
                    field = fissionAlpha2EventNumber(row, side: .front)
                case keyColumnFissionAlphaFront2Sum:
                    field = fissionAlpha2Sum(row, side: .front)
                case keyColumnFissionAlphaFront2Energy:
                    field = fissionAlpha2Energy(row, side: .front)
                case keyColumnFissionAlphaFront2Marker:
                    field = fissionAlpha2Marker(row, side: .front)
                case keyColumnFissionAlphaFront2DeltaTime:
                    field = fissionAlpha2DeltaTime(row, side: .front)
                case keyColumnFissionAlphaFront2Strip:
                    field = fissionAlpha2Strip(row, side: .front)
                case keyColumnFissionAlphaBack2Sum:
                    field = fissionAlpha2Sum(row, side: .back)
                case keyColumnFissionAlphaBack2Energy:
                    field = fissionAlpha2Energy(row, side: .back)
                case keyColumnFissionAlphaBack2Marker:
                    field = fissionAlpha2Marker(row, side: .back)
                case keyColumnFissionAlphaBack2DeltaTime:
                    field = fissionAlpha2DeltaTime(row, side: .back)
                case keyColumnFissionAlphaBack2Strip:
                    field = fissionAlpha2Strip(row, side: .back)
                default:
                    break
                }
                logger.writeField(field as AnyObject, destination: .results)
            }
            logger.finishLine(.results)
        }
    }
    
    fileprivate func fissionAlpha2Match(_ row: Int, side: StripsSide) -> DetectorMatch? {
        if side == .back {
            return fissionsAlpha2PerAct.itemAt(index: row)?.subMatches?[criteria.secondParticleBackType] ?? nil
        } else {
            return fissionsAlpha2PerAct
        }
    }
    
    fileprivate func fissionAlpha2(_ row: Int, side: StripsSide) -> DetectorMatchItem? {
        let frontItem = fissionsAlpha2PerAct.itemAt(index: row)
        if side == .back {
            return frontItem?.subMatches?[criteria.secondParticleBackType]??.itemWithMaxEnergy()
        } else {
            return frontItem
        }
    }
    
    fileprivate func fissionAlpha2Sum(_ row: Int, side: StripsSide) -> String {
        if row == 0, let sum = fissionAlpha2Match(row, side: side)?.getSumEnergy() {
            return String(format: "%.7f", sum)
        } else {
            return ""
        }
    }
    
    fileprivate func fissionAlpha2EventNumber(_ row: Int, side: StripsSide) -> String {
        if let eventNumber = fissionAlpha2(row, side: side)?.eventNumber {
            return currentFileEventNumber(eventNumber)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Energy(_ row: Int, side: StripsSide) -> String {
        if let energy = fissionAlpha2(row, side: side)?.energy {
            return String(format: "%.7f", energy)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Marker(_ row: Int, side: StripsSide) -> String {
        if let marker = fissionAlpha2(row, side: side)?.marker {
            return String(format: "%hu", marker)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2DeltaTime(_ row: Int, side: StripsSide) -> String {
        if let deltaTime = fissionAlpha2(row, side: side)?.deltaTime {
            return String(format: "%lld", deltaTime)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Strip(_ row: Int, side: StripsSide) -> String {
        if let strip = fissionAlpha2(row, side: side)?.strip1_N {
            return String(format: "%d", strip)
        }
        return ""
    }
    
}

