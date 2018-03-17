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
    
    fileprivate class func desktopFilePathWithName(_ fileName: String, folderName: String?) -> String? {
        var path = self.desktopFolder()
        if let folderName = folderName {
            path = path?.appendingPathComponent(folderName) as NSString?
            createIfNeedsDirectoryAtPath(path as String?)
        }
        return path?.appendingPathComponent(fileName)
    }
    
    class func resultsFilePath(_ timeStamp: String, folderName: String) -> String? {
        return self.desktopFilePathWithName("results_\(timeStamp).csv", folderName: folderName)
    }
    
    class func statisticsFilePath(_ timeStamp: String, folderName: String) -> String? {
        return self.desktopFilePathWithName("statistics_\(timeStamp).txt", folderName: folderName)
    }
    
    class func inputFilePath(_ timeStamp: String, folderName: String, onEnd: Bool) -> String? {
        let postfix = onEnd ? "end" : "start"
        return self.desktopFilePathWithName("input_\(timeStamp)_\(postfix).png", folderName: folderName)
    }
    
    class func multiplicityFilePath(_ timeStamp: String, folderName: String) -> String? {
        return self.desktopFilePathWithName("multiplicity_\(timeStamp).txt", folderName: folderName)
    }
    
    class func calibrationFilePath(_ timeStamp: String, folderName: String) -> String? {
        return self.desktopFilePathWithName("calibration_\(timeStamp).txt", folderName: folderName)
    }
    
}
