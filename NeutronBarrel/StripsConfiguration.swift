//
//  StripsConfiguration.swift
//  NeutronBarrel
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
    
    fileprivate var dataProtocol: DataProtocol! {
        return DataLoader.singleton.dataProtocol
    }
    
    var focalFrontStripToChannel: [Int: CUnsignedShort] = [:]
    var focalBackStripToChannel: [Int: CUnsignedShort] = [:]
    
    var strips: [CUnsignedShort: Int] = [:]
    
    func strip1_N_For(channel: CUnsignedShort) -> Int {
        if let strip = self.strips[channel] {
            return strip
        } else {
            return -1
        }
    }
    
    init() {
        // TODO: well detector and gamma for calibration
        let encodersFromOne = Settings.getBoolSetting(.EncodersFromOne)
        for tuple in [("chan_decode_dssd", 0), ("chan_decode_neutrons", 512)] {
            if let url = Bundle.main.url(forResource: tuple.0, withExtension: "txt") {
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let lines: [String] = text.components(separatedBy: "\r\n").filter {
                        return !$0.isEmpty
                    }
                    for index in 0...lines.count-1 {
                        let shift = encodersFromOne ? 1 : 0
                        let channel = CUnsignedShort(index + tuple.1 + shift)
                        let strip = Int(lines[index])!
                        self.strips[channel] = strip
                        
                        // TODO: create calibrations using channel number
                        if dataProtocol.isAlphaFronEvent(Int(channel)) {
                            self.focalFrontStripToChannel[strip] = channel
                        } else if dataProtocol.isAlphaBackEvent(Int(channel)) {
                            self.focalBackStripToChannel[strip] = channel
                        }
                    }
                } catch {
                    print("Error read file \(url): \(error)")
                }
            }
        }
        print("Strips configuration (channel : strip) \(self.strips)")
    }
    
//    init(detector: StripDetector) {
//        self.detector = detector
//    }
//
    var loaded: Bool {
        return strips.count > 0
    }
//
//    fileprivate var stripsCache = [StripsSide: [Int: [CUnsignedShort: Int]]]()
//
//    fileprivate func cacheStrip(strip: Int, side: StripsSide, encoder: Int, strip0_15: CUnsignedShort) {
//        var sideDict = stripsCache[side] ?? [:]
//        var encoderDict = sideDict[encoder] ?? [:]
//        encoderDict[strip0_15] = strip
//        sideDict[encoder] = encoderDict
//        stripsCache[side] = sideDict
//    }
//
//    func strip1_N_For(side: StripsSide, encoder: Int, strip0_15: CUnsignedShort) -> Int {
//        if let cached = stripsCache[side]?[encoder]?[strip0_15] {
//            return cached
//        }
//
//        let encoderIndex = encoder - 1
//        if let encoders = config[side], encoderIndex < encoders.count {
//            let strips = encoders[encoderIndex]
//            if strip0_15 < strips.count {
//                let value = strips[Int(strip0_15)]
//                cacheStrip(strip: value, side: side, encoder: encoder, strip0_15: strip0_15)
//                return value
//            }
//        }
//
//        // Default Config
//        if detector == .focal {
//            var value: Int?
//            switch FocalDetector.type {
//            case .large:
//                /**
//                 Strips are connected in pairs to 16-channel encoders (8 in total):
//
//                 for encoder in 0...7 {
//                     print("Encoder: \(encoder)")
//                     var values = [Int]()
//                     for strip in 0...15 {
//                         let value = (encoder / 2) * 32 + (encoder % 2) + strip * 2
//                         values.append(value)
//                     }
//                     print("Strips:\n" + values.map{ String($0) }.joined(separator: " ") + "\n")
//                 }
//
//                 Encoder: 0
//                 Strips:
//                 0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30
//
//                 Encoder: 1
//                 Strips:
//                 1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31
//
//                 Encoder: 2
//                 Strips:
//                 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62
//
//                 Encoder: 3
//                 Strips:
//                 33 35 37 39 41 43 45 47 49 51 53 55 57 59 61 63
//
//                 Encoder: 4
//                 Strips:
//                 64 66 68 70 72 74 76 78 80 82 84 86 88 90 92 94
//
//                 Encoder: 5
//                 Strips:
//                 65 67 69 71 73 75 77 79 81 83 85 87 89 91 93 95
//
//                 Encoder: 6
//                 Strips:
//                 96 98 100 102 104 106 108 110 112 114 116 118 120 122 124 126
//
//                 Encoder: 7
//                 Strips:
//                 97 99 101 103 105 107 109 111 113 115 117 119 121 123 125 127
//                 */
//                value = (encoder / 2) * 32 + (encoder % 2) + Int(strip0_15) * 2
//            case .small:
//                /**
//                 Strips are connected alternately to 3 16-channel encoders:
//                 | 1.0 | 2.0 | 3.0 | 1.1 | 2.1 | 3.1 | ... | encoder.strip_0_15 |
//                 This method used for convert strip from format "encoder + strip 0-15" to format "strip 1-48".
//                 */
//                value = (Int(strip0_15) * 3) + (encoder - 1) + 1
//            }
//            if let value = value {
//                cacheStrip(strip: value, side: side, encoder: encoder, strip0_15: strip0_15)
//                return value
//            }
//        }
//        return Int(strip0_15) + 1
//    }
//
    class func load(_ completion: @escaping ((Bool, [String]?) -> ())) {
//        let panel = NSOpenPanel()
//        panel.canChooseDirectories = false
//        panel.canChooseFiles = true
//        panel.allowsMultipleSelection = true
//        panel.begin { (result) -> Void in
//            if result == NSApplication.ModalResponse.OK {
//                handle(urls: panel.urls, completion: completion)
//            }
//        }
    }

