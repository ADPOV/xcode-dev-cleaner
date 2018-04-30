//
//  MainViewController.swift
//  XcodeCleaner
//
//  Created by Konrad Kołakowski on 11.02.2018.
//  Copyright © 2018 One Minute Games. All rights reserved.
//

import Cocoa

final class MainViewController: NSViewController {
    // MARK: Types
    private enum OutlineViewColumnsIdentifiers: String {
        case itemColumn = "ItemColumn"
        case sizeColumn = "SizeColumn"
        
        var identifier: NSUserInterfaceItemIdentifier {
            return NSUserInterfaceItemIdentifier(self.rawValue)
        }
    }
    
    private enum OutlineViewCellIdentifiers: String {
        case itemCell = "ItemCell"
        case sizeCell = "SizeCell"
        
        var identifier: NSUserInterfaceItemIdentifier {
            return NSUserInterfaceItemIdentifier(self.rawValue)
        }
    }
    
    private enum Segue: String {
        case showCleaningView = "ShowCleaningView"
    }
    
    // MARK: Properties & outlets
    @IBOutlet private weak var donationEncourageLabel: NSTextField!
    
    @IBOutlet private weak var bytesSelectedTextField: NSTextField!
    @IBOutlet private weak var totalBytesTextField: NSTextField!
    
    @IBOutlet private weak var xcodeVersionsTextField: NSTextField!
    
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var cleanButton: NSButton!
    
    @IBOutlet private weak var outlineView: NSOutlineView!
    
    private let xcodeFiles = XcodeFiles()
    private var loaded = false
    
    // MARK: Initialization
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let xcodeFiles = self.xcodeFiles else {
            log.error("MainViewController: Cannot create XcodeFiles instance!")
            
            // display a popup that tells us that this is basically a fatal error, and quit!
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Cannot locate Xcode cache files"
            alert.informativeText = "Check if you have Xcode installed and run at least once"
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            
            NSApp.terminate(nil)
            
            return
        }
        
        xcodeFiles.scanDelegate = self
        
        // check for installed Xcode versions
        self.checkForInstalledXcodes()
        
        // start initial scan
        self.startScan()
    }
    
    // MARK: Navigation
    private func prepareCleaningView(with segue: NSStoryboardSegue) {
        if let cleaningViewController = segue.destinationController as? CleaningViewController {
            cleaningViewController.state = .idle(title: "Initialization...", indeterminate: true, doneButtonEnabled: false)
            
            self.xcodeFiles?.deleteDelegate = cleaningViewController
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier?.rawValue, let segueId = Segue(rawValue: identifier) else {
            log.warning("MainViewController: Unrecognized segue: \(segue)")
            return
        }
        
        switch segueId {
            case .showCleaningView:
                self.prepareCleaningView(with: segue)
        }
    }
    
    // MARK: Helpers
    private func startScan() {
        guard let xcodeFiles = self.xcodeFiles else {
            log.error("MainViewController: Cannot create XcodeFiles instance!")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            xcodeFiles.scanFiles(in: XcodeFiles.Location.all)
        }
    }
    
    private func checkForInstalledXcodes() {
        guard let xcodeFiles = self.xcodeFiles else {
            log.error("MainViewController: Cannot create XcodeFiles instance!")
            return
        }
        
        xcodeFiles.checkForInstalledXcodes { (installedXcodeVersions) in
            var versionsText = String()
            
            var i = 0
            for version in installedXcodeVersions {
                if i == 0 {
                    versionsText = version.description
                } else {
                    versionsText += ", " + version.description
                }
                
                i += 1
            }
            
            self.xcodeVersionsTextField.stringValue = versionsText
        }
    }
    
    private func updateTotalAndSelectedSizes() {
        guard let xcodeFiles = self.xcodeFiles else {
            log.error("MainViewController: Cannot create XcodeFiles instance!")
            return
        }
        
        // total size
        let totalSizeString = ByteCountFormatter.string(fromByteCount: xcodeFiles.totalSize, countStyle: .file)
        self.totalBytesTextField.stringValue = "Total: \(totalSizeString)"
        
        // selected size
        let selectedSizeString = ByteCountFormatter.string(fromByteCount: xcodeFiles.selectedSize, countStyle: .file)
        self.bytesSelectedTextField.stringValue = "Selected: \(selectedSizeString)"
    }
    
    // MARK: Loading
    private func startLoading() {
        self.loaded = false
        
        self.progressIndicator.isHidden = false
        self.progressIndicator.startAnimation(nil)
        
        self.cleanButton.isEnabled = false
    }
    
    private func stopLoading() {
        self.loaded = true
        
        self.progressIndicator.stopAnimation(nil)
        self.progressIndicator.isHidden = true
        
        self.cleanButton.isEnabled = true
        
        self.outlineView.reloadData()
    }
    
    // MARK: Actions
    @IBAction func startCleaning(_ sender: NSButton) {
        log.info("MainViewController: 'startCleaning' not implemented yet!")
    }
}

