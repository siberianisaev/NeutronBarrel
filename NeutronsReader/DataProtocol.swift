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
    
    fileprivate var dict = [String: Int]()
    fileprivate var alphaWelMinEventId: Int = 0
    fileprivate var keyAFr: String = "AFr"
    fileprivate var keyAdFr: String = "AdFr"
    fileprivate var keyABack: String = "ABack"
    fileprivate var keyABk: String = "ABk"
    fileprivate var keyAdBk: String = "AdBk"
    fileprivate var keyAWel: String = "AWel"
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
        
        p.setMinAlphaWelId()
        return p
    }
    
    fileprivate func setMinAlphaWelId() {
        var alphaWelIds = [Int]()
        for (key, value) in dict {
            if key.hasPrefix(keyAWel) {
                alphaWelIds.append(value)
            }
        }
        alphaWelMinEventId = alphaWelIds.min() ?? 0
    }
    
    /**
     Not all events have time data.
     */
    func isValidEventIdForTimeCheck(_ eventId: Int) -> Bool {
        return eventId <= alphaWelMinEventId || eventId == TOF || isGammaEvent(eventId) || eventId == Neutrons || eventId == AVeto
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
    
    func value(_ key: String) -> Int {
        return dict[key] ?? -1
    }
    
    func isAlphaFronEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyAFr) || isEvent(eventId, ofType: keyAdFr)
    }
    
    func isAlphaBackEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyABack) || isEvent(eventId, ofType: keyABk) || isEvent(eventId, ofType: keyAdBk)
    }
    
    func isAlphaWelEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyAWel)
    }
    
    func isGammaEvent(_ eventId: Int) -> Bool {
        return isEvent(eventId, ofType: keyGam)
    }
    
    fileprivate func isEvent(_ eventId: Int, ofType type: String) -> Bool {
        return keyFor(value: eventId)?.hasPrefix(type) == true
    }
    
    func encoderForEventId(_ eventId: Int) -> CUnsignedShort {
        if AWel == eventId {
            return 1
        }
        if let key = keyFor(value: eventId), let rangeDigits = key.rangeOfCharacter(from: .decimalDigits), let substring = String(key[rangeDigits.lowerBound...]).components(separatedBy: CharacterSet.init(charactersIn: "., ")).first, let encoder = Int(substring) {
            return CUnsignedShort(encoder)
        } else {
            return 0
        }
    }
    
    fileprivate var AWel: Int {
        return value(keyAWel)
    }
    
    var AVeto: Int {
        return value("AVeto")
    }
    
    var TOF: Int {
        return value("TOF")
    }
    
    var Neutrons: Int {
        return value("Neutrons")
    }
    
    var CycleTime: Int {
        return value("THi")
    }
    
    var BeamEnergy: Int {
        return value("EnergyHi")
    }
    
    var BeamCurrent: Int {
        return value("BeamTokHi")
    }
    
    var BeamBackground: Int {
        return value("BeamFonHi")
    }
    
    var BeamIntegral: Int {
        return value("IntegralHi")
    }
    
}