//    class func handle(urls: [URL], completion: @escaping ((Bool, [String]?) -> ())) {
//        var hasConfigs: Bool = false
//        var paths = [String]()
//        let extensions = [.ini, .cfg] as Set<FileExtension>
//        let items = urls.filter { (u: URL) -> Bool in
//            if let ext = FileExtension(url: u, length: 3) {
//                return extensions.contains(ext)
//            } else {
//                return false
//            }
//        }
//        if items.count > 0 {
//            let s = StripDetectorManager.singleton
//            s.reset()
//            for url in items {
//                let path = url.path
//                var detectors: [StripDetector]
//                if FileExtension(url: url, length: 3) == .cfg { // 2 CFG files used since Jan 2017
//                    detectors = [(path as NSString).lastPathComponent == "128X128.CFG" ? .focal : .side]
//                } else { // New INI file used since 2019
//                    detectors = [.focal, .side, .neutron]
//                }
//                for detector in detectors {
//                    let sc = StripsConfiguration(detector: detector)
//                    sc.open(path, detector: detector)
//                    if sc.loaded {
//                        s.setStripConfiguration(sc, detector: detector)
//                        hasConfigs = true
//                    }
//                }
//            }
//            paths = items.map({ (u: URL) -> String in
//                return u.path
//            })
//        }
//        completion(hasConfigs, paths)
//    }
//
//    fileprivate func open(_ path: String?, detector: StripDetector) {
//        if let path = path {
//            do {
//                let content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
//                var frontData = [[Int]]()
//                var backData = [[Int]]()
//                var fillFront = false
//                var fillBack = false
//                for line in content.components(separatedBy: CharacterSet.newlines) {
//                    if detector == .neutron {
//                        if "[Neutrons]".contains(line) {
//                            fillFront = true
//                            fillBack = false
//                            continue
//                        }
//                        if line.contains("[") {
//                            fillFront = false
//                            fillBack = false
//                            continue
//                        }
//                    } else if detector == .side {
//                        if ["[Well inside detector strips configuration]", "[Front Strips Configuration]"].contains(line) {
//                            fillFront = true
//                            fillBack = false
//                            continue
//                        }
//                        if ["[Well outside detector strips configuration]", "[Back Strips Configuration]"].contains(line) {
//                            fillFront = false
//                            fillBack = true
//                            continue
//                        }
//                        if line.contains("[") {
//                            fillFront = false
//                            fillBack = false
//                            continue
//                        }
//                    } else {
//                        if ["[Front 128x128 detector strips configuration]", "[Front Strips Configuration]"].contains(line) {
//                            fillFront = true
//                            fillBack = false
//                            continue
//                        }
//                        if ["[Back 128x128 detector strips configuration]", "[Back Strips Configuration]"].contains(line) {
//                            fillFront = false
//                            fillBack = true
//                            continue
//                        }
//                        if line.contains("[") {
//                            fillFront = false
//                            fillBack = false
//                            continue
//                        }
//                    }
//
//                    let set = CharacterSet.whitespaces
//                    let components = line.components(separatedBy: set).filter() { $0 != "" && $0 != " " }
//                    var values = [Int]()
//                    for component in components {
//                        if let value = Int(component) {
//                            values.append(value)
//                        }
//                    }
//                    if values.count > 0 {
//                        if fillFront {
//                            frontData.append(values)
//                        } else if fillBack {
//                            backData.append(values)
//                        }
//                    }
//                }
//
//                config[.front] = frontData
//                config[.back] = backData
//                let sDetector = "\(detector)".uppercased()
//                print("Loaded \(sDetector) detector strips configuration: \(config)")
//            } catch {
//                print("Error load strips configuration from file at path \(path): \(error)")
//            }
//        }
//    }
    
}