// MARK: NSOutlineViewDataSource implementation
extension MainViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // no items if not loaded
        if !self.loaded {
            return 0
        }
        
        guard let xcodeFiles = self.xcodeFiles else {
            fatalError("MainViewController: Cannot create XcodeFiles instance!")
        }
        
        // for child items
        if let xcodeFileEntry = item as? XcodeFileEntry {
            return xcodeFileEntry.items.count
        }
        
        // for root items
        return xcodeFiles.locations.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let xcodeFiles = self.xcodeFiles else {
            fatalError("MainViewController: Cannot create XcodeFiles instance!")
        }
        
        // for child items
        if let xcodeFileEntry = item as? XcodeFileEntry {
            return xcodeFileEntry.items[index]
        }
        
        // for root items
        if let location = XcodeFiles.Location(rawValue: index), let xcodeFileEntry = xcodeFiles.locations[location] {
            return xcodeFileEntry
        } else {
            fatalError("MainViewController: Wrong location from index for XcodeFiles!")
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // every item that has child items
        if let xcodeFileEntry = item as? XcodeFileEntry {
            return xcodeFileEntry.items.count > 0
        }
        
        return false
    }
}

// MARK: NSOutlineViewDelegate implementation
extension MainViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: NSTableCellView?
        
        if let xcodeFileEntry = item as? XcodeFileEntry, let column = tableColumn {
            if column.identifier == OutlineViewColumnsIdentifiers.itemColumn.identifier {
                if let itemView = outlineView.makeView(withIdentifier: OutlineViewCellIdentifiers.itemCell.identifier, owner: self) as? XcodeEntryCellView {
                    itemView.setup(with: xcodeFileEntry, delegate: self)
                    
                    view = itemView
                }
            } else if column.identifier == OutlineViewColumnsIdentifiers.sizeColumn.identifier {
                if let sizeView = outlineView.makeView(withIdentifier: OutlineViewCellIdentifiers.sizeCell.identifier, owner: self) as? SizeCellView {
                    sizeView.setup(with: xcodeFileEntry)
                    
                    view = sizeView
                }
            }
        }
        
        return view
    }
}

// MARK: XcodeEntryCellViewDelegate implementation
extension MainViewController: XcodeEntryCellViewDelegate {
    func xcodeEntryCellSelectedChanged(_ cell: XcodeEntryCellView, state: NSControl.StateValue, xcodeEntry: XcodeFileEntry?) {
        if let entry = xcodeEntry {
            if state == .on {
                entry.selectWithChildItems()
            } else if state == .off {
                entry.deselectWithChildItems()
            }
            
            // find parent item and refresh it
            var rootEntry: XcodeFileEntry = entry.parent ?? entry
            while let parentEntry = rootEntry.parent {
                rootEntry = parentEntry
            }
            rootEntry.recalculateSelection()
            
            self.outlineView.reloadItem(rootEntry, reloadChildren: true)
            
            self.updateTotalAndSelectedSizes()
        }
    }
}

// MARK: XcodeFilesScanDelegate implementation
extension MainViewController: XcodeFilesScanDelegate {
    func scanWillBegin(xcodeFiles: XcodeFiles) {
        self.startLoading()
    }
    
    func scanDidFinish(xcodeFiles: XcodeFiles) {
        self.stopLoading()

        self.updateTotalAndSelectedSizes()
    }
}
