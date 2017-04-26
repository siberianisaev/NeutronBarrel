//
//  EventID.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

class Protocol: NSObject {
    
    fileprivate var dict = [String: Int]()
    
    class func load(_ path: String?) -> Protocol {
        let p = Protocol()
        
        if let path = path {
            do {
                var content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                content = content.replacingOccurrences(of: " ", with: "")
                
                for line in content.components(separatedBy: CharacterSet.newlines) {
                    if false == line.contains(":") {
                        continue
                    }
                    
                    let set = CharacterSet(charactersIn: ":,")
                    let components = line.components(separatedBy: set).filter() { $0 != "" }
                    if 4 == components.count {
                        let key = components[3]
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
    
    fileprivate func value(_ key: String) -> Int {
        return dict[key] ?? -1
    }
    
    func AFron(_ i: Int) -> Int {
        let i = value("AFron\(i)")
        return i != -1 ? i : value("AFr\(i)")
    }
    
    func ABack(_ i: Int) -> Int {
        let i = value("ABack\(i)")
        return i != -1 ? i : value("ABk\(i)")
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
    
    var FON: Int {
        return value("Fon")
    }
    
    var RecoilSpecial: Int {
        return value("Recoil")
    }
    
}
