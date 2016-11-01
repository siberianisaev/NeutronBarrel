//
//  Calibration.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

class Calibration: NSObject {
    
    private var kName: String {
        return "kName"
    }
    
    private var kCoefficientA: String {
        return "kCoefficientA"
    }
    
    private var kCoefficientB: String {
        return "kCoefficientB"
    }
    
    private var data = [String: [String: Float]]()
    var stringValue: String?
    
    class func openCalibration(onFinish: ((Calibration?) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.beginWithCompletionHandler { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                onFinish(self.calibrationWithUrl(panel.URL))
            }
        }
    }
    
    class func defaultCalibration() -> Calibration {
        let path = NSBundle.mainBundle().pathForResource("default", ofType: "clb")
        let URL = NSURL(fileURLWithPath: path!)
        return self.calibrationWithUrl(URL)
    }
    
    private class func calibrationWithUrl(URL: NSURL?) -> Calibration {
        let calibration = Calibration()
        calibration.load(URL)
        return calibration
    }
    
    private func load(URL: NSURL?) {
        self.data.removeAll(keepCapacity: true)
    
        if let path = URL?.path {
            do {
                var content = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
                content = content.stringByReplacingOccurrencesOfString("\r", withString: "")
                var string = "\nCALIBRATION\n----------\nLoad calibration from file: \((path as NSString).lastPathComponent)\n(B)\t\t(A)\t\t(Name)\n"
                
                let setSpaces = NSCharacterSet.whitespaceCharacterSet()
                let setLines = NSCharacterSet.newlineCharacterSet()
                for line in content.componentsSeparatedByCharactersInSet(setLines) {
                    let components = line.componentsSeparatedByCharactersInSet(setSpaces).filter() { $0 != "" }
                    if 3 == components.count {
                        let b = (components[0] as NSString).floatValue
                        let a = (components[1] as NSString).floatValue
                        let name = components[2] as String
                        string += NSString(format: "%.6f\t%.6f\t%@\n", b, a, name) as String
                        self.data[name] = [kCoefficientB: b, kCoefficientA: a];
                    }
                }
                
                stringValue = string
            } catch {
                print("Error load calibration from file at path \(path): \(error)")
            }
        }
    }
    
    func energyForAmplitude(channel: Double, eventName: String) -> Double {
        if let value = self.data[eventName] {
            let nB = value[self.kCoefficientB]
            let nA = value[self.kCoefficientA]
            if nil != nB && nil != nA {
                return Double(nB!) + Double(nA!) * channel
            }
        }
        
        print("No calibration for name \(eventName)")
        return channel
    }
    
}
