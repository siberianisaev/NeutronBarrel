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
    fileprivate var neutrons_N_SummPerAct: CUnsignedLongLong = 0
    fileprivate var neutronsBackwardSummPerAct: CUnsignedLongLong = 0
    fileprivate var currentFileName: String?
    fileprivate var neutronsMultiplicityTotal = [Int: Int]()
    fileprivate var specialPerAct = [Int: CUnsignedShort]()
    fileprivate var beamStatePerAct = BeamState()
    fileprivate var fissionsAlphaPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var fissionsAlpha2PerAct = DoubleSidedStripDetectorMatch()
    fileprivate var recoilsPerAct = DoubleSidedStripDetectorMatch()
    fileprivate var fissionsAlphaWellPerAct = DoubleSidedStripDetectorSingleMatch()
    fileprivate var tofRealPerAct = DetectorMatch()
    fileprivate var tof2PerAct = DetectorMatch()
    fileprivate var vetoPerAct = DetectorMatch()
    fileprivate var gammaPerAct = DetectorMatch()
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
        
        neutronsMultiplicityTotal = [:]
        totalEventNumber = 0
        clearActInfo()
        
        logger = Logger(folder: criteria.resultsFolderName)
        logInput(onEnd: false)
        logCalibration()
        logResultsHeader()
        
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
        if criteria.searchNeutrons {
            logger.logMultiplicity(neutronsMultiplicityTotal)
        }
        
        print("\nDone!\nTotal time took: \((NSApplication.shared.delegate as! AppDelegate).timeTook())")
    }
    
    class func calculateTotalEventNumberForFile(_ file: UnsafeMutablePointer<FILE>!) -> CUnsignedLongLong {
        fseek(file, 0, SEEK_END)
        var lastNumber = fpos_t()
        fgetpos(file, &lastNumber)
        return CUnsignedLongLong(lastNumber)/CUnsignedLongLong(Event.size)
    }
    
    fileprivate func mainCycleEventCheck(_ event: Event, folder: FolderStatistics) {
        if dataProtocol.isCycleTimeEvent(Int(event.eventId)) {
            currentCycle += 1
        } else if isFront(event, type: criteria.startParticleType) {
            startEventTime = UInt64(event.param1)
            
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
                storeFissionAlphaFront(event, deltaTime: 0)
            }
            
            var p = fpos_t()
            fgetpos(file, &p)
            let position = Int(p)
            
            if criteria.searchVETO {
                findVETO()
                fseek(file, position, SEEK_SET)
                if criteria.requiredVETO && 0 == vetoPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            if !criteria.searchExtraFromParticle2 {
                findGamma(position)
                if criteria.requiredGamma && 0 == gammaPerAct.count {
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
                    findFissionsAlphaWell(position)
                }
            }
            
            if criteria.searchFissionAlpha2 {
                findFissionAlpha2()
                fseek(file, position, SEEK_SET)
                let match = fissionsAlpha2PerAct
                if 0 == match.matchFor(side: .front).count || (criteria.requiredFissionAlphaBack && 0 == match.matchFor(side: .back).count) {
                    clearActInfo()
                    return
                }
                if criteria.searchExtraFromParticle2 && criteria.requiredGamma && 0 == gammaPerAct.count {
                    clearActInfo()
                    return
                }
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
    
    fileprivate func findFissionsAlphaWell(_ position: Int) {
        if criteria.searchWell {
            let directions: Set<SearchDirection> = [.backward, .forward]
            let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
            search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                for side in [.front, .back] as [StripsSide] {
                    if self.isFissionOrAlphaWell(event, side: side) {
                        self.storeFissionAlphaWell(event, side: side)
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
                self.neutrons_N_SummPerAct += 1
            }
        }
    }
    
    fileprivate func findNeutronsBack() {
        let directions: Set<SearchDirection> = [.backward]
        let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
        search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: 10, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.dataProtocol.isNeutronsEvent(Int(event.eventId)) {
                self.neutronsBackwardSummPerAct += 1
            }
        }
    }
    
    fileprivate func findNextFissionsAlphaFront(_ folder: FolderStatistics) {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, useCycleTime: false, updateCycle: true) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.isFront(event, type: self.criteria.startParticleType) && self.isFissionStripNearToFirstFissionFront(event) {
                self.storeFissionAlphaFront(event, deltaTime: deltaTime)
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
    
    fileprivate func findGamma(_ position: Int) {
        let directions: Set<SearchDirection> = [.forward, .backward]
        let start = criteria.searchExtraFromParticle2 ? secondEventTime : startEventTime
        search(directions: directions, startTime: start, minDeltaTime: 0, maxDeltaTime: criteria.maxGammaTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.isGammaEvent(event) {
                self.storeGamma(event, deltaTime: deltaTime)
            }
        }
        fseek(file, position, SEEK_SET)
    }
    
    fileprivate func findFissionAlphaBack() {
        let match = fissionsAlphaPerAct
        let type = criteria.startParticleBackType
        let directions: Set<SearchDirection> = [.backward, .forward]
        search(directions: directions, startTime: startEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.isBack(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if self.criteria.searchFissionAlphaBackByFact || (energy >= self.criteria.fissionAlphaBackMinEnergy && energy <= self.criteria.fissionAlphaBackMaxEnergy) {
                    self.storeFissionAlphaRecoilBack(event, match: match, type: type, deltaTime: deltaTime)
                }
            }
        }
        match.matchFor(side: .back).filterItemsByMaxEnergy(maxStripsDelta: criteria.recoilBackMaxDeltaStrips)
    }
    
    fileprivate func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(startEventTime), cycle: currentCycle)
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: criteria.recoilMinTime, maxDeltaTime: criteria.recoilMaxTime, useCycleTime: true, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            let isRecoil = self.isFront(event, type: self.criteria.recoilType)
            if isRecoil {
                let isNear = self.isEventStripNearToFirstFissionAlpha(event, maxDelta: Int(self.criteria.recoilFrontMaxDeltaStrips), side: .front)
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
            
            let isTOFFounded = self.findTOFForRecoil(event, timeRecoil: t, kind: .TOF)
            fseek(self.file, Int(position), SEEK_SET)
            var isTOF2Founded = false
            if criteria.useTOF2 {
                isTOF2Founded = self.findTOFForRecoil(event, timeRecoil: t, kind: .TOF2)
                fseek(self.file, Int(position), SEEK_SET)
            }
            if (criteria.requiredTOF && !(isTOFFounded || isTOF2Founded)) {
                return false
            }
            
            let found = findRecoilBack(t, position: Int(position))
            if (!found && criteria.requiredRecoilBack) {
                return false
            }
            
            let heavy = self.getEnergy(event, type: criteria.heavyType)
            self.storeRecoil(event, energy: energy, heavy: heavy, deltaTime: deltaTime)
            return true
        }
        return false
    }
    
    fileprivate func findTOFForRecoil(_ eventRecoil: Event, timeRecoil: CUnsignedLongLong, kind: TOFKind) -> Bool {
        var found: Bool = false
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: timeRecoil, minDeltaTime: 0, maxDeltaTime: criteria.maxTOFTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if let k = self.dataProtocol.isTOFEvent(Int(event.eventId)), k == kind {
                let value = self.valueTOF(event, eventRecoil: eventRecoil)
                if value >= self.criteria.minTOFValue && value <= self.criteria.maxTOFValue {
                    self.storeRealTOFValue(value, deltaTime: deltaTime, kind: k)
                    found = true
                    stop.initialize(to: true)
                }
            }
        }
        return found
    }
    
    fileprivate func findRecoilBack(_ timeRecoilFront: CUnsignedLongLong, position: Int) -> Bool {
        var found: Bool = false
        let directions: Set<SearchDirection> = [.backward, .forward]
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: criteria.recoilBackMaxTime, maxDeltaTimeBackward: criteria.recoilBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            // Note: 'recoil' type must be always
            let type: SearchType = .recoil
            if self.isBack(event, type: type) {
                var store = self.criteria.searchRecoilBackByFact
                if !store {
                    let energy = self.getEnergy(event, type: type)
                    if energy >= self.criteria.recoilBackMinEnergy && energy <= self.criteria.recoilBackMaxEnergy {
                        if !self.criteria.startFromRecoil() {
                            store = self.isRecoilBackStripNearToFissionAlphaBack(event)
                        } else {
                            store = true
                        }
                    }
                }
                if store {
                    found = true
                    self.storeFissionAlphaRecoilBack(event, match: self.recoilsPerAct, type: type, deltaTime: deltaTime)
                }
            }
        }
        fseek(self.file, Int(position), SEEK_SET)
        recoilsPerAct.matchFor(side: .back).keepOnlyItemWithMaxEnergy()
        return found
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
                if self.isEventStripNearToFirstFissionAlpha(event, maxDelta: Int(self.criteria.fissionAlpha2MaxDeltaStrips), side: .front) && ((!isFront && self.criteria.searchFissionAlphaBack2ByFact) || (energy >= self.criteria.fissionAlpha2MinEnergy && energy <= self.criteria.fissionAlpha2MaxEnergy)) {
                    self.storeFissionAlpha2(event, type: t, deltaTime: deltaTime)
                    // Recoil Back
                    self.findFissionAlpha2Back(position)
                    // Extra Search
                    if self.criteria.searchExtraFromParticle2 {
                        self.findFissionsAlphaWell(position)
                        self.findGamma(position)
                        self.findAllNeutrons(position)
                    }
                }
            }
        }
    }
    
    fileprivate func findFissionAlpha2Back(_ position: Int) {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: secondEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = self.criteria.secondParticleBackType
            let isBack = self.isBack(event, type: t)
            if isBack {
                var store = self.criteria.searchFissionAlphaBack2ByFact
                if !store {
                    let energy = self.getEnergy(event, type: t)
                    if self.isEventStripNearToFirstFissionAlpha(event, maxDelta: Int(self.criteria.fissionAlpha2MaxDeltaStrips), side: .back) && (energy >= self.criteria.fissionAlpha2BackMinEnergy && energy <= self.criteria.fissionAlpha2BackMaxEnergy) {
                        store = true
                    }
                }
                if store {
                    self.storeFissionAlphaRecoilBack(event, match: self.fissionsAlpha2PerAct, type: t, deltaTime: deltaTime)
                }
            }
        }
        fseek(file, position, SEEK_SET)
        fissionsAlpha2PerAct.matchFor(side: .back).filterItemsByMaxEnergy(maxStripsDelta: criteria.fissionAlpha2MaxDeltaStrips)
    }
    
    // MARK: - Storage
    
    fileprivate func storeFissionAlphaRecoilBack(_ event: Event, match: DoubleSidedStripDetectorMatch, type: SearchType, deltaTime: CLongLong) {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: type)
        let side: StripsSide = .back
        let item = DetectorMatchItem(stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: getMarker(event))
        match.append(item, side: side)
    }
    
    /**
     Summar multiplicity of neutrons calculation over all files
     */
    fileprivate func updateNeutronsMultiplicity() {
        let key = neutronsPerAct.count
        var summ = neutronsMultiplicityTotal[Int(key)] ?? 0
        summ += 1 // One event for all neutrons in one act of fission
        neutronsMultiplicityTotal[Int(key)] = summ
    }
    
    fileprivate func storeFissionAlphaFront(_ event: Event, deltaTime: CLongLong) {
        let id = event.eventId
        let channel = getChannel(event, type: criteria.startParticleType)
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: criteria.startParticleType)
        let side: StripsSide = .front
        let item = DetectorMatchItem(stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: getMarker(event),
                                     channel: channel)
        fissionsAlphaPerAct.append(item, side: side)
    }
    
    fileprivate func storeGamma(_ event: Event, deltaTime: CLongLong) {
        let channel = Double(event.param3 & Mask.gamma.rawValue)
        let eventId = Int(event.eventId)
        let encoder = dataProtocol.encoderForEventId(eventId)
        let energy: Double
        if calibration.hasData() {
            energy = calibration.calibratedValueForAmplitude(channel, type: .gamma, eventId: eventId, encoder: encoder, strip0_15: nil, dataProtocol: dataProtocol)
        } else {
            energy = channel
        }
        let item = DetectorMatchItem(stripDetector: nil,
                                     energy: energy,
                                     encoder: encoder,
                                     deltaTime: deltaTime)
        gammaPerAct.append(item)
    }
    
    fileprivate func storeRecoil(_ event: Event, energy: Double, heavy: Double, deltaTime: CLongLong) {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let item = DetectorMatchItem(stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: getMarker(event),
                                     heavy: heavy)
        recoilsPerAct.append(item, side: .front)
    }
    
    fileprivate func storeFissionAlpha2(_ event: Event, type: SearchType, deltaTime: CLongLong) {
        let id = event.eventId
        let encoder = dataProtocol.encoderForEventId(Int(id))
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: type)
        let side: StripsSide = .front
        let item = DetectorMatchItem(stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     marker: getMarker(event))
        fissionsAlpha2PerAct.append(item, side: side)
    }
    
    fileprivate func storeRealTOFValue(_ value: Double, deltaTime: CLongLong, kind: TOFKind) {
        let item = DetectorMatchItem(stripDetector: nil,
                                     deltaTime: deltaTime,
                                     value: value)
        kind == .TOF ? tofRealPerAct.append(item) : tof2PerAct.append(item)
    }
    
    fileprivate func storeVETO(_ event: Event, deltaTime: CLongLong) {
        let strip0_15 = event.param2 >> 12
        let energy = getEnergy(event, type: .veto)
        let item = DetectorMatchItem(stripDetector: nil,
                                     energy: energy,
                                     strip0_15: strip0_15,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime)
        vetoPerAct.append(item)
    }
    
    fileprivate func storeFissionAlphaWell(_ event: Event, side: StripsSide) {
        let type = side == .front ? (criteria.searchExtraFromParticle2 ? criteria.secondParticleFrontType : criteria.startParticleType) : criteria.wellParticleBackType
        let energy = getEnergy(event, type: type)
        if let e = fissionsAlphaWellPerAct.itemFor(side: side)?.energy, e >= energy { // Store only well event with max energy
            return
        }
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip0_15 = event.param2 >> 12
        let item = DetectorMatchItem(stripDetector: .side,
                                     energy: energy,
                                     encoder: encoder,
                                     strip0_15: strip0_15,
                                     marker: getMarker(event))
        fissionsAlphaWellPerAct.setItem(item, forSide: side)
    }
    
    fileprivate func storeSpecial(_ event: Event, id: Int) {
        let channel = event.param3 & Mask.special.rawValue
        specialPerAct[id] = channel
    }
    
    fileprivate func clearActInfo() {
        neutronsPerAct.removeAll()
        neutrons_N_SummPerAct = 0
        neutronsBackwardSummPerAct = 0
        fissionsAlphaPerAct.removeAll()
        gammaPerAct.removeAll()
        specialPerAct.removeAll()
        beamStatePerAct.clean()
        fissionsAlphaWellPerAct.removeAll()
        recoilsPerAct.removeAll()
        fissionsAlpha2PerAct.removeAll()
        tofRealPerAct.removeAll()
        tof2PerAct.removeAll()
        vetoPerAct.removeAll()
    }
    
    // MARK: - Helpers
    
    fileprivate func isEventStripNearToFirstFissionAlpha(_ event: Event, maxDelta: Int, side: StripsSide) -> Bool {
        let strip0_15 = event.param2 >> 12
        let encoder = dataProtocol.encoderForEventId(Int(event.eventId))
        let strip1_N = stripsConfiguration(detector: .focal).strip1_N_For(side: side, encoder: Int(encoder), strip0_15: strip0_15)
        if let s = fissionsAlphaPerAct.firstItemsFor(side: side)?.strip1_N {
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
        return !isRecoil(event) && ((side == .front && dataProtocol.isAlphaWellEvent(eventId)) || (side == .back && dataProtocol.isAlphaWellBackEvent(eventId)))
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
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let image = appDelegate.window.screenshot()
        logger.logInput(image, onEnd: onEnd)
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
    fileprivate var keyRecoilHeavy: String {
        return criteria.heavyType == .heavy ? "HR" : "R"
    }
    fileprivate var keyColumnRecoilFrontHeavyEnergy: String {
        return "E(\(keyRecoilHeavy)Fron)"
    }
    fileprivate let keyColumnRecoilBackEvent: String = "Event(RBack)"
    fileprivate let keyColumnRecoilBackEnergy: String = "E(RBack)"
    fileprivate var keyColumnTof = "TOF"
    fileprivate var keyColumnTof2 = "TOF2"
    fileprivate var keyColumnTofDeltaTime = "dT(TOF-RFron)"
    fileprivate var keyColumnTof2DeltaTime = "dT(TOF2-RFron)"
    fileprivate var keyColumnStartEvent = "Event($)"
    fileprivate var keyColumnStartFrontSumm = "Summ($Fron)"
    fileprivate var keyColumnStartFrontEnergy = "$Fron"
    fileprivate var keyColumnStartFrontMarker = "$FronMarker"
    fileprivate var keyColumnStartFrontDeltaTime = "dT($FronFirst-Next)"
    fileprivate var keyColumnStartFrontStrip = "Strip($Fron)"
    fileprivate var keyColumnStartFocalPositionXYZ = "StartFocalPositionXYZ"
    fileprivate var keyColumnStartBackSumm = "Summ(@Back)"
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
    fileprivate var keyColumnGammaEnergy: String {
        return searchExtraPostfix("Gamma")
    }
    fileprivate var keyColumnGammaEncoder = "GammaEncoder"
    fileprivate var keyColumnGammaDeltaTime = "dT($Fron-Gamma)"
    fileprivate var keyColumnGammaCount = "GammaCount"
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
    fileprivate var keyColumnFissionAlphaFront2Summ = "Summ(&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Event = "Event(&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Energy = "E(&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Marker = "&Front2Marker"
    fileprivate var keyColumnFissionAlphaFront2DeltaTime = "dT($Front1-&Front2)"
    fileprivate var keyColumnFissionAlphaFront2Strip = "Strip(&Front2)"
    fileprivate var keyColumnFissionAlphaBack2Summ = "Summ(^Back2)"
    fileprivate var keyColumnFissionAlphaBack2Energy = "^Back2"
    fileprivate var keyColumnFissionAlphaBack2Marker = "^Back2Marker"
    fileprivate var keyColumnFissionAlphaBack2DeltaTime = "dT(&Fron1-^Back2)"
    fileprivate var keyColumnFissionAlphaBack2Strip = "Strip(^Back2)"
    
    fileprivate func logResultsHeader() {
        columns = [
            keyColumnRecoilFrontEvent,
            keyColumnRecoilFrontEnergy,
            keyColumnRecoilFrontHeavyEnergy,
            keyColumnRecoilFrontFrontMarker,
            keyColumnRecoilFrontDeltaTime,
            keyColumnRecoilBackEvent,
            keyColumnRecoilBackEnergy,
            keyColumnTof,
            keyColumnTofDeltaTime
        ]
        if criteria.useTOF2 {
            columns.append(contentsOf: [
                keyColumnTof2,
                keyColumnTof2DeltaTime,
            ])
        }
        columns.append(contentsOf: [
            keyColumnStartEvent,
            keyColumnStartFrontSumm,
            keyColumnStartFrontEnergy,
            keyColumnStartFrontMarker,
            keyColumnStartFrontDeltaTime,
            keyColumnStartFrontStrip,
            keyColumnStartFocalPositionXYZ,
            keyColumnStartBackSumm,
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
            keyColumnGammaEnergy,
            keyColumnGammaEncoder,
            keyColumnGammaDeltaTime,
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
                columns.append(keyColumnFissionAlphaFront2Summ)
            }
            columns.append(contentsOf: [
                keyColumnFissionAlphaFront2Energy,
                keyColumnFissionAlphaFront2Marker,
                keyColumnFissionAlphaFront2DeltaTime,
                keyColumnFissionAlphaFront2Strip,
                keyColumnFissionAlphaBack2Summ,
                keyColumnFissionAlphaBack2Energy,
                keyColumnFissionAlphaBack2Marker,
                keyColumnFissionAlphaBack2DeltaTime,
                keyColumnFissionAlphaBack2Strip
                ])
        }
        
        // TODO: incapsulate in SearchType
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
        let headers = columns.map { (s: String) -> String in
            var result = s
            for (key, value) in dict {
                result = result.replacingOccurrences(of: key, with: value)
            }
            return result
        } as [AnyObject]
        logger.writeResultsLineOfFields(headers)
        logger.finishResultsLine() // +1 line padding
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
    
    fileprivate var currentStartEventNumber: CUnsignedLongLong?
    
    fileprivate func logActResults() {
        let rowsMax = max(max(max(max(1, [gammaPerAct, vetoPerAct].max(by: { $0.count < $1.count })!.count), fissionsAlphaPerAct.count), recoilsPerAct.count), neutronsCountWithNewLine())
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
                case keyColumnRecoilFrontHeavyEnergy:
                    if let heavy = recoilsPerAct.matchFor(side: .front).itemAt(index: row)?.heavy {
                        field = String(format: "%.7f", heavy)
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
                    if let value = (column == keyColumnTof ? tofRealPerAct : tof2PerAct).itemAt(index: row)?.value {
                        let format = "%." + (criteria.unitsTOF == .channels ? "0" : "7") + "f"
                        field = String(format: format, value)
                    }
                case keyColumnTofDeltaTime, keyColumnTof2DeltaTime:
                    if let deltaTime = (column == keyColumnTofDeltaTime ? tofRealPerAct : tof2PerAct).itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartEvent:
                    if let eventNumber = fissionsAlphaPerAct.matchFor(side: .front).itemAt(index: row)?.eventNumber {
                        field = currentFileEventNumber(eventNumber)
                        currentStartEventNumber = eventNumber
                    } else if row < neutronsCountWithNewLine(), let eventNumber = currentStartEventNumber { // Need track start event number for neutron times results
                        field = currentFileEventNumber(eventNumber)
                    }
                case keyColumnStartFrontSumm:
                    if row == 0, !criteria.startFromRecoil(), let summ = fissionsAlphaPerAct.matchFor(side: .front).getSummEnergyFrom() {
                        field = String(format: "%.7f", summ)
                    }
                case keyColumnStartFrontEnergy:
                    if let energy = fissionsAlphaPerAct.matchFor(side: .front).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartFrontMarker:
                    if let marker = fissionsAlphaPerAct.matchFor(side: .front).itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnStartFrontDeltaTime:
                    if let deltaTime = fissionsAlphaPerAct.matchFor(side: .front).itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartFrontStrip:
                    if let strip = (criteria.startFromRecoil() ? recoilsPerAct : fissionsAlphaPerAct).matchFor(side: .front).itemAt(index: row)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnStartFocalPositionXYZ:
                    let matches = criteria.startFromRecoil() ? recoilsPerAct : fissionsAlphaPerAct
                    if let itemFront = matches.matchFor(side: .front).itemAt(index: row), let stripFront1 = itemFront.strip1_N, let itemBack = matches.matchFor(side: .back).itemAt(index: row), let stripBack1 = itemBack.strip1_N {
                        let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0: stripFront1 - 1, stripBack0: stripBack1 - 1)
                        field = String(format: "%.1f|%.1f|%.1f", point.x, point.y, point.z)
                    }
                case keyColumnStartBackSumm:
                    if row == 0, !criteria.startFromRecoil(), let summ = fissionsAlphaPerAct.matchFor(side: .back).getSummEnergyFrom() {
                        field = String(format: "%.7f", summ)
                    }
                case keyColumnStartBackEnergy:
                    let side: StripsSide = .back
                    let match = criteria.startFromRecoil() ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let energy = match.itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartBackMarker:
                    let side: StripsSide = .back
                    let match = criteria.startFromRecoil() ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let marker = match.itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnStartBackDeltaTime:
                    let side: StripsSide = .back
                    let match = criteria.startFromRecoil() ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
                    if let deltaTime = match.itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartBackStrip:
                    let side: StripsSide = .back
                    let match = criteria.startFromRecoil() ? recoilsPerAct.matchFor(side: side) : fissionsAlphaPerAct.matchFor(side: side)
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
                    let matchesFocal = criteria.startFromRecoil() ? recoilsPerAct : fissionsAlphaPerAct
                    if row == 0, let itemFocalFront = matchesFocal.matchFor(side: .front).itemAt(index: row), let stripFocalFront1 = itemFocalFront.strip1_N, let itemFocalBack = matchesFocal.matchFor(side: .back).itemAt(index: row), let stripFocalBack1 = itemFocalBack.strip1_N, let itemSideFront = fissionsAlphaWellPerAct.itemFor(side: .front), let stripSideFront0 = itemSideFront.strip0_15, let itemSideBack = fissionsAlphaWellPerAct.itemFor(side: .back), let stripSideBack0 = itemSideBack.strip0_15, let encoderSide = itemSideFront.encoder {
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
                        field = String(format: "%llu", neutrons_N_SummPerAct)
                    }
                case keyColumnNeutronsBackward:
                    if row == 0 {
                        field = String(format: "%llu", neutronsBackwardSummPerAct)
                    }
                case keyColumnGammaEnergy:
                    if let energy = gammaPerAct.itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnGammaEncoder:
                    if let encoder = gammaPerAct.itemAt(index: row)?.encoder {
                        field = String(format: "%hu", encoder)
                    }
                case keyColumnGammaDeltaTime:
                    if let deltaTime = gammaPerAct.itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnGammaCount:
                    if row == 0 {
                        field = String(format: "%d", gammaPerAct.count)
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
                case keyColumnFissionAlphaFront2Summ:
                    field = fissionAlpha2Summ(row, side: .front)
                case keyColumnFissionAlphaFront2Energy:
                    field = fissionAlpha2Energy(row, side: .front)
                case keyColumnFissionAlphaFront2Marker:
                    field = fissionAlpha2Marker(row, side: .front)
                case keyColumnFissionAlphaFront2DeltaTime:
                    field = fissionAlpha2DeltaTime(row, side: .front)
                case keyColumnFissionAlphaFront2Strip:
                    field = fissionAlpha2Strip(row, side: .front)
                case keyColumnFissionAlphaBack2Summ:
                    field = fissionAlpha2Summ(row, side: .back)
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
                logger.writeResultsField(field as AnyObject)
            }
            logger.finishResultsLine()
        }
    }
    
    fileprivate func fissionAlpha2Summ(_ row: Int, side: StripsSide) -> String {
        if row == 0, let summ = fissionsAlpha2PerAct.matchFor(side: side).getSummEnergyFrom() {
            return String(format: "%.7f", summ)
        } else {
            return ""
        }
    }
    
    fileprivate func fissionAlpha2EventNumber(_ row: Int, side: StripsSide) -> String {
        if let eventNumber = fissionsAlpha2PerAct.matchFor(side: side).itemAt(index: row)?.eventNumber {
            return currentFileEventNumber(eventNumber)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Energy(_ row: Int, side: StripsSide) -> String {
        if let energy = fissionsAlpha2PerAct.matchFor(side: side).itemAt(index: row)?.energy {
            return String(format: "%.7f", energy)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Marker(_ row: Int, side: StripsSide) -> String {
        if let marker = fissionsAlpha2PerAct.matchFor(side: side).itemAt(index: row)?.marker {
            return String(format: "%hu", marker)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2DeltaTime(_ row: Int, side: StripsSide) -> String {
        if let deltaTime = fissionsAlpha2PerAct.matchFor(side: side).itemAt(index: row)?.deltaTime {
            return String(format: "%lld", deltaTime)
        }
        return ""
    }
    
    fileprivate func fissionAlpha2Strip(_ row: Int, side: StripsSide) -> String {
        if let strip = fissionsAlpha2PerAct.matchFor(side: side).itemAt(index: row)?.strip1_N {
            return String(format: "%d", strip)
        }
        return ""
    }
    
}

