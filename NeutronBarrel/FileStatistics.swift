//
//  FolderStatistics.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 04/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class FileStatistics {
    
    var name: String?
    
    var fileCreatedOn: Date?
    var calculationsStart: Date?
    var calculationsEnd: Date?
    var correlationsTotal: CUnsignedLongLong = 0
    
    var medianEnergy: Double {
        return FileStatistics.median(energies) ?? 0.0
    }
    fileprivate var energies = [Double]()
    
    var medianCurrent: Double {
        return FileStatistics.median(currents) ?? 0.0
    }
    fileprivate var currents = [Double]()
    
    var medianBackground: Double {
        return FileStatistics.median(backgrounds) ?? 0.0
    }
    fileprivate var backgrounds = [Double]()
    
    var integral: Float = 0
    
    fileprivate var firstEventTime: UInt64?
    fileprivate var lastEventTime: UInt64?
    
    func handleEvent(_ event: Event) {
        let time = event.time
        if firstEventTime == nil {
            firstEventTime = time
        }
        lastEventTime = time
    }
    
    var secondsFromStart: Double {
        let delta = (lastEventTime ?? 0).toMks() - (firstEventTime ?? 0).toMks()
        return delta / 1e6
    }
    
    static func median(_ values: [Double]) -> Double? {
        let count = Double(values.count)
        if count == 0 { return nil }
        let sorted = values.sorted { $0 < $1 }
        
        if count.truncatingRemainder(dividingBy: 2) == 0 {
            // Even number of items - return the mean of two middle values
            let leftIndex = Int(count / 2 - 1)
            let leftValue = sorted[leftIndex]
            let rightValue = sorted[leftIndex + 1]
            return (leftValue + rightValue) / 2
        } else {
            // Odd number of items - take the middle item.
            return sorted[Int(count / 2)]
        }
    }
    
    fileprivate func creationDate(for file: String) -> Date {
        var fileStat = stat()
        stat((file as NSString).utf8String, &fileStat)
//        print("File statistics: \(fileStat)")
        return Date(timeIntervalSince1970: fileStat.st_birthtimespec.toTimeInterval())
    }
    
    func startFile(_ path: String) {
        calculationsStart = Date()
        fileCreatedOn = creationDate(for: path)
    }
    
    func endFile(_ path: String, correlationsPerFile: CUnsignedLongLong) {
        calculationsEnd = Date()
        correlationsTotal += correlationsPerFile
    }
    
    func handleEnergy(_ value: Float) {
        energies.append(Double(value))
    }
    
    func handleCurrent(_ value: Float) {
        currents.append(Double(value))
    }
    
    func handleBackground(_ value: Float) {
        backgrounds.append(Double(value))
    }
    
    func handleIntergal(_ value: Float) {
        if value > integral { // must increase in time
            integral = value
        }
    }
    
    init(fileName: String?) {
        self.name = fileName
    }
    
    class func fileNameFromPath(_ path: String) -> String? {
        return path.components(separatedBy: "/").last
    }
    
}
