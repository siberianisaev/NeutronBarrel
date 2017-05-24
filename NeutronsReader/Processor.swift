//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import Cocoa

protocol ProcessorDelegate {
    
    func incrementProgress(_ delta: Double)
    func startProcessingFile(_ fileName: String)
    
}

class Processor: NSObject {
    
    enum SearchType {
        case fission
        case alpha
        case recoil
    }
    
    enum TOFUnits {
        case channels
        case nanoseconds
    }
    
    fileprivate let kEncoder = "encoder"
    fileprivate let kStrip0_15 = "strip_0_15"
    fileprivate let kStrip1_48 = "strip_1_48"
    fileprivate let kEnergy = "energy"
    fileprivate let kValue = "value"
    fileprivate let kDeltaTime = "delta_time"
    fileprivate let kChannel = "channel"
    fileprivate let kEventNumber = "event_number"
    fileprivate let kMarker = "marker"
    
    // public during migration to Swift phase
    fileprivate var file: UnsafeMutablePointer<FILE>!
    fileprivate var dataProtocol: DataProtocol!
    fileprivate var mainCycleTimeEvent = Event()
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var firstFissionAlphaTime: CUnsignedLongLong = 0 // время главного осколка/альфы в цикле
    fileprivate var neutronsSummPerAct: CUnsignedLongLong = 0
    fileprivate var files = [String]()
    fileprivate var currentFileName: String?
    fileprivate var neutronsMultiplicityTotal = [Int : Int]()
    fileprivate var recoilsFrontPerAct = [Any]()
    fileprivate var alpha2FrontPerAct = [Any]()
    fileprivate var tofRealPerAct = [Any]()
    fileprivate var fissionsAlphaFrontPerAct = [Any]()
    fileprivate var fissionsAlphaBackPerAct = [Any]()
    fileprivate var fissionsAlphaWelPerAct = [Any]()
    fileprivate var gammaPerAct = [Any]()
    fileprivate var tofGenerationsPerAct = [Any]()
    fileprivate var fonPerAct: CUnsignedShort?
    fileprivate var recoilSpecialPerAct: CUnsignedShort?
    fileprivate var firstFissionAlphaInfo: [String: Any]? // информация о главном осколке/альфе в цикле
    fileprivate var stoped: Bool = false
    fileprivate var logger: Logger!
    fileprivate var calibration: Calibration!
    
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
    var maxGammaTime: CUnsignedLongLong = 0
    var maxNeutronTime: CUnsignedLongLong = 0
    var recoilFrontMaxDeltaStrips: Int = 0
    var recoilBackMaxDeltaStrips: Int = 0
    var summarizeFissionsAlphaFront: Bool = false
    var requiredFissionRecoilBack: Bool = false
    var requiredRecoil: Bool = false
    var requiredGamma: Bool = false
    var requiredTOF: Bool = false
    var searchNeutrons: Bool = false
    
    var searchAlpha2: Bool = false
    var alpha2MinEnergy: Double = 0
    var alpha2MaxEnergy: Double = 0
    var alpha2MinTime: CUnsignedLongLong = 0
    var alpha2MaxTime: CUnsignedLongLong = 0
    var alpha2MaxDeltaStrips: Int = 0
    
    var startParticleType: SearchType = .fission
    var unitsTOF: TOFUnits = .channels
    var delegate: ProcessorDelegate! //TODO: weak
    
    class var singleton : Processor {
        struct Static {
            static let sharedInstance : Processor = Processor()
        }
        return Static.sharedInstance
    }
    
    override init() {
        calibration = Calibration()
        super.init()
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
    
    /**
     Note: use SearchDirection values in 'directions'.
     */
    func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((Event, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: работает в пределах одного файла
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
        recoilsFrontPerAct.removeAll()
        alpha2FrontPerAct.removeAll()
        tofRealPerAct.removeAll()
        fissionsAlphaFrontPerAct.removeAll()
        fissionsAlphaBackPerAct.removeAll()
        gammaPerAct.removeAll()
        tofGenerationsPerAct.removeAll()
        fissionsAlphaWelPerAct.removeAll()
        totalEventNumber = 0
        
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
                        if let file = self?.file, let currentFileName = self?.currentFileName, let stoped = self?.stoped {
                            if ferror(file) != 0 {
                                print("\nERROR while reading file \(currentFileName)\n")
                                exit(-1)
                            }
                            if stoped {
                                stop.initialize(to: true)
                            }
                        }
                        self?.mainCycleEventCheck(event)
                    })
                } else {
                    exit(-1)
                }
                
