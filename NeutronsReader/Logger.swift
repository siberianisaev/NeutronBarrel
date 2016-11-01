//
//  Logger.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

class Logger: NSObject {
    private var resultsCSVWriter: CSVWriter!
    private var timeStamp: String?
    
    override init() {
        super.init()
        timeStamp = TimeStamp.createTimeStamp()
        resultsCSVWriter = CSVWriter(path: FileManager.resultsFilePath(timeStamp))
    }
    
    func writeLineOfFields(fields: [String]?) {
        resultsCSVWriter.writeLineOfFields(fields)
    }
    
    func writeField(field: String?) {
        resultsCSVWriter.writeField(field)
    }
    
    func finishLine() {
        resultsCSVWriter.finishLine()
    }
    
    private func logString(string: String, path: String?) {
        if let path = path {
            do {
                try string.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
            } catch {
                print("Error writing to file \(path): \(error)")
            }
        }
    }
    
    func logMultiplicity(info: [Int: Int]) {
        var string = "Multiplicity\tCount\n"
        let sortedKeys = Array(info.keys).sort({ (i1: Int, i2: Int) -> Bool in
            return i1 < i2
        })
        for key in sortedKeys {
            string += "\(key)\t\(info[key]!)\n"
        }
        self.logString(string, path: FileManager.multiplicityFilePath(timeStamp))
    }

    func logCalibration(string: String) {
        self.logString(string, path: FileManager.calibrationFilePath(timeStamp))
    }
    
}
