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
    
    fileprivate var data = [CUnsignedShort: CalibrationEquation]()
    var stringValue: String?
    
    class func clean() {
        let c = Calibration.singleton
        c.data.removeAll()
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
                    // TODO: support gamma and AWFr / AWBk
                    
                    let components = line.components(separatedBy: setSpaces).filter() { $0 != "" }
                    if 3 == components.count {
                        let a = Double(components[1]) ?? 0
                        let b = Double(components[0]) ?? 0
                        let name = components[2]
                        
                        let focalFront = "AFr"
                        let focalBack = "ABk"
                        
                        func preChannelFrom(prefix: String, name: String) -> CUnsignedShort? {
                            if let c = CUnsignedShort(name.replacingOccurrences(of: prefix, with: "")) {
                                return c - 1
                            }
                            return nil
                        }
                        
                        var channel: CUnsignedShort?
                        if name.contains(focalFront) {
                            if let preChannel = preChannelFrom(prefix: focalFront, name: name) {
                                channel = preChannel
                            }
                        } else if name.contains(focalBack) {
                            if let preChannel = preChannelFrom(prefix: focalBack, name: name) {
                                // TODO: 128 is hardcoded this moment
                                channel = preChannel + 128
                            }
                        }
                        
                        if let channel = channel {
                            data[channel] = CalibrationEquation(a: a, b: b)
                            string += "\(name) c\(channel) a\(a) b\(b)\n"
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
