//
//  FileManager.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class FileManager {
    
    fileprivate class func desktopFolder() -> NSString? {
        return NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first as NSString?
    }
    
    fileprivate class func createIfNeedsDirectoryAtPath(_ path: String?) {
        if let path = path {
            let fm = Foundation.FileManager.default
            if false == fm.fileExists(atPath: path) {
                do {
                    try fm.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    fileprivate class func desktopFilePathWithName(_ fileName: String, timeStamp: String?) -> String? {
        var path = self.desktopFolder()
        if let timeStamp = timeStamp {
            path = path?.appendingPathComponent(timeStamp) as NSString?
            createIfNeedsDirectoryAtPath(path as String?)
        }
        return path?.appendingPathComponent(fileName)
    }
    
    class func resultsFilePath(_ timeStamp: String) -> String? {
        return self.desktopFilePathWithName("results_\(timeStamp).csv", timeStamp: timeStamp)
    }
    
    class func inputFilePath(_ timeStamp: String) -> String? {
        return self.desktopFilePathWithName("input_\(timeStamp).png", timeStamp: timeStamp)
    }
    
    class func multiplicityFilePath(_ timeStamp: String) -> String? {
        return self.desktopFilePathWithName("multiplicity_\(timeStamp).txt", timeStamp: timeStamp)
    }
    
    class func calibrationFilePath(_ timeStamp: String) -> String? {
        return self.desktopFilePathWithName("calibration_\(timeStamp).txt", timeStamp: timeStamp)
    }
    
}
