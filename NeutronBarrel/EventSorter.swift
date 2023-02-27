//
//  EventSorter.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 18.11.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class EventSorter {
    
    class var singleton : EventSorter {
        struct Static {
            static let sharedInstance : EventSorter = EventSorter()
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
//        var firstCycleEventFound = false
        if let sortedDataFolder = FileManager.pathForDesktopFolder("SORTED_DATA") {
            for fp in protocols {
                // TODO: copy protocols
            }
            
            for fp in files {
                let pathRead = fp as NSString
                autoreleasepool {
                    fileRead = fopen(pathRead.utf8String, "rb")
                    
                    let components = pathRead.components(separatedBy: "/")
                    _ = components.dropLast()
                    let folder = components.last!
                    let writeFolder = sortedDataFolder.appendingPathComponent(folder)
                    FileManager.createIfNeedsDirectoryAtPath(writeFolder)
                    
                    let writeFilePath = (writeFolder as NSString).appendingPathComponent("sorted_\(pathRead.lastPathComponent)") as NSString
                    fileWrite = fopen(writeFilePath.utf8String, "wb")
                    
                    var intercycleEvents = [Event]()
                    func storeIntercycleEvents() {
                        let sorted = sort(intercycleEvents)
                        for event in sorted {
                            writeToFile(event)
                        }
                        intercycleEvents.removeAll()
                    }
                    
                    if let fileRead = fileRead {
                        setvbuf(fileRead, nil, _IONBF, 0)
                        while feof(fileRead) != 1 {
                            var event = Event()
                            fread(&event, Event.size, 1, fileRead)
                            intercycleEvents.append(event)
                        }
                        // TODO: now no any cycles in files, optimise sorting logic for large files
                        storeIntercycleEvents()
                    } else {
                        exit(-1)
                    }
                    fclose(fileRead)
                    fclose(fileWrite)
                    DispatchQueue.main.async { [weak self] in
                        if let files = self?.files {
                            progressHandler(100 * Double(files.firstIndex(of: fp)! + 1)/Double(files.count))
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                NSWorkspace.shared.openFile(sortedDataFolder as String)
            }
        }
    }
    
    fileprivate func sort(_ events: [Event]) -> [Event] {
        //TODO: пока сортируем просто по event.param1
        return events.sorted { $0.time.bigEndian < $1.time.bigEndian }
//        var time: CUnsignedShort = 0
//        for event in events {
//            if dataProtocol.isValidEventIdForTimeCheck(Int(event.eventId)) {
//                time = event.param1
//            } // Eсли событие не может быть проверено по времени, то присвоить ему время предыдущего событий
//        }
    }
    
    fileprivate func writeToFile(_ event: Event) {
        var e = event
        fwrite(&e, Event.size, 1, fileWrite)
    }
    
    fileprivate var currentPosition: Int {
        var p = fpos_t()
        fgetpos(fileRead, &p)
        let position = Int(p)
        return position
    }
    
    fileprivate var dataProtocol: DataProtocol! {
        return DataLoader.singleton.dataProtocol
    }

    fileprivate var files: [String] {
        return DataLoader.singleton.files
    }
    
    fileprivate var protocols: [String] {
        return DataLoader.singleton.protocols
    }
    
}
