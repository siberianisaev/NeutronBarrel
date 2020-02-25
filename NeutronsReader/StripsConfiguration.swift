//
//  StripsConfiguration.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 10/11/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

enum StripsSide: Int {
    case front, back
}

class StripsConfiguration {
    
    fileprivate var config = [StripsSide: [[Int]]]()
    fileprivate var detector: StripDetector
    
    init(detector: StripDetector) {
        self.detector = detector
    }
    
    var loaded: Bool {
        return config.count > 0
    }
    
    fileprivate var stripsCache = [StripsSide: [Int: [CUnsignedShort: Int]]]()
    
    fileprivate func cacheStrip(strip: Int, side: StripsSide, encoder: Int, strip0_15: CUnsignedShort) {
        var sideDict = stripsCache[side] ?? [:]
        var encoderDict = sideDict[encoder] ?? [:]
        encoderDict[strip0_15] = strip
        sideDict[encoder] = encoderDict
        stripsCache[side] = sideDict
    }

    func strip1_N_For(side: StripsSide, encoder: Int, strip0_15: CUnsignedShort) -> Int {
        if let cached = stripsCache[side]?[encoder]?[strip0_15] {
            return cached
        }
        
        let encoderIndex = encoder - 1
        if let encoders = config[side], encoderIndex < encoders.count {
            let strips = encoders[encoderIndex]
            if strip0_15 < strips.count {
                let value = strips[Int(strip0_15)]
                cacheStrip(strip: value, side: side, encoder: encoder, strip0_15: strip0_15)
                return value
            }
        }
        
        // Default Config
        if detector == .focal {
            // By defaults used 48x48 config
            /**
             Strips in focal plane detector are connected alternately to 3 16-channel encoders:
             | 1.0 | 2.0 | 3.0 | 1.1 | 2.1 | 3.1 | ... | encoder.strip_0_15 |
             This method used for convert strip from format "encoder + strip 0-15" to format "strip 1-48".
             */
            let value = (Int(strip0_15) * 3) + (encoder - 1) + 1
            cacheStrip(strip: value, side: side, encoder: encoder, strip0_15: strip0_15)
            return value
        } else {
            return Int(strip0_15) + 1
        }
    }
    
    class func load(_ completion: @escaping ((Bool, [String]?) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                var hasConfigs: Bool = false
                let urls = panel.urls.filter { (u: URL) -> Bool in
                    return u.path.lowercased().hasSuffix(".ini")
                }
                let s = StripDetectorManager.singleton
                s.reset()
                for url in urls {
                    let path = url.path
                    for detector in [.focal, .side] as [StripDetector] {
                        let sc = StripsConfiguration(detector: detector)
                        sc.open(path, detector: detector)
                        if sc.loaded {
                            s.setStripConfiguration(sc, detector: detector)
                            hasConfigs = true
                        }
                    }
                }
                let paths = urls.map({ (u: URL) -> String in
                    return u.path
                })
                completion(hasConfigs, paths)
            }
        }
    }
    
    fileprivate func open(_ path: String?, detector: StripDetector) {
        if let path = path {
            do {
                let content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                var frontData = [[Int]]()
                var backData = [[Int]]()
                var fillFront = false
                var fillBack = false
                for line in content.components(separatedBy: CharacterSet.newlines) {
                    if detector == .side {
                        if line.contains("[Well inside detector strips configuration]") {
                            fillFront = true
                            fillBack = false
                            continue
                        }
                        if line.contains("[Well outside detector strips configuration]") {
                            fillFront = false
                            fillBack = true
                            continue
                        }
                        if line.contains("[") {
                            fillFront = false
                            fillBack = false
                            continue
                        }
                    } else {
                        if line.contains("[Front 128x128 detector strips configuration]") {
                            fillFront = true
                            fillBack = false
                            continue
                        }
                        if line.contains("[Back 128x128 detector strips configuration]") {
                            fillFront = false
                            fillBack = true
                            continue
                        }
                        if line.contains("[") {
                            fillFront = false
                            fillBack = false
                            continue
                        }
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
                        if fillFront {
                            frontData.append(values)
                        } else if fillBack {
                            backData.append(values)
                        }
                    }
                }
                
                config[.front] = frontData
                config[.back] = backData
                print("Loaded strips configuration: \(config)")
            } catch {
                print("Error load strips configuration from file at path \(path): \(error)")
            }
        }
    }
    
}
