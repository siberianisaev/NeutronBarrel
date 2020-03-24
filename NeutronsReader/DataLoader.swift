//
//  DataLoader.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 30.12.14.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class DataLoader {
    
    var files = [String]()
    var dataProtocol: DataProtocol!
    
    class var singleton : DataLoader {
        struct Static {
            static let sharedInstance : DataLoader = DataLoader()
        }
        return Static.sharedInstance
    }
    
    class func load(_ completion: @escaping ((Bool, [URL]) -> ())) {
        let dl = DataLoader.singleton
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                var selected = [String]()
                let fm = Foundation.FileManager.default
                let urls = panel.urls
                for URL in urls {
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
                // Every data file has numeric extension like ".001"
                let decimalSet = CharacterSet.decimalDigits
                selected = selected.filter({ (s: String) -> Bool in
                    if let ext = (s as NSString).components(separatedBy: ".").last {
                        let set = CharacterSet(charactersIn: ext)
                        return decimalSet.isSuperset(of: set)
                    } else {
                        return false
                    }
                })
                dl.files = selected
                dl.dataProtocol = protocolObject
                completion(selected.count > 0, urls)
            }
        }
    }
    
    /**
     Recursive bypasses folders in 'directoryPath' and then return all files in these folders.
    */
    fileprivate class func recursiveGetFilesFromDirectory(_ directoryPath: String) -> [String] {
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
