//
//  Processor.swift
//  Modane
//
//  Created by Andrey Isaev on 29/10/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import Cocoa

protocol ProcessorDelegate: class {
    
    func startProcessingFile(_ name: String?)
    func endProcessingFile(_ name: String?)
    
}

class Processor {
    
    fileprivate var file: UnsafeMutablePointer<FILE>!
    fileprivate var currentCycle: CUnsignedLongLong = 0
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var currentFileName: String?
    fileprivate var neutronsMultiplicityTotal = [Int: Int]()
    
    fileprivate var stoped = false
    
    fileprivate var files: [String] {
        return DataLoader.singleton.files
    }
    
    fileprivate weak var delegate: ProcessorDelegate?
    fileprivate var minNeutronEnergy: Int = 0
    fileprivate var maxNeutronEnergy: Int = 0
    
    var filesFinishedCount: Int = 0
    
    init(minNeutronEnergy: Int, maxNeutronEnergy: Int, delegate: ProcessorDelegate) {
        self.minNeutronEnergy = minNeutronEnergy
        self.maxNeutronEnergy = maxNeutronEnergy
        self.delegate = delegate
    }
    
    func stop() {
        stoped = true
    }
    
    func processDataWith(completion: @escaping (()->())) {
        stoped = false
        processData()
        DispatchQueue.main.async {
            completion()
        }
    }
    
    // MARK: - Algorithms
    
    fileprivate func forwardSearch(checker: @escaping ((Event, UnsafeMutablePointer<Bool>)->())) {
        while feof(file) != 1 {
            var event = Event()
            fread(&event, Event.size, 1, file)
            
            var stop: Bool = false
            checker(event, &stop)
            if stop {
                return
            }
        }
    }
    
    // MARK: - Search
    
    fileprivate func showNoDataAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Please select some data files to start analysis!"
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    fileprivate func processData() {
        if 0 == files.count {
            showNoDataAlert()
            return
        }
        
        neutronsMultiplicityTotal = [:]
        totalEventNumber = 0
        
        for fp in files {
            let path = fp as NSString
            autoreleasepool {
                file = fopen(path.utf8String, "rb")
                currentFileName = path.lastPathComponent
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.startProcessingFile(self?.currentFileName)
                }

                if let file = file {
                    setvbuf(file, nil, _IONBF, 0)
                    forwardSearch(checker: { [weak self] (event: Event, stop: UnsafeMutablePointer<Bool>) in
                        autoreleasepool {
                            if let file = self?.file, let currentFileName = self?.currentFileName, let stoped = self?.stoped {
                                if ferror(file) != 0 {
                                    print("\nError while reading file \(currentFileName)\n")
                                    exit(-1)
                                }
                                if stoped {
                                    stop.initialize(to: true)
                                }
                            }
                            self?.mainCycleEventCheck(event)
                        }
                    })
                } else {
                    exit(-1)
                }

                totalEventNumber += Processor.calculateTotalEventNumberForFile(file)
                fclose(file)

                filesFinishedCount += 1
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.endProcessingFile(self?.currentFileName)
                }
            }
        }
        
        var strings = ["Neutrons multiplicity:"]
        let maxValue = neutronsMultiplicityTotal.keys.sorted().last ?? 0
        for i in 1...maxValue {
            strings.append("\(i) --- \(neutronsMultiplicityTotal[i] ?? 0)")
        }
        let n2 = Double(neutronsMultiplicityTotal[2] ?? 0)
        let n3 = Double(neutronsMultiplicityTotal[3] ?? 0)
        let n4 = max(Double(neutronsMultiplicityTotal[4] ?? 0), 1)
        
        strings.append("")
        let detected = ["2:3": n2/max(n3,1), "3:4": n3/max(n4,1), "2:4": n2/max(n4,1)]
        for (key, value) in detected {
            strings.append("\(key) --- \(value)")
        }
        
        let data = Calibration.singleton.data
        let ij = [(2, 3), (3, 4), (2, 4)]
        var dict = [String: Efficiency]()
        for item in data {
            for t in ij {
                let i = t.0
                let j = t.1
                let new = item.probability(i: i, j: j)
                let key = "\(i):\(j)"
                let ratio = detected[key]!
                if let old = dict[key]?.probability(i: i, j: j) {
                    if fabs(new - ratio) < fabs(old - ratio) {
                        dict[key] = item
                    }
                } else {
                    dict[key] = item
                }
            }
        }
        
        strings.append("")
        strings.append("Efficiency:")
        for t in ij {
            let i = t.0
            let j = t.1
            let key = "\(i):\(j)"
            if let e = dict[key]?.value {
                strings.append("\(key) --- \(e * 100)%")
            }
        }
        
        FileManager.writeResults(strings.joined(separator: "\n"))
        
        print("\nDone!\nTotal time took: \((NSApplication.shared.delegate as! AppDelegate).timeTook())")
    }

    class func calculateTotalEventNumberForFile(_ file: UnsafeMutablePointer<FILE>!) -> CUnsignedLongLong {
        fseek(file, 0, SEEK_END)
        var lastNumber = fpos_t()
        fgetpos(file, &lastNumber)
        return CUnsignedLongLong(lastNumber)/CUnsignedLongLong(Event.size)
    }
    
    fileprivate var eventsGroup = [Event]()
    
    fileprivate func countFrom(event: Event) -> UInt16 {
        return (event.param1 >> 8) + 1
    }

    fileprivate func mainCycleEventCheck(_ event: Event) {
        let amplitude = event.param1 & 0x00FF
        let detector = event.param2 & 0x00FF
        let count = countFrom(event: event)
        let time = event.param2 >> 8
        if amplitude >= minNeutronEnergy && amplitude <= maxNeutronEnergy {
            print("count: \(count) time: \(time) amplitude:\(amplitude) detector:\(detector)")
            if let last = eventsGroup.last {
                let lastCount = countFrom(event: last)
                if lastCount >= count {
                    let key = Int(lastCount)
                    var summ = neutronsMultiplicityTotal[key] ?? 0
                    summ += 1 // One event for all neutrons in one act of fission
                    neutronsMultiplicityTotal[key] = summ
                } else {
                    eventsGroup.append(event)
                    return
                }
            }
            
            eventsGroup.removeAll()
            eventsGroup.append(event)
        }
    }
    
}

