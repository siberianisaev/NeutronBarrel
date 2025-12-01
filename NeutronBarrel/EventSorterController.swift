//
//  EventSorterController.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 18.11.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Cocoa

class EventSorterController: NSWindowController {
    
    @IBOutlet weak var buttonSort: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBInspectable dynamic var sFilterEventIDs: String = ""
    
    @IBAction func sort(_ sender: Any) {
        let filterEventIDs = Set(self.sFilterEventIDs.components(separatedBy: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        })
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            EventSorter.singleton.processData(filterEventIDs, progressHandler: { [weak self] (progress: Double) in
                if let indicator = self?.progressIndicator {
                    let run = progress < 100.0
                    run ? indicator.startAnimation(self) : indicator.stopAnimation(self)
                    indicator.isHidden = !run
                    indicator.doubleValue = progress <= 0 ? Double.ulpOfOne : progress
                }
            })
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    // TODO: calcel operation on close
    
}
