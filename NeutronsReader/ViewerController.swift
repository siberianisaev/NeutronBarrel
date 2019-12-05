//
//  ViewerController.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 28/05/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

class ViewerController: NSWindowController {

    @IBOutlet weak var tableView: NSTableView!
    
    fileprivate var rowIdentifiers = ["ViewerNumberCell", "ViewerEventIDCell", "ViewerParam1Cell", "ViewerParam2Cell", "ViewerParam3Cell"]
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var index: Int = 0
    fileprivate var file: UnsafeMutablePointer<FILE>?
    fileprivate var eventCount: Int = 0
    
    @IBOutlet weak var buttonPrevious: NSButton!
    @IBOutlet weak var labelFile: NSTextField!
    @IBOutlet weak var buttonNext: NSButton!
    
    override func windowDidLoad() {
        super.windowDidLoad()

        loadFile()
    }
    
    func loadFile(_ index: Int = 0) {
        var name: String = ""
        let files = DataLoader.singleton.files
        
        closeFile()
        
        if index >= 0 && index < files.count {
            self.index = index
            let path = files[index] as NSString
            file = fopen(path.utf8String, "rb")
            if let f = file {
                eventCount = Int(Processor.calculateTotalEventNumberForFile(f))
                name = path.lastPathComponent
            }
        } else {
            self.index = 0
        }
        
        labelFile.stringValue = name
        buttonPrevious.isHidden = index <= 0
        buttonNext.isHidden = index >= files.count-1
        tableView.reloadData()
    }
    
    @IBAction func previous(_ sender: Any) {
        index -= 1
        loadFile(index)
    }
    
    @IBAction func next(_ sender: Any) {
        index += 1
        loadFile(index)
    }
    
    fileprivate func closeFile() {
        if let f = file {
            fclose(f)
            file = nil
        }
    }
    
    fileprivate func getEventForRow(_ row: Int) -> Event? {
        if let file = file {
            let size = Event.size
            fseek(file, row * size, SEEK_SET)
            var event = Event()
            fread(&event, size, 1, file)
            return event
        } else {
            return nil
        }
    }
    
    deinit {
        closeFile()
    }
    
}

extension ViewerController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let tableColumn = tableColumn, let index = tableView.tableColumns.firstIndex(of: tableColumn) {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: rowIdentifiers[index]), owner: self) as? NSTableCellView {
                var string = ""
                if let event = getEventForRow(row) {
                    switch index {
                    case 0:
                        string += "\(row)"
                    case 1:
                        string += "\(event.eventId)"
                    case 2:
                        string += "\(event.param1)"
                    case 3:
                        string += "\(event.param2)"
                    case 4:
                        string += "\(event.param3)"
                    default:
                        break
                    }
                }
                cell.textField?.stringValue = string
                return cell
            }
        }
        return nil
    }
    
}

extension ViewerController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return eventCount
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return ""
    }
    
}
