//
//  Logger.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

@objc
class Logger: NSObject {
    
    private class func logString(string: String, path: String?) {
        if let path = path {
            var error: NSError?
            string.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding, error: &error)
            if let error = error {
                println("Error writing to file \(path): \(error)")
            }
        }
    }
    
    class func logMultiplicity(info: [Int: Int]) {
        var string = "Neutrons multiplicity\n"
        let sortedKeys = info.keys.array.sorted { $0.0 < $1.0 }
        for key in sortedKeys {
            string += "\(key)-x: \(info[key]!)\n"
        }
        self.logString(string, path: FileManager.multiplicityFilePath())
    }

    class func logCalibration(string: String) {
        self.logString(string, path: FileManager.calibrationFilePath())
    }
    
}
