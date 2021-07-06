//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import Cocoa

extension Event {
    
    func getChannelFor(type: SearchType) -> CUnsignedShort {
        return param3 & Mask.recoilOrAlpha.rawValue
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
    
    fileprivate var gammaPerAct: DetectorMatch?
    fileprivate var neutronsPerAct = NeutronsMatch()
    fileprivate var neutronsMultiplicity: NeutronsMultiplicity?
    
    fileprivate var currentEventTime: CUnsignedLongLong = 0
    
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
        if let multiplicity = neutronsMultiplicity {
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
        } else {
            let position = currentPosition
            if criteria.gammaStart {
                if isGammaEvent(event) {
                    currentEventTime = UInt64(event.param1)
                    gammaPerAct = findGamma(position) ?? DetectorMatch()
                    fseek(file, position, SEEK_SET)
                    
                    if let gamma = gammaPerAct, gamma.encoders.count > 1 {
                        findNeutrons(position)
                        onFinishAct()
                    } else {
                        clearActInfo()
                    }
                }
            } else {
                if isNeutronEvent(event) {
                    currentEventTime = UInt64(event.param1)
                    
                    gammaPerAct = findGamma(position) ?? DetectorMatch()
                    fseek(file, position, SEEK_SET)
                    if let gamma = gammaPerAct, gamma.encoders.count > 1 {
                        findNeutrons(position)
                        onFinishAct()
                    } else {
                        clearActInfo()
                    }
                }
            }
        }
    }
    
    fileprivate func onFinishAct() {
        neutronsMultiplicity?.increment(multiplicity: neutronsPerAct.count)
        correlationsPerFile += 1
        resultsTable.logActResults()
        clearActInfo()
    }
    
    fileprivate func findNeutrons(_ position: Int) {
        let directions: Set<SearchDirection> = [.forward, .backward]
        let startTime = currentEventTime
        search(directions: directions, startTime: startTime, minDeltaTime: 0, maxDeltaTime: criteria.maxNeutronTime, maxDeltaTimeBackward: criteria.maxNeutronBackwardTime, useCycleTime: false, updateCycle: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>, _) in
            let id = Int(event.eventId)
            if self.dataProtocol.isNeutronsNewEvent(id) {
                self.addNeutron(event, deltaTime: deltaTime)
            }
        }
    }
    
    func addNeutron(_ event: Event, deltaTime: CLongLong) {
        neutronsPerAct.eventNumbers.append(eventNumber())
        neutronsPerAct.times.append(Float(deltaTime))
        let id = Int(event.eventId)
        var encoder = dataProtocol.encoderForEventId(id) // 1-4
        var channel = event.param3 & Mask.neutronsNew.rawValue // 0-31
        // Convert to encoder 1-8 and strip 0-15 format
        neutronsPerAct.encoders.append(encoder)
        encoder *= 2
        if channel > 15 {
            channel -= 16
        } else {
            encoder -= 1
        }
        let counterNumber = stripsConfiguration(detector: .neutron).strip1_N_For(side: .front, encoder: Int(encoder), strip0_15: channel)
        neutronsPerAct.counters.append(counterNumber)
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
        if energy >= Double(criteria.minGammaEnergy) && energy <= Double(criteria.maxGammaEnergy) {
            let item = DetectorMatchItem(type: type,
                                         stripDetector: nil,
                                         energy: energy,
                                         encoder: encoder,
                                         eventNumber: eventNumber(),
                                         deltaTime: deltaTime,
                                         marker: event.getMarker(),
                                         side: nil)
            return item
        } else {
            return nil
        }
    }
    
    
    
    fileprivate func clearActInfo() {
        neutronsPerAct = NeutronsMatch()
        gammaPerAct = nil
    }
    
    /**
     Time stored in events are relative time (timer from 0x0000 to xFFFF mks resettable on overflow).
     We use special event 'dataProtocol.CycleTime' to calculate time from file start.
     */
    fileprivate func absTime(_ relativeTime: CUnsignedShort, cycle: CUnsignedLongLong) -> CUnsignedLongLong {
        return (cycle << 16) + CUnsignedLongLong(relativeTime)
    }
    
    fileprivate func isGammaEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.isGammaEvent(eventId)
    }
    
    fileprivate func isNeutronEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.isNeutronsNewEvent(eventId)
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
        return max(neutronsCountWithNewLine(), gammaPerAct?.count ?? 0)
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
    
    func gammaContainer() -> DetectorMatch? {
        return gammaPerAct
    }
    
}
