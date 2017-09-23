//
//  DataLoader.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 30.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

class DataLoader: NSObject {
    
    class func load(_ onFinish: @escaping (([String], DataProtocol) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                var selected = [String]()
                let fm = Foundation.FileManager.default
                for URL in panel.urls {
                    let path = URL.path
                    var isDirectory : ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory:&isDirectory) && isDirectory.boolValue {
                        selected += recursiveGetFilesFromDirectory(path)
                    } else {
                        selected.append(path)
                    }
                }
                
                //TODO: show alert for data with many different protocols
                let protocolURLString = selected.filter() { $0.hasSuffix(".PRO") }.first
                let protocolObject = DataProtocol.load(protocolURLString)
                
                selected = selected.filter() { false == $0.hasSuffix(".PRO") && false == $0.hasSuffix(".DS_Store") }
                selected = selected.sorted(by: { (s1: String, s2: String) -> Bool in
                    return s1 < s2
                })
                onFinish(selected, protocolObject)
            }
        }
    }
    
    /**
     Recursive bypasses folders in 'directoryPath' and then return all files in these folders.
    */
    class func recursiveGetFilesFromDirectory(_ directoryPath: String) -> [String] {
        var results = [String]()
        
        let fm = Foundation.FileManager.default
        do {
            let fileNames = try fm.contentsOfDirectory(atPath: directoryPath)
            for fileName in fileNames {
                let path = (directoryPath as NSString).appendingPathComponent(fileName)
                
                var isDirectory: ObjCBool = false
                if fm.fileExists(atPath: path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        results += recursiveGetFilesFromDirectory(path)
                    } else {
                        results.append(path)
                    }
                }
            }
        } catch {
            print(error)
        }
        
        return results
    }
    
}
