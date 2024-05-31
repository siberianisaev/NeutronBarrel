//
//  Processor.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import Cocoa

extension UInt64 {
    
    // 1 cycle is 8 ns
    mutating func mksToCycles() {
        self *= 125
    }
    
    func toMks() -> Double {
        return Double(self) / 125.0
    }
    
}

// TODO: refactor it
extension CLongLong {
    
    func toMks() -> Double {
        return Double(self) / 125.0
    }
    
}

// TODO: refactor it
extension Float {
    
    func toMks() -> Double {
        return Double(self) / 125.0
    }
    
}

extension Event {
    
    // TODO: need custom fread with it to call in all places
    mutating func bigEndian() {
        self.eventId = self.eventId.bigEndian
        self.energy = self.energy.bigEndian
        self.overflow = self.overflow.bigEndian
        self.pileUp = self.pileUp.bigEndian
        self.inBeam = self.inBeam.bigEndian
        self.tof = self.tof.bigEndian
        self.time = self.time.bigEndian
    }

    func getChannelFor(type: SearchType) -> CUnsignedShort {
        return self.energy // (type == .fission || type == .heavy) ? (param2 & Mask.heavyOrFission.rawValue) : (param3 & Mask.recoilOrAlpha.rawValue)
    }

}

protocol ProcessorDelegate: AnyObject {
    
    func startProcessingFile(_ name: String?)
    func endProcessingFile(_ name: String?, correlationsFound: CUnsignedLongLong)
    
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
    
    fileprivate var stoped = false
    fileprivate var logger: Logger!
    fileprivate var resultsTable: ResultsTable!
    
    fileprivate var calibration: Calibration {
        return Calibration.singleton
    }
    
