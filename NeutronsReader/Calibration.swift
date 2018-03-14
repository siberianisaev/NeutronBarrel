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
    
    fileprivate var kName: String {
        return "kName"
    }
    
    fileprivate var kCoefficientA: String {
        return "kCoefficientA"
    }
    
    fileprivate var kCoefficientB: String {
        return "kCoefficientB"
    }
    
    fileprivate var data = [String: [String: Float]]()
    var stringValue: String?
    
    class func openCalibration(_ onFinish: @escaping ((Calibration?, String?) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                let urls = panel.urls.filter() { $0.path.hasSuffix(".clb") }
                onFinish(self.calibrationWithUrls(urls), urls.first?.path)
            }
        }
    }
    
    fileprivate class func calibrationWithUrls(_ URLs: [Foundation.URL]) -> Calibration? {
        let calibration = Calibration()
        calibration.load(URLs)
        if calibration.data.count > 0 {
            return calibration
        } else {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Wrong calibration file!"
            alert.addButton(withTitle: "Got It")
            alert.alertStyle = .warning
            alert.runModal()
            return nil
        }
    }
    
    fileprivate func load(_ URLs: [Foundation.URL]) {
        self.data.removeAll(keepingCapacity: true)
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
                        let b = Float(components[0]) ?? 0
                        let a = Float(components[1]) ?? 0
                        let name = components[2] as String
                        string += String(format: "%.6f\t%.6f\t%@\n", b, a, name)
                        self.data[name] = [kCoefficientB: b, kCoefficientA: a];
                    }
                }
                stringValue = string
            } catch {
                print("Error load calibration from file at path \(path): \(error)")
            }
        }
    }
    
    func calibratedValueForAmplitude(_ channel: Double, eventName: String) -> Double {
        if let value = self.data[eventName] {
            let nB = value[self.kCoefficientB]
            let nA = value[self.kCoefficientA]
            if nil != nB && nil != nA {
                return Double(nB!) + Double(nA!) * channel
            }
        }
        
        if self.data.count > 0 {
            print("No calibration for name \(eventName)")
        }
        return channel
    }
    
}
