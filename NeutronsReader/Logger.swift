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
    fileprivate var folderName: String
    fileprivate var timeStamp: String
    fileprivate var dateFormatter: DateFormatter?
    
    init(folder: String) {
        let stamp = String.timeStamp()
        let name = folder.count > 0 ? folder : stamp
        folderName = name
        timeStamp = stamp
        resultsCSVWriter = CSVWriter(path: FileManager.resultsFilePath(stamp, folderName: name))
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        dateFormatter = f
    }
    
    func writeLineOfFields(_ fields: [AnyObject]?) {
        resultsCSVWriter.writeLineOfFields(fields)
    }
    
    func writeField(_ field: AnyObject?) {
        resultsCSVWriter.writeField(field)
    }
    
    func finishLine() {
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
    
    func logStatisticsEvent(_ eventDescription: String, date: Date? = nil) {
        guard let path = FileManager.statisticsFilePath(timeStamp, folderName: folderName) else {
            return
        }
        var previous: String?
        if Foundation.FileManager.default.fileExists(atPath: path) {
            do {
                previous = try String.init(contentsOfFile: path, encoding: String.Encoding.utf8)
            } catch {
                print(error)
            }
        }
        
        var current = ""
        if let previous = previous {
            current += "\(previous)\n"
        }
        current += "\(eventDescription)"
        if let date = date, let sDate = dateFormatter?.string(from: date) {
            current += "   \(sDate)"
        }
        logString(current, path: path)
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
