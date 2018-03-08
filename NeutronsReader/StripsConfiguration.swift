//
//  StripsConfiguration.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 10/11/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

enum StripsSide: Int {
    case front, back
}

class StripsConfiguration {
    
    fileprivate var config = [StripsSide: [[Int]]]()
    
    var loaded: Bool {
        return config.count > 0
    }
    
    func strip_1_N_For(side: StripsSide, encoder: Int, strip_0_15: CUnsignedShort) -> Int {
        let encoderIndex = encoder - 1
        if let encoders = config[side], encoderIndex < encoders.count {
            let strips = encoders[encoderIndex]
            if strip_0_15 < strips.count {
                return strips[Int(strip_0_15)]
            }
        }
        // By defaults used 48x48 config
        /**
         Strips in focal plane detector are connected alternately to 3 16-channel encoders:
         | 1.0 | 2.0 | 3.0 | 1.1 | 2.1 | 3.1 | ... | encoder.strip_0_15 |
         This method used for convert strip from format "encoder + strip 0-15" to format "strip 1-48".
         */
        return (Int(strip_0_15) * 3) + (encoder - 1) + 1
    }
    
    class func openConfiguration(_ onFinish: @escaping ((StripsConfiguration?) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                let urls = panel.urls.filter() { $0.path.hasSuffix(".CFG") }
                onFinish(self.load(urls.first?.path))
            }
        }
    }
    
    fileprivate class func load(_ path: String?) -> StripsConfiguration {
        let c = StripsConfiguration()
        c.config.removeAll()
        
        if let path = path {
            do {
                let content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                var frontData = [[Int]]()
                var backData = [[Int]]()
                var fillFront = true
                for line in content.components(separatedBy: CharacterSet.newlines) {
                    if line.contains("Front") {
                        fillFront = true
                        continue
                    }
                    if line.contains("Back") {
                        fillFront = false
                        continue
                    }
                    
                    let set = CharacterSet.whitespaces
                    let components = line.components(separatedBy: set).filter() { $0 != "" && $0 != " " }
                    var values = [Int]()
                    for component in components {
                        if let value = Int(component) {
                            values.append(value)
                        }
                    }
                    if values.count > 0 {
                        fillFront ? frontData.append(values) : backData.append(values)
                    }
                }
                
                c.config[.front] = frontData
                c.config[.back] = backData
                print("Loaded strips configuration: \(c.config)")
            } catch {
                print("Error load strips configuration from file at path \(path): \(error)")
            }
        }
        return c
    }
    
}
