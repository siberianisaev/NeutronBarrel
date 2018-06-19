//
//  DataProtocol.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class DataProtocol {
    
    fileprivate var dict = [String: Int]() {
        didSet {
            AVeto = dict["AVeto"]
            TOF = dict["TOF"]
            Neutrons = dict["Neutrons"]
            CycleTime = dict["THi"]
            BeamEnergy = dict["EnergyHi"]
            BeamCurrent = dict["BeamTokHi"]
            BeamBackground = dict["BeamFonHi"]
            BeamIntegral = dict["IntegralHi"]
            AlphaWell = getValues(ofTypes: ["AWel"])
            alphaWellMaxEventId = AlphaWell.max() ?? 0
            AlphaMotherFront = getValues(ofTypes: ["AFr"])
            AlphaDaughterFront = getValues(ofTypes: ["AdFr"])
            AlphaFront = AlphaMotherFront.union(AlphaDaughterFront)
            AlphaMotherBack = getValues(ofTypes: ["ABack", "ABk"])
            AlphaDaughterBack = getValues(ofTypes: ["AdBk"])
            AlphaBack = AlphaMotherBack.union(AlphaDaughterBack)
            Gamma = getValues(ofTypes: ["Gam"])
        }
    }
    
    fileprivate func getValues(ofTypes types: [String]) -> Set<Int> {
        var result = [Int]()
        for type in types {
            let values = dict.filter({ (key: String, value: Int) -> Bool in
                return self.keyFor(value: value)?.hasPrefix(type) == true
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
    fileprivate var Neutrons: Int?
    fileprivate var CycleTime: Int?
    fileprivate var AlphaWell = Set<Int>()
    fileprivate var alphaWellMaxEventId: Int = 0
    fileprivate var AlphaMotherFront = Set<Int>()
    fileprivate var AlphaDaughterFront = Set<Int>()
    fileprivate var AlphaFront = Set<Int>()
    fileprivate var AlphaMotherBack = Set<Int>()
    fileprivate var AlphaDaughterBack = Set<Int>()
    fileprivate var AlphaBack = Set<Int>()
    fileprivate var Gamma = Set<Int>()
    
    class func load(_ path: String?) -> DataProtocol {
        let p = DataProtocol()
        
        if let path = path {
            do {
                var content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                content = content.replacingOccurrences(of: " ", with: "")
                
                let words = Event.words
                for line in content.components(separatedBy: CharacterSet.newlines) {
                    if false == line.contains(":") {
                        continue
                    }
                    
                    let set = CharacterSet(charactersIn: ":,")
                    let components = line.components(separatedBy: set).filter() { $0 != "" }
                    let count = components.count
                    if words == count {
                        let key = components[count-1]
                        let value = Int(components[0])
                        p.dict[key] = value
                    }
                }
            } catch {
                print("Error load protocol from file at path \(path): \(error)")
            }
        }
        
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
        
        let value = eventId <= alphaWellMaxEventId || isTOFEvent(eventId) || isGammaEvent(eventId) || isNeutronsEvent(eventId) || isVETOEvent(eventId)
        isValidEventIdForTimeCheckCache[eventId] = value
        return value
    }
    
    fileprivate func keyFor(value: Int) -> String? {
        for (k, v) in dict {
            if v == value {
                return k
            }
        }
        return nil
    }
    
    func position(_ eventId: Int) -> String {
        if AlphaMotherFront.contains(eventId) {
            return "Fron"
        } else if AlphaMotherBack.contains(eventId) {
            return "Back"
        } else if AlphaDaughterFront.contains(eventId) {
            return "dFr"
        } else if AlphaDaughterBack.contains(eventId) {
            return "dBk"
        } else if isVETOEvent(eventId) {
            return "Veto"
        } else if isGammaEvent(eventId) {
            return "Gam"
        } else {
            return "Wel"
        }
    }
    
    func isAlphaFronEvent(_ eventId: Int) -> Bool {
        return AlphaFront.contains(eventId)
    }
    
    func isAlphaBackEvent(_ eventId: Int) -> Bool {
        return AlphaBack.contains(eventId)
    }
    
    func isAlphaWellEvent(_ eventId: Int) -> Bool {
        return AlphaWell.contains(eventId)
    }
    
    func isGammaEvent(_ eventId: Int) -> Bool {
        return Gamma.contains(eventId)
    }
    
    func isVETOEvent(_ eventId: Int) -> Bool {
        return AVeto == eventId
    }
    
    func isTOFEvent(_ eventId: Int) -> Bool {
        return TOF == eventId
    }
    
    func isNeutronsEvent(_ eventId: Int) -> Bool {
        return Neutrons == eventId
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
