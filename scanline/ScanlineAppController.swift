//
//  ScanlineAppController.swift
//  scanline
//
//  Created by Scott J. Kleper on 12/2/17.
//

import AppKit
import Foundation
import ImageCaptureCore

class ScanlineAppController: NSObject {
    let configuration: ScanConfiguration
    let logger: Logger
    let scannerBrowser: ScannerBrowser
    var scannerBrowserTimer: Timer?

    var scannerController: ScannerController?
    
    init(arguments: [String]) {
        configuration = ScanConfiguration(arguments: Array(arguments[1 ..< arguments.count]))
//        configuration = ScanConfiguration(arguments: ["-flatbed", "-open", "-verbose"])
//        configuration = ScanConfiguration(arguments: ["-flatbed", "house", "-v"])
//        configuration = ScanConfiguration(arguments: ["-scanner", "Dell Color MFP E525w (31:4D:90)", "-exact", "-v"])
//        configuration = ScanConfiguration(arguments: ["-scanner", "epson", "-v", "-resolution", "600"])
//        configuration = ScanConfiguration(arguments: ["-list", "-v"])
//        configuration = ScanConfiguration(arguments: ["-scanner", "epson", "-v", "scanlinetest"])
        logger = Logger(configuration: configuration)
        scannerBrowser = ScannerBrowser(configuration: configuration, logger: logger)
        
        super.init()
        
        scannerBrowser.delegate = self
    }

    func go() {
        scannerBrowser.browse()
        
        let timerExpiration = Double(configuration.config[ScanlineConfigOptionBrowseSecs] as? String ?? "10") ?? 10.0
        scannerBrowserTimer = Timer.scheduledTimer(withTimeInterval: timerExpiration, repeats: false) { _ in
            self.scannerBrowser.stopBrowsing()
        }
        
        logger.verbose("Waiting up to \(timerExpiration) seconds to find scanners")
    }

    func exit() {
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    func scan(scanner: ICScannerDevice) {
        scannerController = ScannerController(scanner: scanner, configuration: configuration, logger: logger)
        scannerController?.delegate = self
        scannerController?.scan()
    }
}

extension ScanlineAppController: ScannerBrowserDelegate {
    func scannerBrowser(_ scannerBrowser: ScannerBrowser, didFinishBrowsingWithScanner scanner: ICScannerDevice?) {
        let run: () -> Void = { [self] in
        logger.verbose("Found scanner: \(scanner?.name ?? "[nil]")")
        scannerBrowserTimer?.invalidate()
        scannerBrowserTimer = nil

        guard configuration.config[ScanlineConfigOptionList] == nil else {
            exit()
            return
        }

        if configuration.config[ScanlineConfigOptionListPageSizes] != nil {
            guard let scanner = scanner else {
                logger.log("No scanner was found.")
                exit()
                return
            }
            let wantsFlatbed = configuration.config[ScanlineConfigOptionFlatbed] != nil
            let keys = PageSizeLister.supportedCatalogKeysFromScannerSync(
                scanner: scanner,
                wantsFlatbed: wantsFlatbed
            )
            if keys.isEmpty {
                let deviceLabel = scanner.name ?? "selected scanner"
                if wantsFlatbed {
                    logger.log("scanline: `\(deviceLabel)' reported no Image Capture page presets for the flatbed.")
                } else {
                    logger.log("scanline: `\(deviceLabel)' reported no page presets for ADF or flatbed via Image Capture (try `--flatbed --list-page-sizes' for flatbed-only).")
                }
            } else {
                for line in PageSizeCatalog.listingTableLines(catalogKeysInOrder: keys) {
                    logger.log(line)
                }
            }
            exit()
            return
        }

        if configuration.config[ScanlineConfigOptionQuery] != nil {
            guard let scanner = scanner else {
                logger.log("No scanner was found.")
                exit()
                return
            }
            let lines = ScannerCapabilitiesReporter.capabilityLinesFromScannerSync(scanner: scanner)
            if lines.isEmpty {
                let deviceLabel = scanner.name ?? "selected scanner"
                logger.log("scanline: could not query capabilities for `\(deviceLabel)'.")
            } else {
                for line in lines {
                    logger.log(line)
                }
            }
            exit()
            return
        }

        guard let scanner = scanner else {
            logger.log("No scanner was found.")
            exit()
            return
        }

        scan(scanner: scanner)
        }

        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.sync(execute: run)
        }
    }
    
    func scannerBrowser(_ scannerBrowser: ScannerBrowser, didUpdateAvailableScanners availableScanners: [String]) {
        // No-op
    }
}

extension ScanlineAppController: ScannerControllerDelegate {
    func scannerController(_ scannerController: ScannerController, didObtainResolutions resolutions: IndexSet) {
        // No-op
    }

    func scannerControllerDidFail(_ scannerController: ScannerController) {
        if let reason = scannerController.failureReason, !reason.isEmpty {
            logger.log("Failed to scan document: \(reason)")
        } else {
            logger.log("Failed to scan document.")
        }
        exit()
    }
    
    func scannerControllerDidSucceed(_ scannerController: ScannerController) {
        exit()
    }
}