    fileprivate func stripsConfiguration() -> StripsConfiguration {
        return criteria.stripsConfiguration
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
            event.bigEndian()
            
            var stop: Bool = false
            checker(event, &stop)
            if stop {
                return
            }
        }
    }
    
    fileprivate func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, maxDeltaTimeBackward: CUnsignedLongLong? = nil, checkMaxDeltaTimeExceeded: Bool = true, checker: @escaping ((Event, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>, Int)->())) {
        //TODO: search over many files
        let maxBackward = maxDeltaTimeBackward ?? maxDeltaTime
        if directions.contains(.backward) {
            var initial = fpos_t()
            fgetpos(file, &initial)

            var current = Int(initial)
            while current > -1 {
                let size = Event.size
                current -= size
                fseek(file, current, SEEK_SET)

                var event = Event()
                fread(&event, size, 1, file)
                event.bigEndian()

                let time = event.time
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

            fseek(file, Int(initial), SEEK_SET)
        }

        if directions.contains(.forward) {
            while feof(file) != 1 {
                var event = Event()
                fread(&event, Event.size, 1, file)
                event.bigEndian()

                let time = event.time
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

        var fileStats = [String: FileStatistics]()

        for fp in files {
            let path = fp as NSString
            let fileName = FileStatistics.fileNameFromPath(fp) ?? ""
            let fileStat = FileStatistics(fileName: fileName)
            fileStats[fileName] = fileStat
            fileStat.startFile(fp)

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
                            self?.mainCycleEventCheck(event, fileStat: fileStat)
                        }
                    })
                } else {
                    exit(-1)
                }

                totalEventNumber += Processor.calculateTotalEventNumberForFile(file)
                fclose(file)
                fileStat.endFile(fp, correlationsPerFile: correlationsPerFile)

                filesFinishedCount += 1
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.endProcessingFile(self?.currentFileName, correlationsFound: self?.correlationsPerFile ?? 0)
                    self?.correlationsPerFile = 0
                }
            }
        }

        logInput(onEnd: true)
        logger.logStatistics(fileStats)
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

    fileprivate func mainCycleEventCheck(_ event: Event, fileStat: FileStatistics) {
        fileStat.handleEvent(event)
        
        if isFront(event, type: criteria.startParticleType) {
            firstParticlePerAct.currentEventTime = event.time

            let inBeam = isInBeam(event)
            if criteria.inBeamOnly && !inBeam {
                clearActInfo()
                return
            }
            if criteria.outBeamOnly && inBeam {
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
                let energy = getEnergy(event)
                if !isOverflowed(event) && (energy < criteria.fissionAlphaFrontMinEnergy || energy > criteria.fissionAlphaFrontMaxEnergy) {
                    clearActInfo()
                    return
                }
                
                if !criteria.usePileUp && event.pileUp == 1 {
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

            if !isRecoilSearch {
                findFissionAlphaBack()
                fseek(file, position, SEEK_SET)
                if criteria.requiredFissionAlphaBack && 0 == fissionsAlphaPerAct.matchFor(side: .back).count {
                    clearActInfo()
                    return
                }

                // Search them only after search all FBack/ABack
                if criteria.searchRecoils {
                    findRecoil()
                    fseek(file, position, SEEK_SET)
                    if criteria.requiredRecoil && 0 == recoilsPerAct.matchFor(side: .front).count {
                        clearActInfo()
                        return
                    }
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

                    if criteria.next[4] != nil {
                        findFissionAlpha(4)
                        fseek(file, position, SEEK_SET)
                        guard let match = fissionsAlphaNextPerAct[4], match.matchFor(side: .front).count > 0 else {
                            clearActInfo()
                            return
                        }
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

            if criteria.trackBeamState {
                findBeamEvents()
            }
            fseek(file, position, SEEK_SET)

            // Important: this search must be last because we don't do file repositioning here
            // Sum(FFron or AFron)
            if !isRecoilSearch && criteria.summarizeFissionsAlphaFront {
                findAllFirstFissionsAlphaFront(fileStat)
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
            updateFileStatistics(event, fileStat: fileStat)
        }
    }

    fileprivate func wellSearchFailed() -> Bool {
        return criteria.searchWell && criteria.requiredWell && fissionsAlphaWellPerAct.matchFor(side: .front).count == 0
    }

    fileprivate func updateFileStatistics(_ event: Event, fileStat: FileStatistics) {
        let id = Int(event.eventId)
        if dataProtocol.isBeamEnergy(id) {
            let e = Float(event.energy) / 10.0
            fileStat.handleEnergy(e)
        } else if dataProtocol.isBeamIntegral(id) {
            let i = Float(event.energy) * 10.0
            fileStat.handleIntergal(i)
        } else if dataProtocol.isBeamCurrent(id) {
            let c = Float(event.energy) / 1000.0
            fileStat.handleCurrent(c)
        } else if dataProtocol.isBeamBackground(id) {
            let c = Float(event.energy)
            fileStat.handleBackground(c)
        }
    }

    fileprivate func findFissionAlphaWell(_ position: Int) {
        if criteria.searchWell {
            let directions: Set<SearchDirection> = [.backward, .forward]
            search(directions: directions, startTime: currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                for side in [.front, .back] as [StripsSide] {
                    if self.isFissionOrAlphaWell(event, side: side) {
                        self.filterAndStoreFissionAlphaWell(event, side: side, deltaTime: deltaTime)
                    }
                }
            }
            fseek(file, position, SEEK_SET)
        }
    }

    fileprivate func checkIsSimultaneousDecay(_ event: Event, deltaTime: CLongLong) -> Bool {
        if criteria.simultaneousDecaysFilterForNeutrons && isBack(event, type: .alpha) && abs(deltaTime) > criteria.fissionAlphaMaxTime {
            let energy = getEnergy(event)
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
            search(directions: directions, startTime: startTime, minDeltaTime: criteria.minNeutronTime, maxDeltaTime: maxDeltaTime, maxDeltaTimeBackward: criteria.maxNeutronBackwardTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                let id = Int(event.eventId)
                // 1) Simultaneous Decays Filter - search the events with fragment energy at the same time with current decay.
                if self.checkIsSimultaneousDecay(event, deltaTime: deltaTime) {
                    excludeSFEvent = true
                    self.neutronsMultiplicity?.incrementBroken()
                    stop.initialize(to: true)
                } else if abs(deltaTime) < maxDeltaTime {
                    // 3) Store neutron info.
                    if self.dataProtocol.isNeutronsNewEvent(id) {
                        let neutronTime = event.time
                        let isNeutronsBkg = self.criteria.neutronsBackground
                        if (!isNeutronsBkg && neutronTime >= startTime) || (isNeutronsBkg && neutronTime < startTime) { // Effect neutrons must be after SF by time
                            let counterNumber = self.stripsConfiguration().strip1_N_For(channel: CUnsignedShort(id))
                            var validNeutron = true
                            if self.criteria.excludeNeutronCounters.contains(counterNumber) {
                                validNeutron = false
                            } else if self.criteria.collapseNeutronOverlays {
                                validNeutron = !self.neutronsPerAct.counters.contains(counterNumber)
                            }
                            if validNeutron {
                                self.neutronsPerAct.counters.append(counterNumber)
                                self.neutronsPerAct.times.append(Float(deltaTime))
                            }
                        }
                    }
                }
            }
            fseek(file, Int(position), SEEK_SET)
        }
        return excludeSFEvent
    }

    fileprivate func findAllFirstFissionsAlphaFront(_ fileStat: FileStatistics) {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: firstParticlePerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.isFront(event, type: self.criteria.startParticleType) && self.isFissionStripNearToFirstFissionFront(event) {
                self.storeFissionAlphaFront(event, deltaTime: deltaTime, subMatches: nil)
            } else {
                self.updateFileStatistics(event, fileStat: fileStat)
            }
        }
    }

    fileprivate func findGamma(_ position: Int) -> DetectorMatch? {
        let match = DetectorMatch()
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.maxGammaTime, maxDeltaTimeBackward: criteria.maxGammaBackwardTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.isGammaEvent(event), let item = self.gammaMatchItem(event, deltaTime: deltaTime) {
                match.append(item)
            }
        }
        fseek(file, position, SEEK_SET)
        return match.count > 0 ? match : nil
    }

    fileprivate func findFissionAlphaBack() {
        let match = fissionsAlphaPerAct
        let type = SearchType.alpha
        let directions: Set<SearchDirection> = [.backward, .forward]
        let byFact = self.criteria.searchFissionAlphaBackByFact
        search(directions: directions, startTime: firstParticlePerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.isBack(event, type: type) {
                var store = byFact
                if !store {
                    let energy = self.getEnergy(event)
                    store = self.isOverflowed(event) || energy >= self.criteria.fissionAlphaBackMinEnergy && energy <= self.criteria.fissionAlphaBackMaxEnergy
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
        let fissionTime = firstParticlePerAct.currentEventTime
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: criteria.recoilMinTime, maxDeltaTime: criteria.recoilMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            let isRecoil = self.isFront(event, type: SearchType.recoil)
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
        if !self.criteria.usePileUp && event.pileUp == 1 {
            return false
        }

        let energy = self.getEnergy(event)
        if energy >= criteria.recoilFrontMinEnergy && energy <= criteria.recoilFrontMaxEnergy {
            var position = fpos_t()
            fgetpos(self.file, &position)
            let t = event.time

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
            self.storeRecoil(event, energy: energy, deltaTime: deltaTime, subMatches: subMatches)
            return true
        }
        return false
    }

    fileprivate func findRecoilBack(_ timeRecoilFront: CUnsignedLongLong, position: Int) -> Bool {
        var items = [DetectorMatchItem]()
        let side: StripsSide = .back
        let directions: Set<SearchDirection> = [.backward, .forward]
        let byFact = self.criteria.searchRecoilBackByFact
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: criteria.recoilBackMaxTime, maxDeltaTimeBackward: criteria.recoilBackBackwardMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            let type: SearchType = .recoil
            if self.isBack(event, type: type) {
                var store = self.criteria.startFromRecoil() || self.isRecoilBackStripNearToFissionAlphaBack(event)
                if !byFact && store {
                    let energy = self.getEnergy(event)
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
        // TODO: did more clear logic in case of recoil search disabled, and implement findFissionAlpha(1)
        let startTime = index <= 2 ? firstParticlePerAct.currentEventTime : (fissionsAlphaNextPerAct[index-1]?.currentEventTime ?? 0)
        let directions: Set<SearchDirection> = [.forward]
        let isLastNext = criteria.nextMaxIndex() == index
        search(directions: directions, startTime: startTime, minDeltaTime: c.minTime, maxDeltaTime: c.maxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = c.frontType
            let isFront = self.isFront(event, type: t)
            if isFront {
                let st = event.time
                self.fissionsAlphaNextPerAct[index]?.currentEventTime = st
                let energy = self.getEnergy(event)
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
        search(directions: directions, startTime: startTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaBackBackwardMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            let t = c.backType
            let isBack = self.isBack(event, type: t)
            if isBack {
                var store = self.isEventStripNearToFirstParticle(event, maxDelta: Int(self.criteria.recoilBackMaxDeltaStrips), side: .back)
                if !byFact && store { // check energy also
                    let energy = self.getEnergy(event)
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
        let encoder = event.eventId
        let energy = getEnergy(event)
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     side: side,
                                     stripConfiguration: stripsConfiguration())
        return item
    }

    fileprivate func storeFissionAlphaBack(_ event: Event, match: DoubleSidedStripDetectorMatch, type: SearchType, deltaTime: CLongLong) {
        let side: StripsSide = .back
        let item = focalDetectorMatchItemFrom(event, type: type, deltaTime: deltaTime, side: side)
        match.append(item, side: side)
    }

    fileprivate func storeFissionAlphaFront(_ event: Event, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?) {
        let encoder = event.eventId
        let type = criteria.startParticleType
        let channel = event.getChannelFor(type: type)
        let energy = getEnergy(event)
        let side: StripsSide = .front
        let time = criteria.searchRecoils ? nil : event.time
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     time: time,
                                     overflow: event.overflow,
                                     inBeam: event.inBeam,
                                     channel: channel,
                                     subMatches: subMatches,
                                     side: side,
                                     stripConfiguration: stripsConfiguration())
        fissionsAlphaPerAct.append(item, side: side)
    }

    fileprivate func gammaMatchItem(_ event: Event, deltaTime: CLongLong) -> DetectorMatchItem? {
        let encoder = event.eventId

        if criteria.gammaEncodersOnly, !criteria.gammaEncoderIds.contains(Int(encoder)) {
            return nil
        }

        let energy = getEnergy(event)
        let type: SearchType = .gamma
        let item = DetectorMatchItem(type: type,
                                     stripDetector: nil,
                                     energy: energy,
                                     encoder: encoder,
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     side: nil,
                                     stripConfiguration: stripsConfiguration())
        return item
    }

    fileprivate func storeRecoil(_ event: Event, energy: Double, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?) {
        let encoder = event.eventId
        let side: StripsSide = .front
        let item = DetectorMatchItem(type: .recoil,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     inBeam: event.inBeam,
                                     subMatches: subMatches,
                                     side: side,
                                     stripConfiguration: stripsConfiguration())
        recoilsPerAct.append(item, side: side)
    }

    fileprivate func storeFissionAlpha(_ index: Int, event: Event, type: SearchType, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?, back: DetectorMatchItem?) {
        let encoder = event.eventId
        let energy = getEnergy(event)
        let side: StripsSide = .front
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .focal,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     subMatches: subMatches,
                                     side: side,
                                     stripConfiguration: stripsConfiguration())
        let match = fissionsAlphaNextPerAct[index] ?? DoubleSidedStripDetectorMatch()
        match.append(item, side: side)
        if let back = back {
            match.append(back, side: .back)
        }
        fissionsAlphaNextPerAct[index] = match
    }

    fileprivate func filterAndStoreFissionAlphaWell(_ event: Event, side: StripsSide, deltaTime: CLongLong) {
        let type: SearchType = .alpha
        let energy = getEnergy(event)
        if !isOverflowed(event) && (energy < criteria.fissionAlphaWellMinEnergy || energy > criteria.fissionAlphaWellMaxEnergy) {
            return
        }
        let encoder = event.eventId
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .side,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     side: side,
                                     stripConfiguration: stripsConfiguration())
        fissionsAlphaWellPerAct.append(item, side: side)
    }

    fileprivate func clearActInfo() {
        neutronsPerAct = NeutronsMatch()
        fissionsAlphaPerAct.removeAll()
        specialPerAct.removeAll()
        beamStatePerAct.clean()
        fissionsAlphaWellPerAct.removeAll()
        recoilsPerAct.removeAll()
        fissionsAlphaNextPerAct.removeAll()
    }

    // MARK: - Helpers

    fileprivate func isEventStripNearToFirstParticle(_ event: Event, maxDelta: Int, side: StripsSide) -> Bool {
        let encoder = event.eventId
        let strip1_N = stripsConfiguration().strip1_N_For(channel: encoder)
        if let s = firstParticlePerAct.firstItemsFor(side: side)?.strip1_N {
            return abs(Int32(strip1_N) - Int32(s)) <= Int32(maxDelta)
        }
        return false
    }

    fileprivate func isRecoilBackStripNearToFissionAlphaBack(_ event: Event) -> Bool {
        let side: StripsSide = .back
        if let s = fissionsAlphaPerAct.matchFor(side: side).itemWithMaxEnergy()?.strip1_N {
            let encoder = event.eventId
            let strip1_N = stripsConfiguration().strip1_N_For(channel: encoder)
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
            let encoder = event.eventId
            let strip1_N = stripsConfiguration().strip1_N_For(channel: encoder)
            return Int(abs(Int32(strip1_N) - Int32(s))) <= 1
        }
        return false
    }

    fileprivate func isRecoil(_ event: Event) -> Bool {
        return event.tof == 1
    }
    
    fileprivate func isInBeam(_ event: Event) -> Bool {
        return event.inBeam == 1
    }

    fileprivate func isOverflowed(_ event: Event) -> Bool {
        return event.overflow == 1 && criteria.useOverflow
    }

    fileprivate func isGammaEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.isGammaEvent(eventId)
    }

    fileprivate func isFront(_ event: Event, type: SearchType) -> Bool {
        let searchRecoil = type == .recoil
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
        let searchRecoil = type == .recoil
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

    fileprivate func getEnergy(_ event: Event) -> Double {
        let energy = calibration.calibratedValueForAmplitude(Double(event.energy), eventId: event.eventId)
        return energy
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
        return max(max(max(max(max(1, fissionsAlphaWellPerAct.count), fissionsAlphaPerAct.count), recoilsPerAct.count), neutronsCountWithNewLine()), fissionsAlphaNextPerAct.values.map { $0.count }.max() ?? 0)
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
