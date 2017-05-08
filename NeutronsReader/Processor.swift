//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 26/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import Cocoa

class Processor: NSObject {
    
    var p: ISAProcessor! // used during mirgation to Swift phase
    
    // MARK: - Algorithms
    
    enum SearchDirection {
        case forward, backward
    }
    
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
    
    /**
     Note: use SearchDirection values in 'directions'.
     */
    func search(directions: Set<SearchDirection>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((ISAEvent, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: работает в пределах одного файла
        if directions.contains(.backward) {
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
        
        if directions.contains(.forward) {
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
    
    // MARK: - Search
    
    func mainCycleEventCheck(_ event: ISAEvent) {
        if Int(event.eventId) == p.dataProtocol.CycleTime {
            p.mainCycleTimeEvent = event
        }
        
        // FFron or AFron
        if isFront(event, type: p.startParticleType) {
            // Запускаем новый цикл поиска, только если энергия осколка/альфы на лицевой стороне детектора выше минимальной
            let energy = getEnergy(event, type: p.startParticleType)
            if energy < p.fissionAlphaFrontMinEnergy || energy > p.fissionAlphaFrontMaxEnergy {
                return
            }
            storeFissionAlphaFront(event, isFirst: true, deltaTime: 0)
            
            var position = fpos_t()
            fgetpos(p.file, &position)
            
            // Alpha 2
            if p.searchAlpha2 {
                findAlpha2()
                fseek(p.file, Int(position), SEEK_SET)
                if 0 == p.alpha2FrontPerAct.count {
                    clearActInfo()
                    return
                }
            }
            
            // Gamma
            findGamma()
            fseek(p.file, Int(position), SEEK_SET)
            if p.requiredGamma && 0 == p.gammaPerAct.count {
                clearActInfo()
                return
            }
            
            // FBack or ABack
            findFissionsAlphaBack()
            fseek(p.file, Int(position), SEEK_SET)
            if p.requiredFissionRecoilBack && 0 == p.fissionsAlphaBackPerAct.count {
                clearActInfo()
                return
            }
            
            // Recoil (Ищем рекойлы только после поиска всех FBack/ABack!)
            findRecoil()
            fseek(p.file, Int(position), SEEK_SET)
            if p.requiredRecoil && 0 == p.recoilsFrontPerAct.count {
                clearActInfo()
                return
            }
            
            // Neutrons
            if p.searchNeutrons {
                findNeutrons()
                fseek(p.file, Int(position), SEEK_SET)
            }
            
            // FON & Recoil Special && TOF Generations
            findFONEvents()
            fseek(p.file, Int(position), SEEK_SET)
            
            // FWel or AWel
            findFissionsAlphaWel()
            fseek(p.file, Int(position), SEEK_SET)
            
            /*
             ВАЖНО: тут не делаем репозиционирование в потоке после поиска!
             Этот подцикл поиска всегда должен быть последним!
             */
            // Summ(FFron or AFron)
            if p.summarizeFissionsAlphaFront {
                findFissionsAlphaFront()
            }
            
            // Завершили поиск корреляций
            if p.searchNeutrons {
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
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
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
        
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: true) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: self.p.startParticleType) && self.isFissionNearToFirstFissionFront(event) { // FFron/AFron пришедшие после первого
                self.storeFissionAlphaFront(event, isFirst: false, deltaTime: deltaTime)
            }
        }
    }
    
    /**
     Ищем ВСЕ! Gam в окне до _maxGammaTime относительно времени Fission Front (в двух направлениях).
     */
    func findGamma() {
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.maxGammaTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
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
        search(directions: directions, startTime: p.firstFissionAlphaTime, minDeltaTime: 0, maxDeltaTime: p.fissionAlphaMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            let type = self.p.startParticleType
            if self.isBack(event, type: type) {
                let energy = self.getEnergy(event, type: type)
                if energy >= self.p.fissionAlphaFrontMinEnergy && energy <= self.p.fissionAlphaFrontMaxEnergy {
                    self.storeFissionAlphaBack(event, deltaTime: deltaTime)
                }
            }
        }
        
        if p.fissionsAlphaBackPerAct.count > 1 {
            let dict = p.fissionsAlphaBackPerAct.sorted(by: { (obj1: Any, obj2: Any) -> Bool in
                func energy(_ o: Any) -> Double {
                    return (o as! NSDictionary)[kEnergy] as? Double ?? 0
                }
                return energy(obj1) > energy(obj2)
            }).first as? NSDictionary
            if let dict = dict, let encoder = dict[kEncoder] as? CUnsignedShort, let strip0_15 = dict[kStrip0_15] as? CUnsignedShort {
                let strip1_48 = stripConvertToFormat_1_48(strip0_15, encoder: encoder)
                p.fissionsAlphaBackPerAct = (p.fissionsAlphaBackPerAct as NSArray).filter( { (obj: Any) -> Bool in
                    let item = obj as! NSDictionary
                    if item == dict {
                        return true
                    }
                    let e = item[kEncoder] as! CUnsignedShort
                    let s0_15 = item[kStrip0_15] as! CUnsignedShort
                    let s1_48 = self.stripConvertToFormat_1_48(s0_15, encoder: e)
                    // TODO: new input field for _fissionBackMaxDeltaStrips
                    return abs(Int32(strip1_48) - Int32(s1_48)) <= Int32(p.recoilBackMaxDeltaStrips)
                }) as! NSMutableArray
            }
        }
    }
    
    /**
     Поиск рекойла осуществляется с позиции файла где найден главный осколок/альфа (возвращаемся назад по времени).
     */
    func findRecoil() {
        let fissionTime = absTime(CUnsignedShort(p.firstFissionAlphaTime), cycleEvent:p.mainCycleTimeEvent)
        let directions: Set<SearchDirection> = [.backward]
        search(directions: directions, startTime: fissionTime, minDeltaTime: p.recoilMinTime, maxDeltaTime: p.recoilMaxTime, useCycleTime: true, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: .recoil) && self.isEventFrontNearToFirstFissionAlphaFront(event, maxDelta: Int(self.p.recoilFrontMaxDeltaStrips)) {
                let energy = self.getEnergy(event, type: .recoil)
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
                            self.storeRecoil(event, deltaTime: deltaTime)
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
        let directions: Set<SearchDirection> = [.forward, .backward]
        search(directions: directions, startTime: timeRecoil, minDeltaTime: 0, maxDeltaTime: p.maxTOFTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.p.dataProtocol.TOF == Int(event.eventId) {
                let value = self.valueTOF(event, eventRecoil: eventRecoil)
                if value >= self.p.minTOFValue && value <= self.p.maxTOFValue {
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
        search(directions: directions, startTime: timeRecoilFront, minDeltaTime: 0, maxDeltaTime: p.recoilBackMaxTime, useCycleTime: false, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isBack(event, type: .recoil) {
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
                    self.storeFON(event)
                    fonFound = true
                }
            } else if self.p.dataProtocol.RecoilSpecial == Int(event.eventId) {
                if !recoilFound {
                    self.storeRecoilSpecial(event)
                    recoilFound = true
                }
            } else if self.p.dataProtocol.TOF == Int(event.eventId) {
                if !tofFound {
                    let deltaTime = fabs(Double(event.param1) - Double(self.p.firstFissionAlphaTime))
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
        let alphaTime = absTime(CUnsignedShort(p.firstFissionAlphaTime), cycleEvent: p.mainCycleTimeEvent)
        let directions: Set<SearchDirection> = [.forward]
        search(directions: directions, startTime: alphaTime, minDeltaTime: p.alpha2MinTime, maxDeltaTime: p.alpha2MaxTime, useCycleTime: true, updateCycleEvent: false) { (event: ISAEvent, time: CUnsignedLongLong, deltaTime: CLongLong, stop: UnsafeMutablePointer<Bool>) in
            if self.isFront(event, type: .alpha) {
                let energy = self.getEnergy(event, type: .alpha)
                if energy >= self.p.alpha2MinEnergy && energy <= self.p.alpha2MaxEnergy && self.isEventFrontNearToFirstFissionAlphaFront(event, maxDelta: Int(self.p.alpha2MaxDeltaStrips)) {
                    self.storeAlpha2(event, deltaTime: deltaTime)
                }
            }
        }
    }
    
    // MARK: - Storage
    
    func storeFissionAlphaBack(_ event: ISAEvent, deltaTime: CLongLong) {
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12  // value from 0 to 15
        let energy = getEnergy(event, type: p.startParticleType)
        let info: NSDictionary = [kEncoder: encoder,
                                  kStrip0_15: strip_0_15,
                                  kEnergy: energy,
                                  kEventNumber: eventNumber(),
                                  kDeltaTime: deltaTime]
        p.fissionsAlphaBackPerAct.add(info)
    }
    
    /**
     Используется для определения суммарной множественности нейтронов во всех файлах
     */
    func updateNeutronsMultiplicity() {
        let key = p.neutronsSummPerAct
        var summ = (p.neutronsMultiplicityTotal[key] as? CUnsignedLongLong) ?? 0
        summ += 1 // Одно событие для всех нейтронов в одном акте деления
        p.neutronsMultiplicityTotal[key] = summ
    }
    
    func storeFissionAlphaFront(_ event: ISAEvent, isFirst: Bool, deltaTime: CLongLong) {
        let channel = p.startParticleType == .fission ? (event.param2 & Mask.fission.rawValue) : (event.param3 & Mask.recoilAlpha.rawValue)
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12 // value from 0 to 15
        let energy = getEnergy(event, type: p.startParticleType)
        let info: NSDictionary = [kEncoder: encoder,
                                  kStrip0_15: strip_0_15,
                                  kChannel: channel,
                                  kEnergy: energy,
                                  kEventNumber: eventNumber(),
                                  kDeltaTime: deltaTime]
        p.fissionsAlphaFrontPerAct.add(info)
        
        if isFirst {
            let strip_1_48 = focalStripConvertToFormat_1_48(strip_0_15, eventId: event.eventId)
            let extraInfo = info.mutableCopy() as! NSMutableDictionary
            extraInfo[kStrip1_48] = strip_1_48
            p.firstFissionAlphaInfo = extraInfo as! [AnyHashable : Any]
            p.firstFissionAlphaTime = UInt64(event.param1)
        }
    }
    
    func storeGamma(_ event: ISAEvent, deltaTime: CLongLong) {
        let channel = event.param3 & Mask.gamma.rawValue
        let energy = p.calibration.calibratedValueForAmplitude(Double(channel), eventName: "Gam1") // TODO: Gam2, Gam
        let info: NSDictionary = [kEnergy: energy,
                                  kDeltaTime: deltaTime]
        p.gammaPerAct.add(info)
    }
    
    func storeRecoil(_ event: ISAEvent, deltaTime: CLongLong) {
        let energy = getEnergy(event, type: .recoil)
        let info: NSDictionary = [kEnergy: energy,
                                  kDeltaTime: deltaTime,
                                  kEventNumber: eventNumber()]
        p.recoilsFrontPerAct.add(info)
    }
    
    func storeAlpha2(_ event: ISAEvent, deltaTime: CLongLong) {
        let energy = getEnergy(event, type: .alpha)
        let info: NSDictionary = [kEnergy: energy,
                                  kDeltaTime: deltaTime,
                                  kEventNumber: eventNumber()]
        p.alpha2FrontPerAct.add(info)
    }
    
    func storeRealTOFValue(_ value: Double, deltaTime: CLongLong) {
        let info: NSDictionary = [kValue: value,
                                  kDeltaTime: deltaTime]
        p.tofRealPerAct.add(info)
    }
    
    func storeFissionAlphaWell(_ event: ISAEvent) {
        let energy = getEnergy(event, type: p.startParticleType)
        let encoder = fissionAlphaRecoilEncoderForEventId(Int(event.eventId))
        let strip_0_15 = event.param2 >> 12  // value from 0 to 15
        let info: NSDictionary = [kEncoder: encoder,
                                  kStrip0_15: strip_0_15,
                                  kEnergy: energy]
        p.fissionsAlphaWelPerAct.add(info)
    }
    
    func storeTOFGenerations(_ event: ISAEvent) {
        let channel = event.param3 & Mask.TOF.rawValue
        p.tofGenerationsPerAct.add(channel)
    }
    
    func storeFON(_ event: ISAEvent) {
        let channel = event.param3 & Mask.FON.rawValue
        p.fonPerAct = channel as NSNumber
    }
    
    func storeRecoilSpecial(_ event: ISAEvent) {
        let channel = event.param3 & Mask.recoilSpecial.rawValue
        p.recoilSpecialPerAct = channel as NSNumber
    }
    
    func clearActInfo() {
        p.neutronsSummPerAct = 0
        p.fissionsAlphaFrontPerAct.removeAllObjects()
        p.fissionsAlphaBackPerAct.removeAllObjects()
        p.gammaPerAct.removeAllObjects()
        p.tofGenerationsPerAct.removeAllObjects()
        p.fissionsAlphaWelPerAct.removeAllObjects()
        p.recoilsFrontPerAct.removeAllObjects()
        p.alpha2FrontPerAct.removeAllObjects()
        p.tofRealPerAct.removeAllObjects()
        p.firstFissionAlphaInfo = nil
        p.fonPerAct = nil
        p.recoilSpecialPerAct = nil
    }
    
    // MARK: - Helpers
    
    fileprivate var eventSize: Int {
        return MemoryLayout<ISAEvent>.size
    }
    
    func fissionAlphaBackWithMaxEnergyInAct() -> NSDictionary? {
        var fission: NSDictionary?
        var maxE: Double = 0
        for info in p.fissionsAlphaBackPerAct {
            if let dict = info as? NSDictionary, let e = dict[kEnergy] as? Double {
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
        if let fissionBackInfo = fissionAlphaBackWithMaxEnergyInAct() {
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
        let typeMarker = type == .recoil ? kRecoilMarker : kFissionOrAlphaMarker
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
        let typeMarker = type == .recoil ? kRecoilMarker : kFissionOrAlphaMarker
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
    
    func nanosecondsForTOFChannel(_ channelTOF: CUnsignedShort, eventRecoil: ISAEvent) -> Double {
        let eventId = Int(eventRecoil.eventId)
        let strip_0_15 = eventRecoil.param2 >> 12  // value from 0 to 15
        let encoder = fissionAlphaRecoilEncoderForEventId(eventId)
        var position: String
        if p.dataProtocol.AFron(1) == eventId || p.dataProtocol.AFron(2) == eventId || p.dataProtocol.AFron(3) == eventId {
            position = "Fron"
        } else {
            position = "Back"
        }
        let name = String(format: "T%@%d.%d", position, encoder, strip_0_15+1)
        return p.calibration.calibratedValueForAmplitude(Double(channelTOF), eventName: name)
    }
    
    func valueTOF(_ eventTOF: ISAEvent, eventRecoil: ISAEvent) -> Double {
        let channel = channelForTOF(eventTOF)
        if p.unitsTOF == .channels {
            return Double(channel)
        } else {
            return nanosecondsForTOFChannel(channel, eventRecoil: eventRecoil)
        }
    }
    
    // MARK: - Output
    
    func logInput() {
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        let image = appDelegate.window.screenshot()
        p.logger.logInput(image)
    }
    
    func logCalibration() {
        p.logger.logCalibration(p.calibration.stringValue ?? "")
    }
    
    func logResultsHeader() {
        let startParticle = p.startParticleType == .fission ? "F" : "A"
        var header = String(format: "Event(Recoil),E(RFron),dT(RFron-$Fron),TOF,dT(TOF-RFron),Event($),Summ($Fron),$Fron,dT($FronFirst-Next),Strip($Fron),$Back,dT($Fron-$Back),Strip($Back),$Wel,$WelPos,Neutrons,Gamma,dT($Fron-Gamma),FON,Recoil(Special)")
        if p.searchAlpha2 {
            header += ",Event(Alpha2),E(Alpha2),dT(Alpha1-Alpha2)"
        }
        header = header.replacingOccurrences(of: "$", with: startParticle)
        let components = header.components(separatedBy: ",")
        p.logger.writeLineOfFields(components as [AnyObject])
        p.logger.finishLine() // +1 line padding
    }
    
    func logActResults() {
        func getValueFrom(array: NSArray, row: Int, key: String) -> Any? {
            return (array[row] as? [String: Any])?[key]
        }
        
        var columnsCount = 19
        if p.searchAlpha2 {
            columnsCount += 3
        }
        let rowsMax = max(max(max(max(max(1, p.gammaPerAct.count), p.fissionsAlphaWelPerAct.count), p.recoilsFrontPerAct.count), p.fissionsAlphaBackPerAct.count), p.fissionsAlphaFrontPerAct.count)
        for row in 0 ..< rowsMax {
            for column in 0...columnsCount {
                var field = ""
                switch column {
                case 0:
                    if row < p.recoilsFrontPerAct.count {
                        if let eventNumberObject = getValueFrom(array: p.recoilsFrontPerAct, row: row, key: kEventNumber) as? CLongLong {
                            field = currentFileEventNumber(eventNumberObject)
                        }
                    }
                case 1:
                    if row < p.recoilsFrontPerAct.count {
                        if let recoilEnergy = getValueFrom(array: p.recoilsFrontPerAct, row: row, key: kEnergy) as? Double {
                            field = String(format: "%.7f", recoilEnergy)
                        }
                    }
                case 2:
                    if row < p.recoilsFrontPerAct.count {
                        if let deltaTimeRecoilFission = getValueFrom(array: p.recoilsFrontPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = String(format: "%lld", deltaTimeRecoilFission)
                        }
                    }
                case 3:
                    if row < p.tofRealPerAct.count {
                        if let tof = getValueFrom(array: p.tofRealPerAct, row: row, key: kValue) as? CUnsignedShort {
                            field = String(format: "%hu", tof)
                        }
                    }
                case 4:
                    if row < p.tofRealPerAct.count {
                        if let deltaTimeTOFRecoil = getValueFrom(array: p.tofRealPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = String(format: "%lld", deltaTimeTOFRecoil)
                        }
                    }
                case 5:
                    if row < p.fissionsAlphaFrontPerAct.count {
                        if let eventNumber = getValueFrom(array: p.fissionsAlphaFrontPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = currentFileEventNumber(eventNumber)
                        }
                    }
                case 6:
                    if row == 0 {
                        var summ: Double = 0
                        for info in p.fissionsAlphaFrontPerAct {
                            let energy = ((info as? [String: Any])?[kEnergy] as? Double) ?? 0
                            summ += energy
                        }
                        field = String(format: "%.7f", summ)
                    }
                case 7:
                    if row < p.fissionsAlphaFrontPerAct.count {
                        if let energy = getValueFrom(array: p.fissionsAlphaFrontPerAct, row: row, key: kEnergy) as? Double {
                            field = String(format: "%.7f", energy)
                        }
                    }
                case 8:
                    if row < p.fissionsAlphaFrontPerAct.count {
                        if let deltaTime = getValueFrom(array: p.fissionsAlphaFrontPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = String(format: "%lld", deltaTime)
                        }
                    }
                case 9:
                    if row < p.fissionsAlphaFrontPerAct.count {
                        if let info = p.fissionsAlphaFrontPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15] as? CUnsignedShort, let encoder = info[kEncoder] as? CUnsignedShort {
                            let strip = stripConvertToFormat_1_48(strip_0_15, encoder: encoder)
                            field = String(format: "%d", strip)
                        }
                    }
                case 10:
                    if row < p.fissionsAlphaBackPerAct.count {
                        if let energy = getValueFrom(array: p.fissionsAlphaBackPerAct, row: row, key: kEnergy) as? Double {
                            field = String(format: "%.7f", energy)
                        }
                    }
                case 11:
                    if row < p.fissionsAlphaBackPerAct.count {
                        if let deltaTime = getValueFrom(array: p.fissionsAlphaBackPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = String(format: "%lld", deltaTime)
                        }
                    }
                case 12:
                    if row < p.fissionsAlphaBackPerAct.count {
                        if let info = p.fissionsAlphaBackPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15] as? CUnsignedShort, let encoder = info[kEncoder] as? CUnsignedShort {
                            let strip = stripConvertToFormat_1_48(strip_0_15, encoder: encoder)
                            field = String(format: "%d", strip)
                        }
                    }
                case 13:
                    if row < p.fissionsAlphaWelPerAct.count {
                        if let energy = getValueFrom(array: p.fissionsAlphaWelPerAct, row: row, key: kEnergy) as? Double {
                            field = String(format: "%.7f", energy)
                        }
                    }
                case 14:
                    if row < p.fissionsAlphaWelPerAct.count {
                        if let info = p.fissionsAlphaWelPerAct[row] as? [String: Any], let strip_0_15 = info[kStrip0_15] as? CUnsignedShort, let encoder = info[kEncoder] as? CUnsignedShort {
                            field = String(format: "FWel%d.%d", encoder, strip_0_15 + 1)
                        }
                    }
                case 15:
                    if row == 0 && p.searchNeutrons {
                        field = String(format: "%llu", p.neutronsSummPerAct)
                    }
                case 16:
                    if row < p.gammaPerAct.count {
                        if let energy = getValueFrom(array: p.gammaPerAct, row: row, key: kEnergy) as? Double {
                            field = String(format: "%.7f", energy)
                        }
                    }
                case 17:
                    if row < p.gammaPerAct.count {
                        if let deltaTime = getValueFrom(array: p.gammaPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = String(format: "%llu", deltaTime)
                        }
                    }
                case 18:
                    if row == 0 {
                        if let v = p.fonPerAct as? CUnsignedShort {
                            field = String(format: "%hu", v)
                        }
                    }
                case 19:
                    if row == 0 {
                        if let v = p.recoilSpecialPerAct as? CUnsignedShort {
                            field = String(format: "%hu", v)
                        }
                    }
                case 20:
                    if row < p.alpha2FrontPerAct.count {
                        if let eventNumber = getValueFrom(array: p.alpha2FrontPerAct, row: row, key: kEventNumber) as? CLongLong {
                            field = currentFileEventNumber(eventNumber)
                        }
                    }
                case 21:
                    if row < p.alpha2FrontPerAct.count {
                        if let energy = getValueFrom(array: p.alpha2FrontPerAct, row: row, key: kEnergy) as? Double {
                            field = String(format: "%.7f", energy)
                        }
                    }
                case 22:
                    if row < p.alpha2FrontPerAct.count {
                        if let deltaTime = getValueFrom(array: p.alpha2FrontPerAct, row: row, key: kDeltaTime) as? CLongLong {
                            field = String(format: "%lld", deltaTime)
                        }
                    }
                default:
                    break
                }
                p.logger.writeField(field as AnyObject)
            }
            p.logger.finishLine()
        }
    }

}
