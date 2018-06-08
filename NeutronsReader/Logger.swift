//
//  Logger.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

class Logger {
    
    fileprivate var resultsCSVWriter: CSVWriter
    fileprivate var statisticsCSVWriter: CSVWriter
    fileprivate var folderName: String
    fileprivate var timeStamp: String
    fileprivate var dateFormatter: DateFormatter?
    
    init(folder: String) {
        let stamp = String.timeStamp()
        let name = folder.count > 0 ? folder : stamp
        folderName = name
        timeStamp = stamp
        resultsCSVWriter = CSVWriter(path: FileManager.resultsFilePath(stamp, folderName: name))
        statisticsCSVWriter = CSVWriter(path: FileManager.statisticsFilePath(stamp, folderName: name))
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        dateFormatter = f
    }
    
    func writeResultsLineOfFields(_ fields: [AnyObject]?) {
        resultsCSVWriter.writeLineOfFields(fields)
    }
    
    func writeResultsField(_ field: AnyObject?) {
        resultsCSVWriter.writeField(field)
    }
    
    func finishResultsLine() {
        resultsCSVWriter.finishLine()
    }
    
    fileprivate func logString(_ string: String, path: String?) {
        if let path = path {
            do {
                try string.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                print("Error writing to file \(path): \(error)")
            }
        }
    }
    
    func logMultiplicity(_ info: [Int: Int]) {
        var string = "Multiplicity\tCount\n"
        let sortedKeys = Array(info.keys).sorted(by: { (i1: Int, i2: Int) -> Bool in
            return i1 < i2
        })
        for key in sortedKeys {
            string += "\(key)\t\(info[key]!)\n"
        }
        logString(string, path: FileManager.multiplicityFilePath(timeStamp, folderName: folderName))
    }

    func logCalibration(_ string: String) {
        logString(string, path: FileManager.calibrationFilePath(timeStamp, folderName: folderName))
    }
    
    func logStatistics(_ folders: [String: FolderStatistics]) {
        let headers = ["Folder", "First File", "Last File", "First File Created On", "Last File Created On", "~ Folder Last Modified", "Mean Energy", "Integral", "Calculation Time"]
        statisticsCSVWriter.writeLineOfFields(headers as [AnyObject])
        statisticsCSVWriter.finishLine()
        
        let statistics = Array(folders.values).sorted { (fs1: FolderStatistics, fs2: FolderStatistics) -> Bool in
            return (fs1.name ?? "") < (fs2.name ?? "")
        }
        func stringFrom(_ date: Date?) -> String {
            return dateFormatter?.string(from: date ?? Date()) ?? ""
        }
        for folder in statistics {
            let name = folder.name ?? ""
            let firstCreatedOn = stringFrom(folder.firstFileCreatedOn)
            let lastCreatedOn = stringFrom(folder.lastFileCreatedOn)
            let firstFile = folder.files.first ?? ""
            let lastFile = folder.files.last ?? ""
            let energy = String(folder.meanEnergy)
            let integral = String(folder.integral)
            let calculationTime = abs(folder.calculationsStart?.timeIntervalSince(folder.calculationsEnd ?? Date()) ?? 0).stringFromSeconds()
            let lastModified = stringFrom(folder.firstFileCreatedOn?.addingTimeInterval(folder.secondsFromStart))
            let values = [name, firstFile, lastFile, firstCreatedOn, lastCreatedOn, lastModified, energy, integral, calculationTime] as [AnyObject]
            statisticsCSVWriter.writeLineOfFields(values)
        }
        statisticsCSVWriter.finishLine()
    }
    
    func logInput(_ image: NSImage?, onEnd: Bool) {
        if let path = FileManager.inputFilePath(timeStamp, folderName: folderName, onEnd: onEnd) {
            let url = URL.init(fileURLWithPath: path)
            do {
                try image?.imagePNGRepresentation()?.write(to: url)
            } catch {
                print("Error writing to file \(path): \(error)")
            }
        }
    }
    
}
