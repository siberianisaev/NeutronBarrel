//
//  Logger.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

enum LoggerDestination {
    case results, gammaAll, gammaGeOnly
}

class Logger {
    
    fileprivate var resultsCSVWriter: CSVWriter
    fileprivate var gammaAllCSVWriter: CSVWriter
    fileprivate var gammaGeOnlyCSVWriter: CSVWriter
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
        gammaAllCSVWriter = CSVWriter(path: FileManager.filePath("gamma_all", timeStamp: stamp, folderName: name))
        gammaGeOnlyCSVWriter = CSVWriter(path: FileManager.filePath("gamma_Ge_only", timeStamp: stamp, folderName: name))
        statisticsCSVWriter = CSVWriter(path: FileManager.statisticsFilePath(stamp, folderName: name))
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        dateFormatter = f
    }
    
    fileprivate func writerFor(destination: LoggerDestination) -> CSVWriter {
        switch destination {
        case .results:
            return resultsCSVWriter
        case .gammaAll:
            return gammaAllCSVWriter
        case .gammaGeOnly:
            return gammaGeOnlyCSVWriter
        }
    }
    
    func writeLineOfFields(_ fields: [AnyObject]?, destination: LoggerDestination) {
        writerFor(destination: destination).writeLineOfFields(fields)
    }
    
    func writeField(_ field: AnyObject?, destination: LoggerDestination) {
        writerFor(destination: destination).writeField(field)
    }
    
    func finishLine(_ destination: LoggerDestination) {
        writerFor(destination: destination).finishLine()
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
    
    func log(multiplicity: NeutronsMultiplicity) {
        logString(multiplicity.stringValue(), path: FileManager.multiplicityFilePath(timeStamp, folderName: folderName))
    }

    func logCalibration(_ string: String) {
        logString(string, path: FileManager.calibrationFilePath(timeStamp, folderName: folderName))
    }
    
    func logStatistics(_ folders: [String: FolderStatistics]) {
        let headers = ["Folder", "First File", "Last File", "First File Created On", "Last File Created On", "~ Folder Last Modified", "Median Energy", "Median Current", "Total Integral", "Calculation Time", "Last Cycle Time (s)"]
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
            let energy = String(folder.medianEnergy)
            let current = String(folder.medianCurrent)
            let integral = String(folder.integral)
            let calculationTime = abs(folder.calculationsStart?.timeIntervalSince(folder.calculationsEnd ?? Date()) ?? 0).stringFromSeconds()
            let secondsFromStart = folder.secondsFromStart
            let lastModified = stringFrom(folder.firstFileCreatedOn?.addingTimeInterval(secondsFromStart))
            let values = [name, firstFile, lastFile, firstCreatedOn, lastCreatedOn, lastModified, energy, current, integral, calculationTime, secondsFromStart] as [AnyObject]
            statisticsCSVWriter.writeLineOfFields(values)
        }
        statisticsCSVWriter.finishLine()
    }
    
    func logSettings() {
        if let path = FileManager.settingsFilePath(timeStamp, folderName: folderName) {
            let url = URL(fileURLWithPath: path)
            Settings.writeToFile(url)
        }
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