                fseek(file, 0, SEEK_END)
                var lastNumber = fpos_t()
                fgetpos(file, &lastNumber)
                totalEventNumber += CUnsignedLongLong(lastNumber)/CUnsignedLongLong(eventSize)
                
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
    
    func mainCycleEventCheck(_ event: Event) {
        if Int(event.eventId) == dataProtocol.CycleTime {
            mainCycleTimeEvent = event
        }
        
        // FFron or AFron
        if isFront(event, type: startParticleType) {
            // Запускаем новый цикл поиска, только если энергия осколка/альфы на лицевой стороне детектора выше минимальной
            let energy = getEnergy(event, type: startParticleType)
            if energy < fissionAlphaFrontMinEnergy || energy > fissionAlphaFrontMaxEnergy {
                return
            }
            storeFissionAlphaFront(event, isFirst: true, deltaTime: 0)
            
            var position = fpos_t()
            fgetpos(file, &position)
            
            // Alpha 2
            if searchAlpha2 {
                findAlpha2()
                fseek(file, Int(position), SEEK_SET)
                if 0 == alpha2FrontPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            // Gamma
            findGamma()
            fseek(file, Int(position), SEEK_SET)
            if requiredGamma && 0 == gammaPerAct.count {
                clearActInfo()
                return
            }
            
            // FBack or ABack
            findFissionsAlphaBack()
            fseek(file, Int(position), SEEK_SET)
            if requiredFissionRecoilBack && 0 == fissionsAlphaBackPerAct.count {
                clearActInfo()
                return
            }
            
            // Recoil (Ищем рекойлы только после поиска всех FBack/ABack!)
            findRecoil()
            fseek(file, Int(position), SEEK_SET)
            if requiredRecoil && 0 == recoilsFrontPerAct.count {
                clearActInfo()
                return
            }
            
            // Neutrons
            if searchNeutrons {
                findNeutrons()
                fseek(file, Int(position), SEEK_SET)
            }
            
            // FON & Recoil Special && TOF Generations
            findFONEvents()
            fseek(file, Int(position), SEEK_SET)
            
            // FWel or AWel
            findFissionsAlphaWel()
            fseek(file, Int(position), SEEK_SET)
            
            /*
             ВАЖНО: тут не делаем репозиционирование в потоке после поиска!
             Этот подцикл поиска всегда должен быть последним!
             */
            // Summ(FFron or AFron)
            if summarizeFissionsAlphaFront {
                findFissionsAlphaFront()
            }
            
            // Завершили поиск корреляций
            if searchNeutrons {
                updateNeutronsMultiplicity()
            }
            logActResults()
            clearActInfo()
        }
    }
    
    /**
     Ищем все FWel/AWel в направлении до +_fissionAlphaMaxTime относительно времени T(Fission/Alpha First).
     */
    func findFissionsAlphaWel() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFissionOrAlphaWel(event) {
                self.storeFissionAlphaWell(event)
            }
        }
    }
    
    /**
     Ищем все Neutrons в окне <= _maxNeutronTime относительно времени FFron.
     */
    func findNeutrons() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: maxNeutronTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.Neutrons == Int(event.eventId) {
                self.neutronsSummPerAct += 1
            }
        }
    }
    
    /**
     Ищем все FFron/AFRon в окне <= _fissionAlphaMaxTime относительно времени T(Fission/Alpha First).
     Важно: _mainCycleTimeEvent обновляется при поиске в прямом направлении,
     так как эта часть относится к основному циклу и после поиска не производится репозиционирование потока!
     */
    func findFissionsAlphaFront() {
        var initial = fpos_t()
        fgetpos(file, &initial)
        var current = initial
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: true) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            // File-position check is used for skip Fission/Alpha First event!
            fgetpos(self.file, &current)
            if current != initial && self.isFront(event, type: self.startParticleType) && self.isFissionNearToFirstFissionFront(event) { // FFron/AFron пришедшие после первого
                self.storeFissionAlphaFront(event, isFirst: false, deltaTime: deltaTime)
            }
        }
    }
    
    /**
     Ищем ВСЕ! Gam в окне до _maxGammaTime относительно времени Fission Front (в двух направлениях).
     */
    func findGamma() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: maxGammaTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isGammaEvent(event) {
                self.storeGamma(event, deltaTime: deltaTime)
            }
        }
    }
    
    /**
     Ищем все FBack/ABack в окне <= _fissionAlphaMaxTime относительно времени FFron.
     */
    func findFissionsAlphaBack() {
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let type = self.startParticleType
            if self.isBack(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if energy >= self.fissionAlphaFrontMinEnergy && energy <= self.fissionAlphaFrontMaxEnergy {
                    self.storeFissionAlphaBack(event, deltaTime: deltaTime)
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
                let strip1_48 = stripConvertToFormat_1_48(strip0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort)
                let array = (fissionsAlphaBackPerAct as [Any]).filter( { (obj: Any) -> Bool in
                    let item = obj as! [String: Any]
                    if NSDictionary(dictionary: item).isEqual(to: dict) {
                        return true
                    }
                    let e = item[kEncoder] as! CUnsignedShort
                    let s0_15 = item[kStrip0_15] as! CUnsignedShort
                    let s1_48 = self.stripConvertToFormat_1_48(s0_15, encoder: e)
                    // TODO: new input field for _fissionBackMaxDeltaStrips
                    return abs(Int32(strip1_48) - Int32(s1_48)) <= Int32(recoilBackMaxDeltaStrips)
                })
                fissionsAlphaBackPerAct = array
            }
        }
    }
    
    /**
     Поиск рекойла осуществляется с позиции файла где найден главный осколок/альфа (возвращаемся назад по времени).
     */
    func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(firstFissionAlphaTime), cycleEvent:mainCycleTimeEvent)
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: recoilMinTime, maxDeltaTime: recoilMaxTime, useCycleTime: true, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let isRecoil = self.isFront(event, type: .recoil)
            if isRecoil {
                let isNear = self.isEventFrontNearToFirstFissionAlphaFront(event, maxDelta: Int(self.recoilFrontMaxDeltaStrips))
                if isNear {
                    let energy = self.getEnergy(event, type: .recoil)
                    if energy >= self.recoilFrontMinEnergy && energy <= self.recoilFrontMaxEnergy {
                        // Сохраняем рекойл только если к нему найден Recoil Back и TOF (если required)
                        var position = fpos_t()
                        fgetpos(self.file, &position)
                        let t = CUnsignedLongLong(event.param1)
                        let isRecoilBackFounded = self.findRecoilBack(t)
                        fseek(self.file, Int(position), SEEK_SET)
                        if (isRecoilBackFounded) {
                            let isTOFFounded = self.findTOFForRecoil(event, timeRecoil: t)
                            fseek(self.file, Int(position), SEEK_SET)
                            if (!self.requiredTOF || isTOFFounded) {
                                self.storeRecoil(event, deltaTime: deltaTime)
                            }
                        }
                    }
                }
            }
            
        }
    }
    
    /**
     Real TOF for Recoil.
     */
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
    
    /**
     Ищем Recoil Back в окне <= kFissionsMaxSearchTimeInMks относительно времени Recoil Front.
     */
    func findRecoilBack(_ timeRecoilFront: CUnsignedLongLong) -> Bool {
        var found: Bool = false
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: recoilBackMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isBack(event, type: .recoil) {
                if (self.requiredFissionRecoilBack) {
                    found = self.isRecoilBackNearToFissionAlphaBack(event)
                } else {
                    found = true
                }
                stop.initialize(to: true)
            }
        }
        return found
    }
    
    fileprivate let kTOFGenerationsMaxTime: Double = 2 // from t(FF) (случайные генерации, а не отмеки рекойлов)
    /**
     Поиск первых событий FON, Recoil Special, TOF (случайные генерации) осуществляется с позиции файла где найден главный осколок.
     */
    func findFONEvents() {
        var fonFound: Bool = false
        var recoilFound: Bool = false
        var tofFound: Bool = false
        forwardSearch { (event: Event, stop: UnsafeMutablePointer<Bool>) in
            if self.dataProtocol.FON == Int(event.eventId) {
                if !fonFound {
                    self.storeFON(event)
                    fonFound = true
                }
            } else if self.dataProtocol.RecoilSpecial == Int(event.eventId) {
                if !recoilFound {
                    self.storeRecoilSpecial(event)
                    recoilFound = true
                }
            } else if self.dataProtocol.TOF == Int(event.eventId) {
                if !tofFound {
                    let deltaTime = fabs(Double(event.param1) - Double(self.firstFissionAlphaTime))
                    if deltaTime <= self.kTOFGenerationsMaxTime {
                        self.storeTOFGenerations(event)
                    }
                    tofFound = true
                }
            }
            if fonFound && recoilFound && tofFound {
                stop.initialize(to: true)
            }
        }
    }
    
    /**
     Поиск альфы 2 осуществляется с позиции файла где найдена альфа 1 (вперед по времени).
     */
    func findAlpha2() {
        let alphaTime = absTime(CUnsignedShort(firstFissionAlphaTime), cycleEvent: mainCycleTimeEvent)
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: alphaTime, minDeltaTime: alpha2MinTime, maxDeltaTime: alpha2MaxTime, useCycleTime: true, updateCycleEvent: false) { (event: Event, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: .alpha) {
                let energy = self.getEnergy(event, type: .alpha)
                if energy >= self.alpha2MinEnergy && energy <= self.alpha2MaxEnergy && self.isEventFrontNearToFirstFissionAlphaFront(event, maxDelta: Int(self.alpha2MaxDeltaStrips)) {
                    self.storeAlpha2(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    // MARK: - Storage
    
    func storeFissionAlphaBack(_ event: Event, deltaTime: CLongLong) {
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12  // value from 0 to 15
        let energy = getEnergy(event, type: startParticleType)
        let info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kEventNumber: eventNumber(),
                    kDeltaTime: deltaTime,
                    kMarker: getMarker(event)] as [String : Any]
        fissionsAlphaBackPerAct.append(info)
    }
    
    /**
     Используется для определения суммарной множественности нейтронов во всех файлах
     */
    func updateNeutronsMultiplicity() {
        let key = neutronsSummPerAct
        var summ = neutronsMultiplicityTotal[Int(key)] ?? 0
        summ += 1 // Одно событие для всех нейтронов в одном акте деления
        neutronsMultiplicityTotal[Int(key)] = summ
    }
    
    func storeFissionAlphaFront(_ event: Event, isFirst: Bool, deltaTime: CLongLong) {
        let channel = startParticleType == .fission ? (event.param2 & Mask.fission.rawValue) : (event.param3 & Mask.recoilAlpha.rawValue)
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12 // value from 0 to 15
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
            let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId: event.eventId)
            var extraInfo = info
            extraInfo[kStrip1_48] = strip_1_48
            firstFissionAlphaInfo = extraInfo
            firstFissionAlphaTime = UInt64(event.param1)
        }
    }
    
    func storeGamma(_ event: Event, deltaTime: CLongLong) {
        let channel = event.param3 & Mask.gamma.rawValue
        let energy = calibration.calibratedValueForAmplitude(Double(channel), eventName: "Gam1") // TODO: Gam2, Gam
        let info = [kEnergy: energy,
                    kDeltaTime: deltaTime] as [String : Any]
        gammaPerAct.append(info)
    }
    
    func storeRecoil(_ event: Event, deltaTime: CLongLong) {
        let energy = getEnergy(event, type: .recoil)
        let info = [kEnergy: energy,
                    kDeltaTime: deltaTime,
                    kEventNumber: eventNumber(),
                    kMarker: getMarker(event)] as [String : Any]
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
    
    func storeFissionAlphaWell(_ event: Event) {
        let energy = getEnergy(event, type: startParticleType)
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12  // value from 0 to 15
        let info = [kEncoder: encoder,
                    kStrip0_15: strip_0_15,
                    kEnergy: energy,
                    kMarker: getMarker(event)] as [String : Any]
        fissionsAlphaWelPerAct.append(info)
    }
    
    func storeTOFGenerations(_ event: Event) {
        let channel = event.param3 & Mask.TOF.rawValue
        tofGenerationsPerAct.append(channel)
    }
    
    func storeFON(_ event: Event) {
        let channel = event.param3 & Mask.FON.rawValue
        fonPerAct = channel
    }
    
    func storeRecoilSpecial(_ event: Event) {
        let channel = event.param3 & Mask.recoilSpecial.rawValue
        recoilSpecialPerAct = channel
    }
    
    func clearActInfo() {
        neutronsSummPerAct = 0
        fissionsAlphaFrontPerAct.removeAll()
        fissionsAlphaBackPerAct.removeAll()
        gammaPerAct.removeAll()
        tofGenerationsPerAct.removeAll()
        fissionsAlphaWelPerAct.removeAll()
        recoilsFrontPerAct.removeAll()
        alpha2FrontPerAct.removeAll()
        tofRealPerAct.removeAll()
        firstFissionAlphaInfo = nil
        fonPerAct = nil
        recoilSpecialPerAct = nil
    }
    
    // MARK: - Helpers
    
    fileprivate var eventSize: Int {
        return MemoryLayout<Event>.size
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
    
    /**
     Метод проверяет находится ли ! рекоил/альфа ! event на близких стрипах относительно первого осколка/альфы.
     */
    func isEventFrontNearToFirstFissionAlphaFront(_ event: Event, maxDelta: Int) -> Bool {
        let strip_0_15 = event.param2 >> 12
        let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId:event.eventId)
        if let n = firstFissionAlphaInfo?[kStrip1_48] {
            let s = n as! CUnsignedShort
            return abs(Int32(strip_1_48) - Int32(s)) <= Int32(maxDelta)
        }
        return false
    }
    
    /**
     Метод проверяет находится ли рекоил event на близких стрипах (_recoilBackMaxDeltaStrips) относительно заднего осколка с макимальной энергией.
     */
    func isRecoilBackNearToFissionAlphaBack(_ event: Event) -> Bool {
        if let fissionBackInfo = fissionAlphaBackWithMaxEnergyInAct() {
            let strip_0_15 = event.param2 >> 12
            let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId:event.eventId)
            let strip_0_15_back_fission = fissionBackInfo[kStrip0_15] as! CUnsignedShort
            let encoder_back_fission = fissionBackInfo[kEncoder] as! CUnsignedShort
            let strip_1_48_back_fission = stripConvertToFormat_1_48(strip_0_15_back_fission, encoder: encoder_back_fission)
            return abs(Int32(strip_1_48) - Int32(strip_1_48_back_fission)) <= Int32(recoilBackMaxDeltaStrips)
        } else {
            return false
        }
    }
    
    /**
     Метод проверяет находится ли осколок event на соседних стрипах относительно первого осколка.
     */
    func isFissionNearToFirstFissionFront(_ event: Event) -> Bool {
        let strip_0_15 = event.param2 >> 12
        if let n = firstFissionAlphaInfo?[kStrip0_15] {
            let s = n as! CUnsignedShort
            if strip_0_15 == s { // совпадают
                return true
            }
            
            let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId: event.eventId)
            if let n = firstFissionAlphaInfo?[kStrip1_48] {
                let s = n as! CUnsignedShort
                return Int(abs(Int32(strip_1_48) - Int32(s))) <= 1 // +/- 1 стрип
            }
        }
        return false
    }
    
    /**
     У осколков/рекойлов записывается только время относительно начала нового счетчика времени (счетчик обновляется каждые 0xFFFF мкс).
     Для вычисления времени от запуска файла используем время цикла.
     */
    func absTime(_ relativeTime: CUnsignedShort, cycleEvent: Event) -> CUnsignedLongLong {
        return (CUnsignedLongLong(cycleEvent.param3) << 16) + CUnsignedLongLong(cycleEvent.param1) + CUnsignedLongLong(relativeTime)
    }
    
    /**
     В фокальном детекторе cтрипы подключены поочередно к трем 16-канальным кодировщикам:
     | 1.0 | 2.0 | 3.0 | 1.1 | 2.1 | 3.1 | 1.1 ... (encoder.strip_0_15)
     Метод переводит стрип из формата "кодировщик + стрип от 0 до 15" в формат "стрип от 1 до 48".
     */
    func focalStripConvertToFormat_1_48(_ strip_0_15: CUnsignedShort, eventId: CUnsignedShort) -> CUnsignedShort {
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(eventId))
        return stripConvertToFormat_1_48(strip_0_15, encoder:encoder)
    }
    
    func stripConvertToFormat_1_48(_ strip_0_15: CUnsignedShort, encoder: CUnsignedShort) -> CUnsignedShort {
        return (strip_0_15 * 3) + (encoder - 1) + 1
    }
    
    func getMarker(_ event: Event) -> CUnsignedShort {
        return event.param3 >> 13
    }
    
    /**
     Чтобы различить рекоил и осколок/альфу используем первый бит из param3:
     0 - осколок,
     1 - рекоил
     */
    func isRecoil(_ event: Event) -> Bool {
        return (event.param3 >> 15) == 1
    }
    
    func fissionAlphaRecoilEncoderForEventId(_ eventId: Int) -> CUnsignedShort {
        if (dataProtocol.AFron(1) == eventId || dataProtocol.ABack(1) == eventId || dataProtocol.AdFr(1) == eventId || dataProtocol.AdBk(1) == eventId || dataProtocol.AWel(1) == eventId || dataProtocol.AWel == eventId) {
            return 1
        }
        if (dataProtocol.AFron(2) == eventId || dataProtocol.ABack(2) == eventId || dataProtocol.AdFr(2) == eventId || dataProtocol.AdBk(2) == eventId || dataProtocol.AWel(2) == eventId) {
            return 2
        }
        if (dataProtocol.AFron(3) == eventId || dataProtocol.ABack(3) == eventId || dataProtocol.AdFr(3) == eventId || dataProtocol.AdBk(3) == eventId || dataProtocol.AWel(3) == eventId) {
            return 3
        }
        if (dataProtocol.AWel(4) == eventId) {
            return 4
        }
        return 0
    }
    
    func isGammaEvent(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return dataProtocol.Gam(1) == eventId || dataProtocol.Gam(2) == eventId || dataProtocol.Gam == eventId
    }
    
    func isFront(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == .recoil
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && (dataProtocol.AFron(1) == eventId || dataProtocol.AFron(2) == eventId || dataProtocol.AFron(3) == eventId || dataProtocol.AdFr(1) == eventId || dataProtocol.AdFr(2) == eventId || dataProtocol.AdFr(3) == eventId)
    }
    
    func isFissionOrAlphaWel(_ event: Event) -> Bool {
        let eventId = Int(event.eventId)
        return !isRecoil(event) && (dataProtocol.AWel == eventId || dataProtocol.AWel(1) == eventId || dataProtocol.AWel(2) == eventId || dataProtocol.AWel(3) == eventId || dataProtocol.AWel(4) == eventId)
    }
    
    func isBack(_ event: Event, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let searchRecoil = type == .recoil
        let currentRecoil = isRecoil(event)
        let sameType = (searchRecoil && currentRecoil) || (!searchRecoil && !currentRecoil)
        return sameType && (dataProtocol.ABack(1) == eventId || dataProtocol.ABack(2) == eventId || dataProtocol.ABack(3) == eventId || dataProtocol.AdBk(1) == eventId || dataProtocol.AdBk(2) == eventId || dataProtocol.AdBk(3) == eventId)
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
    
    func getEnergy(_ event: Event, type: SearchType) -> Double {
        let channel = type == .fission ? (event.param2 & Mask.fission.rawValue) : (event.param3 & Mask.recoilAlpha.rawValue)
        let eventId = Int(event.eventId)
        let strip_0_15 = event.param2 >> 12  // value from 0 to 15
        let encoder = fissionAlphaRecoilEncoderForEventId(eventId)
        
        var detector: String
        switch type {
        case .fission:
            detector = "F"
        case .alpha:
            detector = "A"
        case .recoil:
            detector = "R"
        }
        
        var position: String
        if dataProtocol.AFron(1) == eventId || dataProtocol.AFron(2) == eventId || dataProtocol.AFron(3) == eventId {
            position = "Fron"
        } else if dataProtocol.ABack(1) == eventId || dataProtocol.ABack(2) == eventId || dataProtocol.ABack(3) == eventId {
            position = "Back"
        } else if dataProtocol.AdFr(1) == eventId || dataProtocol.AdFr(2) == eventId || dataProtocol.AdFr(3) == eventId {
            position = "dFr"
        } else if dataProtocol.AdBk(1) == eventId || dataProtocol.AdBk(2) == eventId || dataProtocol.AdBk(3) == eventId {
            position = "dBk"
        } else {
            position = "Wel"
        }
        
        let name = String(format: "%@%@%d.%d", detector, position, encoder, strip_0_15+1)
        return calibration.calibratedValueForAmplitude(Double(channel), eventName: name)
    }
    
    func currentFileEventNumber(_ number: CUnsignedLongLong) -> String {
        return String(format: "%@_%llu", currentFileName ?? "", number)
    }
    
    func nanosecondsForTOFChannel(_ channelTOF: CUnsignedShort, eventRecoil: Event) -> Double {
        let eventId = Int(eventRecoil.eventId)
        let strip_0_15 = eventRecoil.param2 >> 12  // value from 0 to 15
        let encoder = fissionAlphaRecoilEncoderForEventId(eventId)
        var position: String
        if dataProtocol.AFron(1) == eventId || dataProtocol.AFron(2) == eventId || dataProtocol.AFron(3) == eventId {
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
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        let image = appDelegate.window.screenshot()
        logger.logInput(image)
    }
    
    func logCalibration() {
        logger.logCalibration(calibration.stringValue ?? "")
    }
    
    func logResultsHeader() {
        let startParticle = startParticleType == .fission ? "F" : "A"
        var header = String(format: "Event(Recoil),E(RFron),RFronMarker,dT(RFron-$Fron),TOF,dT(TOF-RFron),Event($),Summ($Fron),$Fron,$FronMarker,dT($FronFirst-Next),Strip($Fron),$Back,$BackMarker,dT($Fron-$Back),Strip($Back),$Wel,$WelMarker,$WelPos,Neutrons,Gamma,dT($Fron-Gamma),FON,Recoil(Special)")
        if searchAlpha2 {
            header += ",Event(Alpha2),E(Alpha2),Alpha2Marker,dT(Alpha1-Alpha2)"
        }
        header = header.replacingOccurrences(of: "$", with: startParticle)
        let components = header.components(separatedBy: ",")
        logger.writeLineOfFields(components as [AnyObject])
        logger.finishLine() // +1 line padding
    }
    
    func logActResults() {
        func getValueFrom(array: [Any], row: Int, key: String) -> Any? {
            return (array[row] as? [String: Any])?[key]
        }
        
        var columnsCount = 23
        if searchAlpha2 {
            columnsCount += 4
        }
        let rowsMax = max(max(max(max(max(1, gammaPerAct.count), fissionsAlphaWelPerAct.count), recoilsFrontPerAct.count), fissionsAlphaBackPerAct.count), fissionsAlphaFrontPerAct.count)
        for row in 0 ..< rowsMax {
            for column in 0...columnsCount {
                var field = ""
                switch column {
                case 0:
                    if row < recoilsFrontPerAct.count {
                        if let eventNumberObject = getValueFrom(array: recoilsFrontPerAct, row: row, key: kEventNumber) {
                            field = currentFileEventNumber(eventNumberObject as! CUnsignedLongLong)
                        }
                    }
                case 1:
                    if row < recoilsFrontPerAct.count {
                        if let recoilEnergy = getValueFrom(array: recoilsFrontPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", recoilEnergy as! Double)
                        }
                    }
                case 2:
                    if row < recoilsFrontPerAct.count {
                        if let marker = getValueFrom(array: recoilsFrontPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case 3:
                    if row < recoilsFrontPerAct.count {
                        if let deltaTimeRecoilFission = getValueFrom(array: recoilsFrontPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTimeRecoilFission as! CLongLong)
                        }
                    }
                case 4:
                    if row < tofRealPerAct.count {
                        if let tof = getValueFrom(array: tofRealPerAct, row: row, key: kValue) {
                            let format = "%." + (unitsTOF == .channels ? "0" : "7") + "f"
                            field = String(format: format, tof as! Double)
                        }
                    }
                case 5:
                    if row < tofRealPerAct.count {
                        if let deltaTimeTOFRecoil = getValueFrom(array: tofRealPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTimeTOFRecoil as! CLongLong)
                        }
                    }
                case 6:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let eventNumber = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kEventNumber) {
                            field = currentFileEventNumber(eventNumber as! CUnsignedLongLong)
                        }
                    }
                case 7:
                    if row == 0 {
                        var summ: Double = 0
                        for info in fissionsAlphaFrontPerAct {
                            if let energy = (info as? [String: Any])?[kEnergy] {
                                summ += energy as! Double
                            }
                        }
                        field = String(format: "%.7f", summ)
                    }
                case 8:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let energy = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case 9:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let marker = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case 10:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let deltaTime = getValueFrom(array: fissionsAlphaFrontPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case 11:
                    if row < fissionsAlphaFrontPerAct.count {
                        if let info = fissionsAlphaFrontPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                            let strip = stripConvertToFormat_1_48(strip_0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort)
                            field = String(format: "%d", strip)
                        }
                    }
                case 12:
                    if row < fissionsAlphaBackPerAct.count {
                        if let energy = getValueFrom(array: fissionsAlphaBackPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case 13:
                    if row < fissionsAlphaBackPerAct.count {
                        if let marker = getValueFrom(array: fissionsAlphaBackPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case 14:
                    if row < fissionsAlphaBackPerAct.count {
                        if let deltaTime = getValueFrom(array: fissionsAlphaBackPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case 15:
                    if row < fissionsAlphaBackPerAct.count {
                        if let info = fissionsAlphaBackPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                            let strip = stripConvertToFormat_1_48(strip_0_15 as! CUnsignedShort, encoder: encoder as! CUnsignedShort)
                            field = String(format: "%d", strip)
                        }
                    }
                case 16:
                    if row < fissionsAlphaWelPerAct.count {
                        if let energy = getValueFrom(array: fissionsAlphaWelPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case 17:
                    if row < fissionsAlphaWelPerAct.count {
                        if let marker = getValueFrom(array: fissionsAlphaWelPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case 18:
                    if row < fissionsAlphaWelPerAct.count {
                        if let info = fissionsAlphaWelPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15], let encoder = info[kEncoder] {
                            field = String(format: "FWel%d.%d", encoder as! CUnsignedShort, (strip_0_15  as! CUnsignedShort) + 1)
                        }
                    }
                case 19:
                    if row == 0 && searchNeutrons {
                        field = String(format: "%llu", neutronsSummPerAct)
                    }
                case 20:
                    if row < gammaPerAct.count {
                        if let energy = getValueFrom(array: gammaPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case 21:
                    if row < gammaPerAct.count {
                        if let deltaTime = getValueFrom(array: gammaPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                case 22:
                    if row == 0 {
                        if let v = fonPerAct {
                            field = String(format: "%hu", v)
                        }
                    }
                case 23:
                    if row == 0 {
                        if let v = recoilSpecialPerAct {
                            field = String(format: "%hu", v)
                        }
                    }
                case 24:
                    if row < alpha2FrontPerAct.count {
                        if let eventNumber = getValueFrom(array: alpha2FrontPerAct, row: row, key: kEventNumber) {
                            field = currentFileEventNumber(eventNumber as! CUnsignedLongLong)
                        }
                    }
                case 25:
                    if row < alpha2FrontPerAct.count {
                        if let energy = getValueFrom(array: alpha2FrontPerAct, row: row, key: kEnergy) {
                            field = String(format: "%.7f", energy as! Double)
                        }
                    }
                case 26:
                    if row < alpha2FrontPerAct.count {
                        if let marker = getValueFrom(array: alpha2FrontPerAct, row: row, key: kMarker) {
                            field = String(format: "%hu", marker as! CUnsignedShort)
                        }
                    }
                case 27:
                    if row < alpha2FrontPerAct.count {
                        if let deltaTime = getValueFrom(array: alpha2FrontPerAct, row: row, key: kDeltaTime) {
                            field = String(format: "%lld", deltaTime as! CLongLong)
                        }
                    }
                default:
                    break
                }
                logger.writeField(field as AnyObject)
            }
            logger.finishLine()
        }
    }

}
