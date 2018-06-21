//
//  Calibration.swift
//  NeutronsReader
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
        Calibration.singleton.data.removeAll()
    }
    
    class func load(_ completion: @escaping ((Bool, String?) -> ())) {
        let calibration = Calibration.singleton
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                let urls = panel.urls.filter() { $0.path.hasSuffix(".clb") }
                clean()
                let success = calibration.open(urls)
                completion(success, urls.first?.path)
            }
        }
    }
    
    fileprivate func open(_ URLs: [Foundation.URL]) -> Bool {
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
                        let name = components[2] as String
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
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Wrong calibration file!"
            alert.addButton(withTitle: "Got It")
            alert.alertStyle = .warning
            alert.runModal()
            return false
        } else {
            return true
        }
    }
    
    func calibratedValueForAmplitude(_ channel: Double, eventName: String) -> Double {
        if let equation = data[eventName] {
            return equation.applyOn(channel)
        }
        if hasData() {
            print("No calibration for name \(eventName)")
        }
        return channel
    }
    
}
