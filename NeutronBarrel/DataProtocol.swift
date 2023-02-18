//
//  DataProtocol.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

enum TOFKind: String {
    case TOF = "TOF"
    case TOF2 = "TOF2"
}

class DataProtocol {
    
    fileprivate var dict = [String: Int]() {
        didSet {
            AVeto = dict["AVeto"]
            TOF = dict[TOFKind.TOF.rawValue]
            TOF2 = dict[TOFKind.TOF2.rawValue]
            NeutronsOld = dict["Neutrons"]
            Neutrons_N = getValues(ofTypes: ["N1", "N2", "N3", "N4"], prefix: false)
            NeutronsNew = getValues(ofTypes: ["NNeut"])
            CycleTime = dict["THi"]
            BeamEnergy = dict["EnergyHi"]
            BeamCurrent = dict["BeamTokHi"]
            BeamBackground = dict["BeamFonHi"]
            BeamIntegral = dict["IntegralHi"]
            AlphaWell = getValues(ofTypes: ["AWel"])
            AlphaWellFront = getValues(ofTypes: ["AWFr"])
            AlphaWellBack = getValues(ofTypes: ["AWBk"])
            AlphaMotherFront = getValues(ofTypes: ["AFr"])
            AlphaDaughterFront = getValues(ofTypes: ["AdFr"])
            AlphaFront = AlphaMotherFront.union(AlphaDaughterFront)
            AlphaMotherBack = getValues(ofTypes: ["ABack", "ABk"])
            AlphaDaughterBack = getValues(ofTypes: ["AdBk"])
            AlphaBack = AlphaMotherBack.union(AlphaDaughterBack)
            Gamma = getValues(ofTypes: ["Gam"])
        }
    }
    
    fileprivate func getValues(ofTypes types: [String], prefix: Bool = true) -> Set<Int> {
        var result = [Int]()
        for type in types {
            let values = dict.filter({ (key: String, value: Int) -> Bool in
                if prefix {
                    return self.keyFor(value: value)?.hasPrefix(type) == true
                } else {
                    return self.keyFor(value: value) == type
                }
            }).values
            result.append(contentsOf: values)
        }
        return Set(result)
    }
    
    fileprivate var BeamEnergy: Int?
    fileprivate var BeamCurrent: Int?
    fileprivate var BeamBackground: Int?
    fileprivate var BeamIntegral: Int?
    fileprivate var AVeto: Int?
    fileprivate var TOF: Int?
    fileprivate var TOF2: Int?
    fileprivate var NeutronsOld: Int?
    fileprivate var Neutrons_N = Set<Int>()
    fileprivate var NeutronsNew = Set<Int>()
    fileprivate var CycleTime: Int?
    fileprivate var AlphaWell = Set<Int>()
    fileprivate var AlphaWellFront = Set<Int>()
    fileprivate var AlphaWellBack = Set<Int>()
    fileprivate var AlphaMotherFront = Set<Int>()
    fileprivate var AlphaDaughterFront = Set<Int>()
    fileprivate var AlphaFront = Set<Int>()
    fileprivate var AlphaMotherBack = Set<Int>()
    fileprivate var AlphaDaughterBack = Set<Int>()
    fileprivate var AlphaBack = Set<Int>()
    fileprivate var Gamma = Set<Int>()
    
    fileprivate var isAlphaCache = [Int: Bool]()
    func isAlpha(eventId: Int) -> Bool {
        if let b = isAlphaCache[eventId] {
            return b
        } else {
            var b = false
            for s in [AlphaFront, AlphaBack, AlphaWell, AlphaWellFront, AlphaWellBack, AlphaMotherFront, AlphaMotherBack, AlphaDaughterFront, AlphaDaughterBack] {
                if s.contains(eventId) {
                    b = true
                    break
                }
            }
            isAlphaCache[eventId] = b
            return b
        }
    }
    
    class func load(_ path: String?) -> DataProtocol {
        var result = [String: Int]()
        if let path = path {
            do {
                var content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                content = content.replacingOccurrences(of: " ", with: "")
                
                let words = Event.words
                for line in content.components(separatedBy: CharacterSet.newlines) {
                    if false == line.contains(":") || line.starts(with: "#") {
                        continue
                    }
                    
                    let set = CharacterSet(charactersIn: ":,")
                    let components = line.components(separatedBy: set).filter() { $0 != "" }
                    let count = components.count
                    if words == count {
                        let key = components[count-1]
                        let value = Int(components[0])
                        result[key] = value
                    }
                }
            } catch {
                print("Error load protocol from file at path \(path): \(error)")
            }
        }
        
        let p = DataProtocol()
        p.dict = result
        if p.dict.count == 0 {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Please select protocol!"
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        }
        
        p.encoderForEventIdCache.removeAll()
        p.isValidEventIdForTimeCheckCache.removeAll()
        return p
    }
    
    fileprivate var isValidEventIdForTimeCheckCache = [Int: Bool]()
    
