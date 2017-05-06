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
            fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
            
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
    @objc func search(directions: Set<NSNumber>, startTime: CUnsignedLongLong, minDeltaTime: CUnsignedLongLong, maxDeltaTime: CUnsignedLongLong, useCycleTime: Bool, updateCycleEvent: Bool, checker: @escaping ((ISAEvent, CUnsignedLongLong, CLongLong, UnsafeMutablePointer<Bool>)->())) {
        //TODO: работает в пределах одного файла
        if directions.contains(SearchDirection.backward.rawValue as NSNumber) {
            var initial = fpos_t()
            fgetpos(p.file, &initial)
            
            var cycleEvent = p.mainCycleTimeEvent
            var current = Int(initial)
            while current > -1 {
                current -= MemoryLayout<ISAEvent>.size
                fseek(p.file, current, SEEK_SET)
                
                var event = ISAEvent()
                fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
                
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
                fread(&event, MemoryLayout<ISAEvent>.size, 1, p.file)
                
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
    
    // MARK: - Helpers
    
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
        return CUnsignedLongLong(position/Int64(MemoryLayout<ISAEvent>.size)) + p.totalEventNumber + 1
    }
    
    func channelForTOF(_ event :ISAEvent) -> CUnsignedShort {
        return event.param3 & Mask.TOF.rawValue
    }

}
