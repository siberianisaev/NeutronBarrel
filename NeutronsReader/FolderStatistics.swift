//
//  FolderStatistics.swift
//  NeutronsReader
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
    
    var meanEnergy: Float {
        if energyCount == 0 {
            return 0
        } else {
            return Float(energySumm/Double(energyCount))
        }
    }
    fileprivate var energySumm: Double = 0
    fileprivate var energyCount: CUnsignedLong = 0
    
    var integral: Float {
        if let e = integralEvent {
            return Processor.singleton.getFloatValueFrom(event: e)
        } else {
            return 0
        }
    }
    fileprivate var integralEvent: Event?
    
    var files = [String]()
    
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
    
    func endFile(_ path: String) {
        calculationsEnd = Date()
        lastFileCreatedOn = creationDate(for: path)
    }
    
    func handleEnergy(_ value: Float) {
        energySumm += Double(value)
        energyCount += 1
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
