//
//  Calibration.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class Calibration {
    
    func hasData() -> Bool {
        return data.count > 0
    }
    
    class var singleton : Calibration {
        struct Static {
            static let sharedInstance : Calibration = Calibration()
        }
        return Static.sharedInstance
    }
    
    fileprivate var data = [String: CalibrationEquation]()
    var stringValue: String?
    
    class func clean() {
        let c = Calibration.singleton
        c.data.removeAll()
        c.calibrationKeysCache.removeAll()
    }
    
    class func load(_ completion: @escaping ((Bool, [String]?) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                handle(urls: panel.urls, silent: false, completion: completion)
            }
        }
    }
    
    class func handle(urls: [URL], silent: Bool = true, completion: @escaping ((Bool, [String]?) -> ())) {
        let items = urls.filter() { $0.path.lowercased().hasSuffix(".clb") }
        if items.count == 0 && silent {
            completion(false, [])
            return
        }
        
        clean()
        let success = singleton.open(items, showFailAlert: !silent)
        let paths = items.map({ (u: URL) -> String in
            return u.path
        })
        completion(success, paths)
    }
    
    fileprivate func open(_ URLs: [Foundation.URL], showFailAlert: Bool) -> Bool {
        for URL in URLs {
            let path = URL.path
            do {
                var content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                content = content.replacingOccurrences(of: "\r", with: "")
                var string = "\nCALIBRATION\n----------\nLoad calibration from file: \((path as NSString).lastPathComponent)\n(B)\t\t(A)\t\t(Name)\n"
                let setSpaces = CharacterSet.whitespaces
                let setLines = CharacterSet.newlines
                for line in content.components(separatedBy: setLines) {
                    let components = line.components(separatedBy: setSpaces).filter() { $0 != "" }
                    if 3 == components.count {
                        let b = Double(components[0]) ?? 0
                        let a = Double(components[1]) ?? 0
                        var name = (components[2] as String)
                        if !name.localizedCaseInsensitiveContains("Fron") {
                            name = name.replacingOccurrences(of: "Fr", with: "Fron")
                        }
                        if !name.localizedCaseInsensitiveContains("Back") {
                            name = name.replacingOccurrences(of: "Bk", with: "Back")
                        }
                        string += String(format: "%.6f\t%.6f\t%@\n", b, a, name)
                        data[name] = CalibrationEquation(a: a, b: b)
                    }
                }
                stringValue = string
            } catch {
                print("Error load calibration from file at path \(path): \(error)")
            }
        }
        if !hasData() {
            if showFailAlert {
                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = "Wrong calibration file!"
                alert.addButton(withTitle: "Got It")
                alert.alertStyle = .warning
                alert.runModal()
            }
            return false
        } else {
            return true
        }
    }
    
    fileprivate var calibrationKeysCache = [SearchType: [Int: [CUnsignedShort: [CUnsignedShort: String]]]]()
    
    fileprivate func cacheCalibrationKey(_ key: String, type: SearchType, eventId: Int, encoder: CUnsignedShort, strip: CUnsignedShort) {
        var typeDict = calibrationKeysCache[type] ?? [:]
        var eventIdDict = typeDict[eventId] ?? [:]
        var encoderDict = eventIdDict[encoder] ?? [:]
        encoderDict[strip] = key
        eventIdDict[encoder] = encoderDict
        typeDict[eventId] = eventIdDict
        calibrationKeysCache[type] = typeDict
    }
    
    fileprivate func keyFor(type: SearchType, eventId: Int, encoder: CUnsignedShort, strip: CUnsignedShort, dataProtocol: DataProtocol) -> String {
        let position = dataProtocol.position(eventId)
        var name = type.symbol() + position
        if encoder != 0 {
            name += "\(encoder)."
        }
        name += String(strip)
        return name
    }
    
    fileprivate func calibrationKeyFor(type: SearchType, eventId: Int, encoder: CUnsignedShort, strip0_15: CUnsignedShort?, dataProtocol: DataProtocol) -> String {
        let strip = (strip0_15 ?? 0) + 1
        if let cached = calibrationKeysCache[type]?[eventId]?[encoder]?[strip] {
            return cached
        }
        
        var key: String
        if type == .gamma {
            let position = dataProtocol.position(eventId)
            key = "\(position)\(encoder)"
        } else if type == .tof {
            let position = dataProtocol.isAlphaFronEvent(eventId) ? "Fron" : "Back"
            key = String(format: "%@%@%d.%d", type.symbol(), position, encoder, strip)
        } else {
            key = keyFor(type: type, eventId: eventId, encoder: encoder, strip: strip, dataProtocol: dataProtocol)
            if false == data.keys.contains(key), let alternative = type.alternativeCalibrationType() {
                key = keyFor(type: alternative, eventId: eventId, encoder: encoder, strip: strip, dataProtocol: dataProtocol)
            }
        }
        cacheCalibrationKey(key, type: type, eventId: eventId, encoder: encoder, strip: strip)
        return key
    }
    
    func calibratedValueForAmplitude(_ channel: Double, type: SearchType, eventId: Int, encoder: CUnsignedShort, strip0_15: CUnsignedShort?, dataProtocol: DataProtocol) -> Double {
        let key = calibrationKeyFor(type: type, eventId: eventId, encoder: encoder, strip0_15: strip0_15, dataProtocol: dataProtocol)
        if let equation = data[key] {
            return equation.applyOn(channel)
        }
        if hasData() {
            print("No calibration for name \(key)")
        }
        return channel
    }
    
    /**
     New TOF format.
     */
    func calibratedTOFValueForAmplitude(_ channel: Double) -> Double? {
        return data["TOF"]?.applyOn(channel)
    }
    
}
