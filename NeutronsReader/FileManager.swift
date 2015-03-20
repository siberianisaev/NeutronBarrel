//
//  FileManager.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

class FileManager: NSObject {
    
    private class func desktopFolder() -> String? {
        return NSSearchPathForDirectoriesInDomains(.DesktopDirectory, .UserDomainMask, true)[0] as? String
    }
    
    private class func createIfNeedsDirectoryAtPath(path: String?) {
        if let path = path {
            let fm = NSFileManager.defaultManager()
            if false == fm.fileExistsAtPath(path) {
                fm.createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil, error: nil)
            }
        }
    }
    
    private class func desktopFilePathWithName(fileName: String, timeStamp: String?) -> String? {
        var path = self.desktopFolder()
        if let timeStamp = timeStamp {
            path = path?.stringByAppendingPathComponent(timeStamp)
            createIfNeedsDirectoryAtPath(path)
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