    /**
     Not all events have time data.
     */
    func isValidEventIdForTimeCheck(_ eventId: Int) -> Bool {
        if let cached = isValidEventIdForTimeCheckCache[eventId] {
            return cached
        }
        
        let value = isAlpha(eventId: eventId) || isTOFEvent(eventId) != nil || isGammaEvent(eventId) || isNeutronsOldEvent(eventId) || isNeutronsNewEvent(eventId) || isNeutrons_N_Event(eventId) || isVETOEvent(eventId)
        isValidEventIdForTimeCheckCache[eventId] = value
        return value
    }
    
    func keyFor(value: Int) -> String? {
        if isAlphaFronEvent(value) {
            return "FocalFront"
        } else if isAlphaBackEvent(value) {
            return "FocalBack"
        } else if isAlphaWellFrontEvent(value) {
            return "WellFront"
        } else if isAlphaWellBackEvent(value) {
            return "WellBack"
        } else if isNeutronsNewEvent(value) {
            return "Neutrons"
        } else {
            // TODO: !!!
            return nil
        }
//        for (k, v) in dict {
//            if v == value {
//                return k
//            }
//        }
//        return nil
    }
    
    func position(_ eventId: Int) -> String {
        if AlphaMotherFront.contains(eventId) {
            return "Fron"
        } else if AlphaMotherBack.contains(eventId) {
            return "Back"
        } else if AlphaDaughterFront.contains(eventId) {
            return "dFron"
        } else if AlphaDaughterBack.contains(eventId) {
            return "dBack"
        } else if isVETOEvent(eventId) {
            return "Veto"
        } else if isGammaEvent(eventId) {
            return "Gam"
        } else if isAlphaWellBackEvent(eventId) {
            return "WBack"
        } else if isAlphaWellFrontEvent(eventId) {
            return "WFront"
        } else {
            return "Wel"
        }
    }
    
    
    
    
    
    
    
    
    let eventIdsFocalFront = Set(0...127)
    let eventIdsFocalBack = Set(128...255)
    let eventIdsWellFront = Set(256...383)
    let eventIdsWellBack = Set(384...511)
    let eventIdsNeutrons = Set(512...640)
    
    func isAlphaFronEvent(_ eventId: Int) -> Bool {
        return eventIdsFocalFront.contains(eventId)
    }
    
    func isAlphaBackEvent(_ eventId: Int) -> Bool {
        return eventIdsFocalBack.contains(eventId)
    }
    
    func isAlphaWellEvent(_ eventId: Int) -> Bool {
        return eventIdsWellFront.contains(eventId) || eventIdsWellBack.contains(eventId)
    }
    
    func isAlphaWellFrontEvent(_ eventId: Int) -> Bool {
        return eventIdsWellFront.contains(eventId)
    }
    
    func isAlphaWellBackEvent(_ eventId: Int) -> Bool {
        return eventIdsWellBack.contains(eventId)
    }
    
    func isNeutronsNewEvent(_ eventId: Int) -> Bool {
        return eventIdsNeutrons.contains(eventId)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func isGammaEvent(_ eventId: Int) -> Bool {
        return Gamma.contains(eventId)
    }
    
    func isVETOEvent(_ eventId: Int) -> Bool {
        return AVeto == eventId
    }
    
    func isTOFEvent(_ eventId: Int) -> TOFKind? {
        if TOF == eventId {
            return .TOF
        } else if TOF2 == eventId {
            return .TOF2
        }
        return nil
    }
    
    func isNeutronsOldEvent(_ eventId: Int) -> Bool {
        return NeutronsOld == eventId
    }
    
    func isNeutrons_N_Event(_ eventId: Int) -> Bool {
        return Neutrons_N.contains(eventId)
    }
    
    func hasNeutrons_N() -> Bool {
        return Neutrons_N.count > 0
    }
    
    func isCycleTimeEvent(_ eventId: Int) -> Bool {
        return CycleTime == eventId
    }
    
    func isBeamEnergy(_ eventId: Int) -> Bool {
        return BeamEnergy == eventId
    }
    
    func isBeamCurrent(_ eventId: Int) -> Bool {
        return BeamCurrent == eventId
    }
    
    func isBeamBackground(_ eventId: Int) -> Bool {
        return BeamBackground == eventId
    }
    
    func isBeamIntegral(_ eventId: Int) -> Bool {
        return BeamIntegral == eventId
    }
    
    fileprivate var encoderForEventIdCache = [Int: CUnsignedShort]()
    
    func encoderForEventId(_ eventId: Int) -> CUnsignedShort {
        if let cached = encoderForEventIdCache[eventId] {
            return cached
        }
        
        var value: CUnsignedShort
        if let key = keyFor(value: eventId), let rangeDigits = key.rangeOfCharacter(from: .decimalDigits), let substring = String(key[rangeDigits.lowerBound...]).components(separatedBy: CharacterSet.init(charactersIn: "., ")).first, let encoder = Int(substring) {
            value = CUnsignedShort(encoder)
        } else if (AlphaWell.contains(eventId) && AlphaWell.count == 1) || (Gamma.contains(eventId) && Gamma.count == 1) {
            value = 1
        } else {
            value = 0
        }
        encoderForEventIdCache[eventId] = value
        return value
    }
    
}
