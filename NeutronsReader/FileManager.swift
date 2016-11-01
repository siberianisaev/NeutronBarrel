//
//  FileManager.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

class FileManager: NSObject {
    
    private class func desktopFolder() -> NSString? {
        return NSSearchPathForDirectoriesInDomains(.DesktopDirectory, .UserDomainMask, true).first
    }
    
    private class func createIfNeedsDirectoryAtPath(path: String?) {
        if let path = path {
            let fm = NSFileManager.defaultManager()
            if false == fm.fileExistsAtPath(path) {
                do {
                    try fm.createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    private class func desktopFilePathWithName(fileName: String, timeStamp: String?) -> String? {
        var path = self.desktopFolder()
        if let timeStamp = timeStamp {
            path = path?.stringByAppendingPathComponent(timeStamp)
            createIfNeedsDirectoryAtPath(path as? String)
        }
        return path?.stringByAppendingPathComponent(fileName)
    }
    
    class func resultsFilePath(timeStamp: String?) -> String? {
        return self.desktopFilePathWithName("results.csv", timeStamp: timeStamp)
    }
    
    class func multiplicityFilePath(timeStamp: String?) -> String? {
        return self.desktopFilePathWithName("multiplicity.txt", timeStamp: timeStamp)
    }
    
    class func calibrationFilePath(timeStamp: String?) -> String? {
        return self.desktopFilePathWithName("calibration.txt", timeStamp: timeStamp)
    }
    
}
