//
//  FolderStatistics.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 04/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class FolderStatistics {
    
    var name: String?
    
    var firstFileCreatedOn: Date?
    var lastFileCreatedOn: Date?
    var calculationsStart: Date?
    var calculationsEnd: Date?
    var secondsFromStart: TimeInterval = 0
    var correlationsTotal: CUnsignedLongLong = 0
    
    var medianEnergy: Double {
        return FolderStatistics.median(energies) ?? 0.0
    }
    fileprivate var energies = [Double]()
    
    var medianCurrent: Double {
        return FolderStatistics.median(currents) ?? 0.0
    }
    fileprivate var currents = [Double]()
    
    var integral: Float {
        return Float(integralEvent?.energy ?? 0) 
    }
    fileprivate var integralEvent: Event?
    
    var files = [String]()
    
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
        if let name = path.components(separatedBy: "/").last {
            files.append(name)
            if files.count == 1 {
                calculationsStart = Date()
                firstFileCreatedOn = creationDate(for: path)
            }
        }
    }
    
    func endFile(_ path: String, secondsFromFirstFileStart: TimeInterval, correlationsPerFile: CUnsignedLongLong) {
        calculationsEnd = Date()
        lastFileCreatedOn = creationDate(for: path)
        secondsFromStart = secondsFromFirstFileStart
        correlationsTotal += correlationsPerFile
    }
    
    func handleEnergy(_ value: Float) {
        energies.append(Double(value))
    }
    
    func handleCurrent(_ value: Float) {
        currents.append(Double(value))
    }
    
    func handleIntergal(_ event: Event) {
        integralEvent = event
    }
    
    init(folderName: String?) {
        self.name = folderName
    }
    
    class func folderNameFromPath(_ path: String) -> String? {
        return path.components(separatedBy: "/").dropLast().last
    }
    
}
