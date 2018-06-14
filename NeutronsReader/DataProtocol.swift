//
//  DataProtocol.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

class DataProtocol {
    
    fileprivate var dict = [String: Int]() {
        didSet {
            AWell = dict[keyAWell]
            AVeto = dict["AVeto"]
            TOF = dict["TOF"]
            Neutrons = dict["Neutrons"]
            CycleTime = dict["THi"]
            BeamEnergy = dict["EnergyHi"]
            BeamCurrent = dict["BeamTokHi"]
            BeamBackground = dict["BeamFonHi"]
            BeamIntegral = dict["IntegralHi"]
        }
    }
    
    fileprivate var AWell: Int?
    var AVeto: Int?
    var TOF: Int?
    var Neutrons: Int?
    var CycleTime: Int?
    var BeamEnergy: Int?
    var BeamCurrent: Int?
    var BeamBackground: Int?
    var BeamIntegral: Int?
    
    fileprivate var alphaWellMaxEventId: Int = 0
    fileprivate var keyAFr: String = "AFr"
    fileprivate var keyAdFr: String = "AdFr"
    fileprivate var keyABack: String = "ABack"
    fileprivate var keyABk: String = "ABk"
    fileprivate var keyAdBk: String = "AdBk"
    fileprivate var keyAWell: String = "AWel"
    fileprivate var keyGam: String = "Gam"
    
    class func load(_ path: String?) -> DataProtocol {
        let p = DataProtocol()
        
        if let path = path {
            do {
                var content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                content = content.replacingOccurrences(of: " ", with: "")
                
                let words = Processor.singleton.eventWords
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
        
        p.setMaxAlphaWellId()
        p.isEventOfTypeCache.removeAll()
        p.encoderForEventIdCache.removeAll()
        return p
    }
    
    fileprivate func setMaxAlphaWellId() {
        var alphaWellIds = [Int]()
        for (key, value) in dict {
            if key.hasPrefix(keyAWell) {
                alphaWellIds.append(value)
            }
        }
        alphaWellMaxEventId = alphaWellIds.max() ?? 0
    }
    
    /**
     Not all events have time data.
     */
    func isValidEventIdForTimeCheck(_ eventId: Int) -> Bool {
        return eventId <= alphaWellMaxEventId || eventId == TOF || isGammaEvent(eventId) || eventId == Neutrons || eventId == AVeto
    }
    
    func keyFor(value: Int) -> String? {
        for (k, v) in dict {
            if v == value {
                return k
            }
        }
        return nil
    }
    
    func position(_ eventId: Int) -> String {
        if isEvent(eventId, ofType: keyAFr) {
            return "Fron"
        } else if isEvent(eventId, ofType: keyABack) || isEvent(eventId, ofType: keyABk) {
            return "Back"
        } else if isEvent(eventId, ofType: keyAdFr) {
            return "dFr"
        } else if isEvent(eventId, ofType: keyAdBk) {
            return "dBk"
        } else if AVeto == eventId {
            return "Veto"
        } else {
            return "Wel"
        }
    }
    
    func isAlphaFronEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyAFr) || isEvent(eventId, ofType: keyAdFr)
    }
    
    func isAlphaBackEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyABack) || isEvent(eventId, ofType: keyABk) || isEvent(eventId, ofType: keyAdBk)
    }
    
    func isAlphaWellEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyAWell)
    }
    
    func isGammaEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyGam)
    }
    
    fileprivate var isEventOfTypeCache = [Int: [String: Bool]]()
    
    fileprivate func cacheIsEventOfType(value: Bool, eventId: Int, type: String) {
        var dict = isEventOfTypeCache[eventId] ?? [:]
        dict[type] = value
        isEventOfTypeCache[eventId] = dict
    }
    
    fileprivate func isEvent(_ eventId: Int, ofType type: String) -> Bool {
        if let cached = isEventOfTypeCache[eventId]?[type] {
            return cached
        }
        
        let b = keyFor(value: eventId)?.hasPrefix(type) == true
        cacheIsEventOfType(value: b, eventId: eventId, type: type)
        return b
    }
    
    fileprivate var encoderForEventIdCache = [Int: CUnsignedShort]()
    
    func encoderForEventId(_ eventId: Int) -> CUnsignedShort {
        if let cached = encoderForEventIdCache[eventId] {
            return cached
        }
        
        var value: CUnsignedShort
        if AWell == eventId {
            value = 1
        } else if let key = keyFor(value: eventId), let rangeDigits = key.rangeOfCharacter(from: .decimalDigits), let substring = String(key[rangeDigits.lowerBound...]).components(separatedBy: CharacterSet.init(charactersIn: "., ")).first, let encoder = Int(substring) {
            value = CUnsignedShort(encoder)
        } else {
            value = 0
        }
        encoderForEventIdCache[eventId] = value
        return value
    }
    
}
