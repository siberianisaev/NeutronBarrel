//
//  DataLoader.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 30.12.14.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class DataLoader {
    
    var files = [String]()
    var protocols = [String]()
    var dataProtocol = DataProtocol()
    
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
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
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
                selected = selected.filter({ (s: String) in
                    return !s.contains(".DS_Store")
                })
                selected = selected.sorted(by: { (s1: String, s2: String) -> Bool in
                    let t1 = s1.fileNameAndExtension()
                    let t2 = s2.fileNameAndExtension()
                    let n1 = t1.0 ?? ""
                    let n2 = t2.0 ?? ""
                    if n1 == n2 {
                        let e1 = Int(t1.1 ?? "") ?? 0
                        let e2 = Int(t2.1 ?? "") ?? 0
                        return e1 < e2
                    } else {
                        return n1 < n2
                    }
                })
                dl.files = selected
                dl.dataProtocol = DataProtocol()
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
