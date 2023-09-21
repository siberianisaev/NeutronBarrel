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
    
    func toMks() -> CLongLong {
        return self / 125
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
    fileprivate var currentEventTime: CUnsignedLongLong {
        return fissionsAlphaPerAct.currentEventTime
    }
    
    fileprivate var stoped = false
    fileprivate var logger: Logger!
    fileprivate var resultsTable: ResultsTable!
    
    fileprivate var calibration: Calibration {
        return Calibration.singleton
    }
    
    fileprivate func stripsConfiguration() -> StripsConfiguration {
        return StripDetectorManager.singleton.stripConfiguration
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

        neutronsMultiplicity = NeutronsMultiplicity(efficiency: criteria.neutronsDetectorEfficiency, efficiencyError: criteria.neutronsDetectorEfficiencyError, placedSFSource: nil)
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
        
        // TODO: validate findFissionAlphaWell
        if dataProtocol.isAlphaWellFrontEvent(Int(event.eventId)) {
            fissionsAlphaPerAct.currentEventTime = event.time

            if criteria.inBeamOnly && !isInBeam(event) {
                clearActInfo()
                return
            }

            var gamma: DetectorMatch?
            // FFron or AFron
            let energy = getEnergy(event)
            if !isOverflowed(event) && (energy < criteria.fissionAlphaWellMinEnergy || energy > criteria.fissionAlphaWellMaxEnergy) {
                clearActInfo()
                return
            }
            
            if !criteria.usePileUp && event.pileUp == 1 {
                clearActInfo()
                return
            }

            gamma = findGamma(currentPosition)
            if criteria.requiredGamma && nil == gamma {
                clearActInfo()
                return
            }

            storeFissionAlphaFront(event, deltaTime: 0, subMatches: [.gamma: gamma])

            let position = currentPosition

            findFissionAlphaBack()
            fseek(file, position, SEEK_SET)
            if 0 == fissionsAlphaPerAct.matchFor(side: .back).count {
                clearActInfo()
                return
            }

            if criteria.requiredGammaOrWell && gamma == nil {
                clearActInfo()
                return
            }

            if findNeutrons(position) {
                clearActInfo()
                return
            }

            if criteria.trackBeamState {
                findBeamEvents()
            }
            fseek(file, position, SEEK_SET)

            // Important: this search must be last because we don't do file repositioning here
            // TODO: well logic for Sum(FFron or AFron)
            if criteria.summarizeWell {
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
        }
    }

//    fileprivate func findFissionAlphaWell(_ position: Int) {
//        let directions: Set<SearchDirection> = [.backward, .forward]
//        search(directions: directions, startTime: currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
//            for side in [.front, .back] as [StripsSide] {
//                if self.isFissionOrAlphaWell(event, side: side) {
//                    self.filterAndStoreFissionAlphaWell(event, side: side)
//                }
//            }
//        }
//        fseek(file, position, SEEK_SET)
//    }

//    fileprivate func checkIsSimultaneousDecay(_ event: Event, deltaTime: CLongLong) -> Bool {
//        if criteria.simultaneousDecaysFilterForNeutrons && isBack(event, type: .alpha) && abs(deltaTime) > criteria.fissionAlphaMaxTime {
//            let energy = getEnergy(event)
//            if energy >= criteria.fissionAlphaBackMinEnergy && energy <= criteria.fissionAlphaBackMaxEnergy {
//                return true
//            }
//        }
//        return false
//    }

    fileprivate func findNeutrons(_ position: Int) -> Bool {
        var excludeSFEvent: Bool = false
        if criteria.searchNeutrons {
            let directions: Set<SearchDirection> = [.forward, .backward]
            let startTime = currentEventTime
            let maxDeltaTime = criteria.maxNeutronTime
            search(directions: directions, startTime: startTime, minDeltaTime: criteria.minNeutronTime, maxDeltaTime: maxDeltaTime, maxDeltaTimeBackward: criteria.maxNeutronBackwardTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
                let id = Int(event.eventId)
                // 1) TODO: Simultaneous Decays Filter - search the events with fragment energy at the same time with current decay.
//                if self.checkIsSimultaneousDecay(event, deltaTime: deltaTime) {
//                    excludeSFEvent = true
//                    self.neutronsMultiplicity?.incrementBroken()
//                    stop.initialize(to: true)
//                } else if abs(deltaTime) < maxDeltaTime {
                if abs(deltaTime) < maxDeltaTime {
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
        search(directions: directions, startTime: fissionsAlphaPerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, position: Int) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.dataProtocol.isAlphaWellFrontEvent(Int(event.eventId)) { // && self.isFissionStripNearToFirstFissionFront(event)
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
        let byFact = false // TODO: add UI for self.criteria.searchFissionAlphaBackByFact
        search(directions: directions, startTime: fissionsAlphaPerAct.currentEventTime, minDeltaTime: 0, maxDeltaTime: criteria.fissionAlphaMaxTime, maxDeltaTimeBackward: criteria.fissionAlphaWellBackwardMaxTime) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            if self.dataProtocol.isAlphaWellBackEvent(Int(event.eventId)) {
                var store = byFact
                if !store {
                    let energy = self.getEnergy(event)
                    store = self.isOverflowed(event) || energy >= self.criteria.fissionAlphaWellMinEnergy && energy <= self.criteria.fissionAlphaWellMaxEnergy
                }
                if store {
                    self.storeFissionAlphaBack(event, match: match, type: type, deltaTime: deltaTime)
                    if byFact { // just stop on first one
                        stop.initialize(to: true)
                    }
                }
            }
        }
        if !criteria.summarizeWell {
            match.matchFor(side: .back).filterItemsByMaxEnergy(maxStripsDelta: criteria.fissionAlphaBackMaxDeltaStrips)
        }
    }

    fileprivate func findBeamEvents() {
        forwardSearch { (event: Event, stop: UnsafeMutablePointer<Bool>) in
            if self.beamStatePerAct.handleEvent(event, criteria: self.criteria, dataProtocol: self.dataProtocol!) {
                stop.initialize(to: true)
            }
        }
    }

    // MARK: - Storage

    fileprivate func wellDetectorMatchItemFrom(_ event: Event, type: SearchType, deltaTime: CLongLong, side: StripsSide) -> DetectorMatchItem {
        let encoder = event.eventId
        let energy = getEnergy(event)
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .side,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     side: side)
        return item
    }

    fileprivate func storeFissionAlphaBack(_ event: Event, match: DoubleSidedStripDetectorMatch, type: SearchType, deltaTime: CLongLong) {
        let side: StripsSide = .back
        let item = wellDetectorMatchItemFrom(event, type: type, deltaTime: deltaTime, side: side)
        match.append(item, side: side)
    }

    fileprivate func storeFissionAlphaFront(_ event: Event, deltaTime: CLongLong, subMatches: [SearchType: DetectorMatch?]?) {
        let encoder = event.eventId
        let type = criteria.startParticleType
        let channel = event.getChannelFor(type: type)
        let energy = getEnergy(event)
        let side: StripsSide = .front
        let item = DetectorMatchItem(type: type,
                                     stripDetector: .side,
                                     energy: energy,
                                     encoder: encoder,
                                     eventNumber: eventNumber(),
                                     deltaTime: deltaTime,
                                     overflow: event.overflow,
                                     channel: channel,
                                     subMatches: subMatches,
                                     side: side)
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
                                     side: nil)
        return item
    }

//    fileprivate func filterAndStoreFissionAlphaWell(_ event: Event, side: StripsSide) {
//        let type: SearchType = .alpha
//        let energy = getEnergy(event)
//        if !isOverflowed(event) && (energy < criteria.fissionAlphaWellMinEnergy || energy > criteria.fissionAlphaWellMaxEnergy) {
//            return
//        }
//        let encoder = event.eventId
//        let item = DetectorMatchItem(type: type,
//                                     stripDetector: .side,
//                                     energy: energy,
//                                     encoder: encoder,
//                                     overflow: event.overflow,
//                                     side: side)
//        fissionsAlphaWellPerAct.append(item, side: side)
//    }

    fileprivate func clearActInfo() {
        neutronsPerAct = NeutronsMatch()
        fissionsAlphaPerAct.removeAll()
        specialPerAct.removeAll()
        beamStatePerAct.clean()
    }

    // MARK: - Helpers

//    fileprivate func isEventStripNearToFirstParticle(_ event: Event, maxDelta: Int, side: StripsSide) -> Bool {
//        let encoder = event.eventId
//        let strip1_N = stripsConfiguration().strip1_N_For(channel: encoder)
//        if let s = fissionsAlphaPerAct.firstItemsFor(side: side)?.strip1_N {
//            return abs(Int32(strip1_N) - Int32(s)) <= Int32(maxDelta)
//        }
//        return false
//    }

//    /**
//     +/-1 strips check at this moment.
//     */
//    fileprivate func isFissionStripNearToFirstFissionFront(_ event: Event) -> Bool {
//        let side: StripsSide = .front
//        if let s = fissionsAlphaPerAct.firstItemsFor(side: side)?.strip1_N {
//            let encoder = event.eventId
//            let strip1_N = stripsConfiguration().strip1_N_For(channel: encoder)
//            return Int(abs(Int32(strip1_N) - Int32(s))) <= 1
//        }
//        return false
//    }

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
        return max(max(1, fissionsAlphaPerAct.count), neutronsCountWithNewLine())
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
        return fissionsAlphaPerAct.matchFor(side: .front)
    }

    func fissionsAlphaWellAt(side: StripsSide, index: Int) -> DetectorMatchItem? {
        return fissionsAlphaPerAct.matchFor(side: side).itemAt(index: index)
    }

    func beamState() -> BeamState {
        return beamStatePerAct
    }

    func firstParticleAt(side: StripsSide) -> DetectorMatch {
        return fissionsAlphaPerAct.matchFor(side: side)
    }

    func specialWith(eventId: Int) -> CUnsignedShort? {
        return specialPerAct[eventId]
    }
    
    func wellDetectorNumber(_ eventId: Int, stripsSide: StripsSide) -> Int {
        let startIndex = (stripsSide == .front ? dataProtocol.wellFrontIds : dataProtocol.wellBackIds).first!
        let detector = (eventId - startIndex) / 32 // TODO: constant
        return detector
    }
    
}
