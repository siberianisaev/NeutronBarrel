//
//  Logger.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

class Logger: NSObject {
    fileprivate var resultsCSVWriter: CSVWriter!
    fileprivate var timeStamp: String?
    
    override init() {
        super.init()
        timeStamp = TimeStamp.createTimeStamp()
        resultsCSVWriter = CSVWriter(path: FileManager.resultsFilePath(timeStamp))
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
        self.logString(string, path: FileManager.multiplicityFilePath(timeStamp))
    }

    func logCalibration(_ string: String) {
        self.logString(string, path: FileManager.calibrationFilePath(timeStamp))
    }
    
}
