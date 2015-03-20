//
//  Logger.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

class Logger: NSObject {
    private var resultsCSVWriter: CHCSVWriter!
    private var timeStamp: String?
    
    override init() {
        super.init()
        timeStamp = TimeStamp.createTimeStamp()
        resultsCSVWriter = CHCSVWriter(forWritingToCSVFile: FileManager.resultsFilePath(timeStamp))
    }
    
    func writeLineOfFields(fields: [String]?) {
        if let fields = fields {
            resultsCSVWriter.writeLineOfFields(fields)
        }
    }
    
    func writeField(field: String?) {
        if let field = field {
            resultsCSVWriter.writeField(field)
        }
    }
    
    func finishLine() {
        resultsCSVWriter.finishLine()
    }
    
    private func logString(string: String, path: String?) {
        if let path = path {
            var error: NSError?
            string.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding, error: &error)
            if let error = error {
                println("Error writing to file \(path): \(error)")
            }
        }
    }
    
    func logMultiplicity(info: [Int: Int]) {
        var string = "Multiplicity\tCount\n"
        let sortedKeys = info.keys.array.sorted { $0.0 < $1.0 }
        for key in sortedKeys {
            string += "\(key)\t\(info[key]!)\n"
        }
        self.logString(string, path: FileManager.multiplicityFilePath(timeStamp))
    }

    func logCalibration(string: String) {
        self.logString(string, path: FileManager.calibrationFilePath(timeStamp))
    }
    
}
