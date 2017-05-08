//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation

class Processor: NSObject {
    
    var p: ISAProcessor! // used during mirgation to Swift phase
    
    @objc func forwardSearch(checker: @escaping ((ISAEvent, UnsafeMutablePointer<Bool>)->())) {
        while feof(p.file) != 1 {
            var event = ISAEvent()
            fread(&event, eventSize, 1, p.file)
            
            var stop: Bool = false
            checker(event, &stop)
            if stop {
                return
            }
        }
    }
    
    fileprivate var eventSize: Int {
        return MemoryLayout<ISAEvent>.size
    }
    
    /**
     Note: use SearchDirection values in 'directions'.
     */
    @objc func search(directions: Set<NSNumber>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((ISAEvent, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: работает в пределах одного файла
        if directions.contains(SearchDirection.backward.rawValue as NSNumber) {
            var initial = fpos_t()
            fgetpos(p.file, &initial)
            
            var cycleEvent = p.mainCycleTimeEvent
            var current = Int(initial)
            while current > -1 {
                current -= eventSize
                fseek(p.file, current, SEEK_SET)
                
                var event = ISAEvent()
                fread(&event, eventSize, 1, p.file)
                
                let id = Int(event.eventId)
                if id == p.dataProtocol.CycleTime {
                    cycleEvent = event
                    continue
                }
                
                if p.dataProtocol.isValidEventIdForTimeCheck(id) {
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
                
                fseek(p.file, Int(initial), SEEK_SET)
            }
        }
        
        if directions.contains(SearchDirection.forward.rawValue as NSNumber) {
            var cycleEvent = p.mainCycleTimeEvent
            while feof(p.file) != 1 {
                var event = ISAEvent()
                fread(&event, eventSize, 1, p.file)
                
                let id = Int(event.eventId)
                if id == p.dataProtocol.CycleTime {
                    if updateCycleEvent {
                        p.mainCycleTimeEvent = event
                    }
                    cycleEvent = event
                    continue
                }
            
                if p.dataProtocol.isValidEventIdForTimeCheck(id) {
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
    
    /**
     Ищем все FWel/AWel в направлении до +_fissionAlphaMaxTime относительно времени T(Fission/Alpha First).
     */
    func findFissionsAlphaWel() {
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFissionOrAlphaWel(event) {
                self.p.storeFissionAlphaWell(event)
            }
        }
    }
    
    /**
     Ищем все Neutrons в окне <= _maxNeutronTime относительно времени FFron.
     */
    func findNeutrons() {
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.maxNeutronTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.p.dataProtocol.Neutrons == Int(event.eventId) {
                self.p.neutronsSummPerAct += 1
            }
        }
    }
    
    /**
     Ищем все FFron/AFRon в окне <= _fissionAlphaMaxTime относительно времени T(Fission/Alpha First).
     Важно: _mainCycleTimeEvent обновляется при поиске в прямом направлении,
     так как эта часть относится к основному циклу и после поиска не производится репозиционирование потока!
     */
    func findFissionsAlphaFront() {
        // Skip Fission/Alpha First event!
        var position = fpos_t()
        fgetpos(p.file, &position)
        if (position > -1) {
            position -= fpos_t(eventSize)
            fseek(p.file, Int(position), SEEK_SET)
        }
        
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber, SearchDirection.backward.rawValue as NSNumber]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: true) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: self.p.startParticleType) && self.isFissionNearToFirstFissionFront(event) { // FFron/AFron пришедшие после первого
                self.p.storeNextFissionAlphaFront(event, deltaTime: deltaTime)
            }
        }
    }
    
    /**
     Ищем ВСЕ! Gam в окне до _maxGammaTime относительно времени Fission Front (в двух направлениях).
     */
    func findGamma() {
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber, SearchDirection.backward.rawValue as NSNumber]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.maxGammaTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isGammaEvent(event) {
                self.p.storeGamma(event, deltaTime: deltaTime)
            }
        }
    }
    
    /**
     Ищем все FBack/ABack в окне <= _fissionAlphaMaxTime относительно времени FFron.
     */
    func findFissionsAlphaBack() {
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let type = self.p.startParticleType
            if self.isBack(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if energy >= self.p.fissionAlphaFrontMinEnergy && energy <= self.p.fissionAlphaFrontMaxEnergy {
                    self.p.storeFissionAlphaBack(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    /**
     Поиск рекойла осуществляется с позиции файла где найден главный осколок/альфа (возвращаемся назад по времени).
     */
    func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(p.firstFissionAlphaTime), cycleEvent:p.mainCycleTimeEvent)
        let directions: Set<NSNumber> = [SearchDirection.backward.rawValue as NSNumber]
        search(directions: directions, startTime: fissionTime, minDeltaTime: p.recoilMinTime, maxDeltaTime: p.recoilMaxTime, useCycleTime: true, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: SearchType.recoil) && self.isEventFrontNearToFirstFissionAlphaFront(event, maxDelta: Int(self.p.recoilFrontMaxDeltaStrips)) {
                let energy = self.getEnergy(event, type: SearchType.recoil)
                if energy >= self.p.recoilFrontMinEnergy && energy <= self.p.recoilFrontMaxEnergy {
                    // Сохраняем рекойл только если к нему найден Recoil Back и TOF (если required)
                    var position = fpos_t()
                    fgetpos(self.p.file, &position)
                    let isRecoilBackFounded = self.findRecoilBack(CUnsignedLongLong(event.param1))
                    fseek(self.p.file, Int(position), SEEK_SET)
                    if (isRecoilBackFounded) {
                        let isTOFFounded = self.findTOFForRecoil(event, timeRecoil: time)
                        fseek(self.p.file, Int(position), SEEK_SET)
                        if (!self.p.requiredTOF || isTOFFounded) {
                            self.p.storeRecoil(event, deltaTime: deltaTime)
                        }
                    }
                }
            }
        }
    }
    
    /**
     Real TOF for Recoil.
     */
    func findTOFForRecoil(_ eventRecoil: ISAEvent, timeRecoil: CUnsignedLongLong) -> Bool {
        var found: Bool = false
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber, SearchDirection.backward.rawValue as NSNumber]
        search(directions: directions, startTime: timeRecoil, minDeltaTime: 0, maxDeltaTime: p.maxTOFTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.p.dataProtocol.TOF == Int(event.eventId) {
                let value = self.p.valueTOF(event, forRecoil: eventRecoil)
                if value >= self.p.minTOFValue && value <= self.p.maxTOFValue {
                    self.p.storeRealTOFValue(value, deltaTime: deltaTime)
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
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber]
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: p.recoilBackMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isBack(event, type: SearchType.recoil) {
                if (self.p.requiredFissionRecoilBack) {
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
        forwardSearch { (event: ISAEvent, stop: UnsafeMutablePointer<Bool>) in
            if self.p.dataProtocol.FON == Int(event.eventId) {
                if !fonFound {
                    self.p.storeFON(event)
                    fonFound = true
                }
            } else if self.p.dataProtocol.RecoilSpecial == Int(event.eventId) {
                if !recoilFound {
                    self.p.storeRecoilSpecial(event)
                    recoilFound = true
                }
            } else if self.p.dataProtocol.TOF == Int(event.eventId) {
                if !tofFound {
                    let deltaTime = fabs(Double(event.param1) - Double(self.p.firstFissionAlphaTime))
                    if deltaTime <= self.kTOFGenerationsMaxTime {
                        self.p.storeTOFGenerations(event)
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
        let alphaTime = absTime(CUnsignedShort(p.firstFissionAlphaTime), cycleEvent: p.mainCycleTimeEvent)
        let directions: Set<NSNumber> = [SearchDirection.forward.rawValue as NSNumber]
        search(directions: directions, startTime: alphaTime, minDeltaTime: p.alpha2MinTime, maxDeltaTime: p.alpha2MaxTime, useCycleTime: true, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: SearchType.alpha) {
                let energy = self.getEnergy(event, type: SearchType.alpha)
                if energy >= self.p.alpha2MinEnergy && energy <= self.p.alpha2MaxEnergy && self.isEventFrontNearToFirstFissionAlphaFront(event, maxDelta: Int(self.p.alpha2MaxDeltaStrips)) {
                    self.p.storeAlpha2(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /**
     Метод проверяет находится ли ! рекоил/альфа ! event на близких стрипах относительно первого осколка/альфы.
     */
    func isEventFrontNearToFirstFissionAlphaFront(_ event: ISAEvent, maxDelta: Int) -> Bool {
        let strip_0_15 = event.param2 >> 12
        let strip_1_48 = Int(focalStripConvertToFormat_1_48(strip_0_15, eventId:event.eventId))
        let strip_1_48_first_fission = p.firstFissionAlphaInfo[kStrip1_48] as! Int
        return abs(Int32(strip_1_48 - strip_1_48_first_fission)) <= Int32(maxDelta)
    }
    
    /**
     Метод проверяет находится ли рекоил event на близких стрипах (_recoilBackMaxDeltaStrips) относительно заднего осколка с макимальной энергией.
     */
    func isRecoilBackNearToFissionAlphaBack(_ event: ISAEvent) -> Bool {
        if let fissionBackInfo = p.fissionAlphaBackWithMaxEnergyInAct() {
            let strip_0_15 = event.param2 >> 12
            let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId:event.eventId)
            let strip_0_15_back_fission = fissionBackInfo[kStrip0_15] as! Int
            let encoder_back_fission = fissionBackInfo[kEncoder] as! Int
            let strip_1_48_back_fission = stripConvertToFormat_1_48(CUnsignedShort(strip_0_15_back_fission), encoder: CUnsignedShort(encoder_back_fission))
            return abs(Int32(strip_1_48 - strip_1_48_back_fission)) <= Int32(p.recoilBackMaxDeltaStrips)
        } else {
            return false
        }
    }
    
    /**
     Метод проверяет находится ли осколок event на соседних стрипах относительно первого осколка.
     */
    func isFissionNearToFirstFissionFront(_ event: ISAEvent) -> Bool {
        let strip_0_15 = event.param2 >> 12
        let strip_0_15_first_fission = p.firstFissionAlphaInfo[kStrip0_15] as! Int
        if Int(strip_0_15) == strip_0_15_first_fission { // совпадают
            return true
        }
        
        let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId: event.eventId)
        let strip_1_48_first_fission = p.firstFissionAlphaInfo[kStrip1_48] as! Int
        return abs(Int32(Int(strip_1_48) - strip_1_48_first_fission)) <= 1 // +/- 1 стрип
    }
    
    /**
     У осколков/рекойлов записывается только время относительно начала нового счетчика времени (счетчик обновляется каждые 0xFFFF мкс).
     Для вычисления времени от запуска файла используем время цикла.
     */
    func absTime(_ relativeTime: CUnsignedShort, cycleEvent: ISAEvent) -> CUnsignedLongLong {
        return CUnsignedLongLong(cycleEvent.param3 << 16) + CUnsignedLongLong(cycleEvent.param1) + CUnsignedLongLong(relativeTime)
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
    
    /**
     Чтобы различить рекоил и осколок/альфу используем первые 3 бита из param3:
     000 - осколок,
     100 - рекоил
     */
    func getMarker(_ value_16_bits: CUnsignedShort) -> CUnsignedShort {
        return value_16_bits >> 13
    }
    
    func fissionAlphaRecoilEncoderForEventId(_ eventId: Int) -> CUnsignedShort {
        if (p.dataProtocol.AFron(1) == eventId || p.dataProtocol.ABack(1) == eventId || p.dataProtocol.AdFr(1) == eventId || p.dataProtocol.AdBk(1) == eventId || p.dataProtocol.AWel(1) == eventId || p.dataProtocol.AWel == eventId) {
            return 1
        }
        if (p.dataProtocol.AFron(2) == eventId || p.dataProtocol.ABack(2) == eventId || p.dataProtocol.AdFr(2) == eventId || p.dataProtocol.AdBk(2) == eventId || p.dataProtocol.AWel(2) == eventId) {
            return 2
        }
        if (p.dataProtocol.AFron(3) == eventId || p.dataProtocol.ABack(3) == eventId || p.dataProtocol.AdFr(3) == eventId || p.dataProtocol.AdBk(3) == eventId || p.dataProtocol.AWel(3) == eventId) {
            return 3
        }
        if (p.dataProtocol.AWel(4) == eventId) {
            return 4
        }
        return 0
    }
    
    /**
     Маркер отличающий осколок/альфу (0) от рекойла (4), записывается в первые 3 бита param3.
     */
    fileprivate let kFissionOrAlphaMarker: CUnsignedShort = 0b000
    fileprivate let kRecoilMarker: CUnsignedShort = 0b100
    
    func isGammaEvent(_ event: ISAEvent) -> Bool {
        let eventId = Int(event.eventId)
        return p.dataProtocol.Gam(1) == eventId || p.dataProtocol.Gam(2) == eventId || p.dataProtocol.Gam == eventId
    }
    
    func isFront(_ event: ISAEvent, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let marker = getMarker(event.param3)
        let typeMarker = type == SearchType.recoil ? kRecoilMarker : kFissionOrAlphaMarker
        return (typeMarker == marker) && (p.dataProtocol.AFron(1) == eventId || p.dataProtocol.AFron(2) == eventId || p.dataProtocol.AFron(3) == eventId || p.dataProtocol.AdFr(1) == eventId || p.dataProtocol.AdFr(2) == eventId || p.dataProtocol.AdFr(3) == eventId)
    }
    
    func isFissionOrAlphaWel(_ event: ISAEvent) -> Bool {
        let eventId = Int(event.eventId)
        let marker = getMarker(event.param3)
        return (kFissionOrAlphaMarker == marker) && (p.dataProtocol.AWel == eventId || p.dataProtocol.AWel(1) == eventId || p.dataProtocol.AWel(2) == eventId || p.dataProtocol.AWel(3) == eventId || p.dataProtocol.AWel(4) == eventId)
    }
    
    func isBack(_ event: ISAEvent, type: SearchType) -> Bool {
        let eventId = Int(event.eventId)
        let marker = getMarker(event.param3)
        let typeMarker = type == SearchType.recoil ? kRecoilMarker : kFissionOrAlphaMarker
        return (typeMarker == marker) && (p.dataProtocol.ABack(1) == eventId || p.dataProtocol.ABack(2) == eventId || p.dataProtocol.ABack(3) == eventId || p.dataProtocol.AdBk(1) == eventId || p.dataProtocol.AdBk(2) == eventId || p.dataProtocol.AdBk(3) == eventId)
    }
    
    func eventNumber() -> CUnsignedLongLong {
        var position = fpos_t()
        fgetpos(p.file, &position)
        return CUnsignedLongLong(position/Int64(eventSize)) + p.totalEventNumber + 1
    }
    
    func channelForTOF(_ event :ISAEvent) -> CUnsignedShort {
        return event.param3 & Mask.TOF.rawValue
    }
    
    func getEnergy(_ event: ISAEvent, type: SearchType) -> Double {
        let channel = type == SearchType.fission ? (event.param2 & Mask.fission.rawValue) : (event.param3 & Mask.recoilAlpha.rawValue)
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
        if p.dataProtocol.AFron(1) == eventId || p.dataProtocol.AFron(2) == eventId || p.dataProtocol.AFron(3) == eventId {
            position = "Fron"
        } else if p.dataProtocol.ABack(1) == eventId || p.dataProtocol.ABack(2) == eventId || p.dataProtocol.ABack(3) == eventId {
            position = "Back"
        } else if p.dataProtocol.AdFr(1) == eventId || p.dataProtocol.AdFr(2) == eventId || p.dataProtocol.AdFr(3) == eventId {
            position = "dFr"
        } else if p.dataProtocol.AdBk(1) == eventId || p.dataProtocol.AdBk(2) == eventId || p.dataProtocol.AdBk(3) == eventId {
            position = "dBk"
        } else {
            position = "Wel"
        }
        
        let name = String(format: "%@%@%d.%d", detector, position, encoder, strip_0_15+1)
        return p.calibration.calibratedValueForAmplitude(Double(channel), eventName: name)
    }
    
    func currentFileEventNumber(_ number: CLongLong) -> String {
        return String(format: "%@_%llu", p.currentFileName, number)
    }

}
