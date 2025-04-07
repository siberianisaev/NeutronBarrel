//
//  EventSorter.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 18.11.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class EventMerger {
    
    class var singleton : EventMerger {
        struct Static {
            static let sharedInstance : EventMerger = EventMerger()
        }
        return Static.sharedInstance
    }
    
    fileprivate var fileRead: UnsafeMutablePointer<FILE>!
    fileprivate var fileWrite: UnsafeMutablePointer<FILE>!
    
    /*
     Call it from bkg thread.
     */
    func processData(_ progressHandler: @escaping ((Double)->())) {
        DispatchQueue.main.async {
            progressHandler(0.0)
        }
        if let resultsDataFolder = FileManager.pathForDesktopFolder("MERGED_DATA") {
            FileManager.createIfNeedsDirectoryAtPath(resultsDataFolder as String)
            let writeFilePath = (resultsDataFolder as NSString).appendingPathComponent("merged_file") as NSString
            fileWrite = fopen(writeFilePath.utf8String, "wb")
            
            print("\nWill merge data files: \(files)\n")
            for fp in files {
                let pathRead = fp as NSString
                autoreleasepool {
                    if let fileRead = fopen(pathRead.utf8String, "rb") {
                        setvbuf(fileRead, nil, _IONBF, 0)
                        while feof(fileRead) != 1 {
                            var event = Event()
                            fread(&event, Event.size, 1, fileRead)
                            fwrite(&event, Event.size, 1, fileWrite)
                        }
                    } else {
                        exit(-1)
                    }
                    fclose(fileRead)
                    
                    DispatchQueue.main.async { [weak self] in
                        if let files = self?.files {
                            progressHandler(100 * Double(files.firstIndex(of: fp)! + 1)/Double(files.count))
                        }
                    }
                }
            }
            
            fclose(fileWrite)
            DispatchQueue.main.async {
                NSWorkspace.shared.openFile(resultsDataFolder as String)
            }
        }
    }

    fileprivate var files: [String] {
        return DataLoader.singleton.files
    }
    
}
