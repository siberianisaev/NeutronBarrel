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
    
    fileprivate var stripsConfiguration = StripsConfiguration()
    
    fileprivate var data = [CUnsignedShort: CalibrationEquation]()
    var stringValue: String?
    
    class func clean() {
        let c = Calibration.singleton
        c.data.removeAll()
        c.stripsConfiguration = StripsConfiguration()
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
        var string = "\nCALIBRATION\n----------\nLoad calibration\n(B)\t\t(A)\t\t(Name)\n"
        for URL in URLs {
            let path = URL.path
            do {
                var content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                content = content.replacingOccurrences(of: "\r", with: "")
                string += "File: \((path as NSString).lastPathComponent)\n"
                let setSpaces = CharacterSet.whitespaces
                let setLines = CharacterSet.newlines
                let lines = content.components(separatedBy: setLines)
                for line in lines {
                    let config = stripsConfiguration
                    // TODO: support gamma and AWFr / AWBk
                    
                    let components = line.components(separatedBy: setSpaces).filter() { $0 != "" }
                    if 3 == components.count {
                        let a = Double(components[1]) ?? 0
                        let b = Double(components[0]) ?? 0
                        let name = components[2]
                        
                        var channel: CUnsignedShort? = nil
                        let focalFront = "AFr"
                        let focalBack = "ABk"
                        
                        func stripFrom(prefix: String, name: String) -> Int? {
                            return Int(name.replacingOccurrences(of: prefix, with: ""))
                        }
                        
                        var s: Int = -1
                        if name.contains(focalFront) {
                            if let strip = stripFrom(prefix: focalFront, name: name) {
                                channel = config.focalFrontStripToChannel[strip]
                                s = strip
                            }
                        } else if name.contains(focalBack) {
                            if let strip = stripFrom(prefix: focalBack, name: name) {
                                channel = config.focalBackStripToChannel[strip]
                                s = strip
                            }
                        }
                        
                        if let channel = channel {
                            data[channel] = CalibrationEquation(a: a, b: b)
                            string += "\(name) a\(a) b\(b) strip\(s) channel\(channel)\n"
                        }
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
    
    func calibratedValueForAmplitude(_ amplitude: Double, eventId: CUnsignedShort) -> Double {
        if let equation = self.data[eventId] {
            return equation.applyOn(amplitude)
        }
        return amplitude
    }
    
}
