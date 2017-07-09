//
//  DataProtocol.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

class DataProtocol: NSObject {
    
    fileprivate var dict = [String: Int]()
    
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
        
        return p
    }
    
    /**
     Не у всех событий в базе, вторые 16 бит слова отводятся под время.
     */
    func isValidEventIdForTimeCheck(_ eventId: Int) -> Bool {
        return (eventId <= AWel(4) || eventId <= AWel(3) || eventId <= AWel(2) || eventId <= AWel(1) || eventId <= AWel || eventId == TOF  || eventId == Gam(1) || eventId == Gam(2) || eventId == Gam || eventId == Neutrons)
    }
    
    func keyFor(value: Int) -> String? {
        for (k, v) in dict {
            if v == value {
                return k
            }
        }
        return nil
    }
    
    func value(_ key: String) -> Int {
        return dict[key] ?? -1
    }
    
    func AFron(_ i: Int) -> Int {
        let v = value("AFron\(i)")
        return v != -1 ? v : value("AFr\(i)")
    }
    
    func ABack(_ i: Int) -> Int {
        let v = value("ABack\(i)")
        return v != -1 ? v : value("ABk\(i)")
    }
    
    func AdFr(_ i: Int) -> Int {
        return value("AdFr\(i)")
    }
    
    func AdBk(_ i: Int) -> Int {
        return value("AdBk\(i)")
    }
    
    var AWel: Int {
        return value("AWel")
    }
    
    var AVeto: Int {
        return value("AVeto")
    }
    
    func AWel(_ i: Int) -> Int {
        return value("AWel\(i)")
    }
    
    var Gam: Int {
        return value("Gam")
    }
    
    func Gam(_ i: Int) -> Int {
        return value("Gam\(i)")
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
    
}
