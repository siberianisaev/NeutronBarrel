//
//  ViewerController.swift
//  NeutronBarrel
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
    
    @IBInspectable dynamic var sFileToScroll: String = ""
    @IBInspectable dynamic var sEventNumberToScroll: String = ""
    @IBInspectable dynamic var sHighlightedStrip: String = "" {
        didSet {
            tableView.reloadData()
        }
    }
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var labelFile: NSTextField!
    @IBOutlet weak var buttonPrevious: NSButton!
    @IBOutlet weak var buttonNext: NSButton!
    @IBOutlet weak var buttonScroll: NSButton!
    
    fileprivate var dataProtocol: DataProtocol! {
        return DataLoader.singleton.dataProtocol
    }
    
    fileprivate var stripsConfiguration = StripsConfiguration()
    
    override func windowDidLoad() {
        super.windowDidLoad()

        loadFile()
    }
    
    func loadFile(_ index: Int = 0) {
        var name: String = ""
        let files = DataLoader.singleton.files
        
        if index >= 0 && index < files.count {
            self.index = index
            let path = files[index] as NSString
            
            closeFile()
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
    
    fileprivate func loadFile(_ name: String) {
        let files = DataLoader.singleton.files
        for file in files {
            let path = file as NSString
            if name.caseInsensitiveCompare(path.lastPathComponent) == .orderedSame {
                let index = files.firstIndex(of: file)!
                loadFile(index)
                break
            }
        }
    }
    
    @IBAction func scroll(_ sender: Any) {
        if !sFileToScroll.isEmpty {
            loadFile(sFileToScroll)
        }
        if let number = Int(sEventNumberToScroll) {
            let row = number - 1
            if row >= 0,  row < numberOfRows(in: tableView) {
                tableView.scrollRowToVisible(row)
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
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
            event.bigEndian()
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
    
    func colorFor(name: String) -> NSColor {
        // text color
        if name.contains("AFr") || name.contains("FFr") {
            return NSColor.blue
        } else if name.contains("ABk") || name.contains("FBk") {
            return NSColor.systemGreen
        } else if name.contains("THi") {
            return NSColor.orange
        }
        return NSColor.black
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let tableColumn = tableColumn, let index = tableView.tableColumns.firstIndex(of: tableColumn) {
            if let column = Column(rawValue: index), let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: column.rowId), owner: self) as? NSTableCellView {
                var string = ""
                var textColor = NSColor.black
                var highlight = false
                if let event = getEventForRow(row) {
                    let id = Int(event.eventId)
                    let isAlpha = dataProtocol?.isAlpha(id) ?? false
                    switch column {
                    case .number:
                        string = "\(row + 1)"
                    case .name:
                        string = dataProtocol?.keyFor(value: id) ?? ""
                        textColor = colorFor(name: string)
                        // channel number
                        var strip: UInt16?
                        // TODO: strip
//                        if isAlpha {
//                            strip = event.param2 >> 12
//                        } else if dataProtocol.isNeutronsNewEvent(id) {
//                            strip = event.param3 & Mask.neutronsNew.rawValue
//                        } else if dataProtocol.isGammaEvent(id) {
//                            strip = (event.param3 << 1) >> 12
//                        }
                        if let strip = strip {
                            string += ".\(strip+1)"
                        }
                    case .ID:
                        string = "\(event.eventId)"
                    case .time:
                        string = String(format: "%.3f", event.time.toMks())
                    case .strip:
                        string = "enc\(id)"
                        let strip1_N = stripsConfiguration.strip1_N_For(channel: CUnsignedShort(id))
                        if strip1_N != -1 {
                            string += "_str\(strip1_N)"
                        }
                    case .alpha:
                        // TODO: !!!
                        string = "\(event.energy)"
//                        if dataProtocol.isNeutronsNewEvent(id) {
//                            let CT = NeutronCT.init(event: event)
//                            string = "R: \(CT.R), W: \(CT.W)"
//                        } else {
//                            string = "\(event.getChannelFor(type: .alpha))"
//                        }
                    case .fission:
                        string = ""
                    case .markers:
                        string = ""
//                        if dataProtocol.isGammaEvent(id) {
//                            string = String(event.param3 >> 15)
//                        } else {
//                            string = String(event.getMarker(), radix: 2)
//                        }
                    }
                }
                cell.textField?.stringValue = string
                cell.textField?.textColor = textColor
                cell.textField?.layer?.borderColor = NSColor.red.cgColor
                cell.textField?.layer?.borderWidth = highlight ? 2.0 : 0.0
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
