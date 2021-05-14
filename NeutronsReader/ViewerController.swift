//
//  ViewerController.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 28/05/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

class ViewerController: NSWindowController {
    
    enum Column: Int, CaseCountable {
        case number = 0, name, ID, time, strip, alpha, fission, markers
        
        static let count = Column.countCases()
        
        var name: String {
            switch self {
            case .number:
                return "Number"
            case .name:
                return "Name"
            case .ID:
                return "ID"
            case .time:
                return "Time"
            case .strip:
                return "Strip"
            case .alpha:
                return "Alpha"
            case .fission:
                return "Fission"
            case .markers:
                return "Markers"
            }
        }
        
        var rowId: String {
            return "Viewer\(name)Cell"
        }
    }
    
    fileprivate var totalEventNumber: CUnsignedLongLong = 0
    fileprivate var index: Int = 0
    fileprivate var file: UnsafeMutablePointer<FILE>?
    fileprivate var eventCount: Int = 0
    
    @IBInspectable dynamic var sEventNumberToScroll: String = ""
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var labelFile: NSTextField!
    @IBOutlet weak var buttonPrevious: NSButton!
    @IBOutlet weak var buttonNext: NSButton!
    @IBOutlet weak var buttonScroll: NSButton!
    
    fileprivate var dataProtocol: DataProtocol! {
        return DataLoader.singleton.dataProtocol
    }
    
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
    
    @IBAction func scroll(_ sender: Any) {
        if let row = Int(sEventNumberToScroll), row >= 0,  row < numberOfRows(in: tableView) {
            tableView.scrollRowToVisible(row)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
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
            if let column = Column(rawValue: index), let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: column.rowId), owner: self) as? NSTableCellView {
                var string = ""
                if let event = getEventForRow(row) {
                    let id = Int(event.eventId)
                    switch column {
                    case .number:
                        string = "\(row)"
                    case .name:
                        string = dataProtocol?.keyFor(value: id) ?? ""
                    case .ID:
                        string = "\(event.eventId)"
                    case .time:
                        if dataProtocol?.isValidEventIdForTimeCheck(id) == true {
                            string = "\(event.param1)"
                        }
                    case .strip:
                        let isAlpha = dataProtocol?.isAlpha(eventId: id) ?? false
                        var encoder: CUnsignedShort?
                        var strip: UInt16?
                        if isAlpha {
                            encoder = dataProtocol?.encoderForEventId(Int(id))
                            strip = event.param2 >> 12
                        } else if dataProtocol.isNeutronsNewEvent(id) == true {
                            encoder = dataProtocol?.encoderForEventId(Int(id))
                            strip = event.param3 & Mask.neutronsNew.rawValue
                        }
                        if let encoder = encoder {
                            string += "enc\(encoder)_"
                        }
                        if let strip = strip {
                            string += "ch\(strip)"
                        }
                    case .alpha:
                        string = "\(event.getChannelFor(type: .alpha))"
                    case .fission:
                        let isAlpha = dataProtocol?.isAlpha(eventId: id) ?? false
                        if isAlpha {
                            string = "\(event.getChannelFor(type: .fission))"
                        }
                    case .markers:
                        string = String(event.getMarker(), radix: 2)
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
