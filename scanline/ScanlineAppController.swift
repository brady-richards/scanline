//
//  ScanlineAppController.swift
//  scanline
//
//  Created by Scott J. Kleper on 12/2/17.
//

import AppKit
import Foundation
import ImageCaptureCore
import Quartz

class ScanlineAppController: NSObject, ScannerBrowserDelegate, ScannerControllerDelegate {
    let configuration: ScanConfiguration
    let logger: Logger
    let scannerBrowser: ScannerBrowser
    var scannerBrowserTimer: Timer?

    var scannerController: ScannerController?
    
    init(arguments: [String]) {
        configuration = ScanConfiguration(arguments: Array(arguments[1 ..< arguments.count]))
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

    // MARK: - ScannerBrowserDelegate
    
    func scannerBrowser(_ scannerBrowser: ScannerBrowser, didFinishBrowsingWithScanner scanner: ICScannerDevice?) {
        logger.verbose("Found scanner: \(scanner?.name ?? "[nil]")")
        scannerBrowserTimer?.invalidate()
        scannerBrowserTimer = nil
        
        guard configuration.config[ScanlineConfigOptionList] == nil else {
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
    
    // MARK: - ScannerControllerDelegate
    
    func scannerControllerDidFail(_ scannerController: ScannerController) {
        logger.log("Failed to scan document.")
        exit()
    }
    
    func scannerControllerDidSucceed(_ scannerController: ScannerController) {
        exit()
    }
}

protocol ScannerControllerDelegate: class {
    func scannerControllerDidFail(_ scannerController: ScannerController)
    func scannerControllerDidSucceed(_ scannerController: ScannerController)
}

class ScannerController: NSObject, ICScannerDeviceDelegate {
    let scanner: ICScannerDevice
    let configuration: ScanConfiguration
    let logger: Logger
    var scannedURLs = [URL]()
    weak var delegate: ScannerControllerDelegate?
    var desiredFunctionalUnitType: ICScannerFunctionalUnitType {
        return (configuration.config[ScanlineConfigOptionFlatbed] == nil) ?
            ICScannerFunctionalUnitType.documentFeeder :
            ICScannerFunctionalUnitType.flatbed
    }
    
    init(scanner: ICScannerDevice, configuration: ScanConfiguration, logger: Logger) {
        self.scanner = scanner
        self.configuration = configuration
        self.logger = logger
        
        super.init()

        self.scanner.delegate = self
    }
    
    func scan() {
        logger.verbose("Opening session with scanner")
        scanner.requestOpenSession()
    }
    
    // MARK: - ICScannerDeviceDelegate

    func device(_ device: ICDevice, didEncounterError error: Error?) {
        logger.verbose("didEncounterError: \(error?.localizedDescription ?? "[no error]")")
        delegate?.scannerControllerDidFail(self)
    }
    
    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        if error != nil {
            logger.verbose("didCloseSessionWithError: \(error!.localizedDescription)")
        } else {
            logger.verbose("didCloseSessionWithError: <no error passed>")
        }
        delegate?.scannerControllerDidFail(self)
    }
    
    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        logger.verbose("didOpenSessionWithError: \(error?.localizedDescription ?? "[no error]")")
        
        guard error == nil else {
            logger.log("Error received while attempting to open a session with the scanner.")
            delegate?.scannerControllerDidFail(self)
            return
        }
    }
    
    func didRemove(_ device: ICDevice) {}
    
    func deviceDidBecomeReady(_ device: ICDevice) {
        logger.verbose("deviceDidBecomeReady")
        selectFunctionalUnit()
    }
    
    func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
            logger.verbose("didSelectFunctionalUnit: \(functionalUnit)")
        if let flatbed = functionalUnit as? ICScannerFunctionalUnitFlatbed {
            logger.verbose( "documentTypes: \(flatbed.supportedDocumentTypes())")
        }
        
        if let feeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            logger.verbose( "documentTypes: \(feeder.supportedDocumentTypes())")
        }
        
        if error != nil {
            logger.verbose( "error: \(error?.localizedDescription ?? "[no description]")")
        }

        // NOTE: Despite the fact that `functionalUnit` is not an optional, it still sometimes comes in as `nil` even when `error` is `nil`
        if functionalUnit != nil && functionalUnit.type == desiredFunctionalUnitType {
            configureScanner()
            logger.log("Starting scan...")
            scanner.requestScan()
        }
    }

    func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
        logger.verbose("didScanTo \(url)")
        
        scannedURLs.append(url)
    }
    
    func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        logger.verbose("didCompleteScanWithError \(error?.localizedDescription ?? "[no error]")")
        
        guard error == nil else {
            logger.log("ERROR: \(error!.localizedDescription)")
            delegate?.scannerControllerDidFail(self)
            return
        }

        if configuration.config[ScanlineConfigOptionBatch] != nil {
            logger.log("Press RETURN to scan next page or S to stop")
            let userInput = String(format: "%c", getchar())
            if !"sS".contains(userInput) {
                logger.verbose("Continuing scan")
                scanner.requestScan()
                return
            }
        }

        let outputProcessor = ScanlineOutputProcessor(urls: scannedURLs, configuration: configuration, logger: logger)
        if outputProcessor.process() {
            delegate?.scannerControllerDidSucceed(self)
        } else {
            delegate?.scannerControllerDidFail(self)
        }
    }
    
    // MARK: Private Methods
    
    fileprivate func selectFunctionalUnit() {
        scanner.requestSelect(desiredFunctionalUnitType)
    }
    
    fileprivate func configureScanner() {
        logger.verbose("Configuring scanner")
        
        let functionalUnit = scanner.selectedFunctionalUnit
        
        if functionalUnit.type == .documentFeeder {
            configureDocumentFeeder()
        } else {
            configureFlatbed()
        }
        
        let desiredResolution = Int(configuration.config[ScanlineConfigOptionResolution] as? String ?? "150") ?? 150
        if let resolutionIndex = functionalUnit.supportedResolutions.integerGreaterThanOrEqualTo(desiredResolution) {
            functionalUnit.resolution = resolutionIndex
        }

        if configuration.config[ScanlineConfigOptionMono] != nil {
            functionalUnit.pixelDataType = .BW
            functionalUnit.bitDepth = .depth1Bit
        } else {
            functionalUnit.pixelDataType = .RGB
            functionalUnit.bitDepth = .depth8Bits
        }

        scanner.transferMode = .fileBased
        scanner.downloadsDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        scanner.documentName = "Scan"
        
        if configuration.config[ScanlineConfigOptionTIFF] != nil {
            scanner.documentUTI = kUTTypeTIFF as String
        } else if configuration.config[ScanlineConfigOptionPNG] != nil {
            scanner.documentUTI = kUTTypePNG as String
        } else {
            scanner.documentUTI = kUTTypeJPEG as String
        }
    }

    fileprivate func configureDocumentFeeder() {
        logger.verbose("Configuring Document Feeder")

        guard let functionalUnit = scanner.selectedFunctionalUnit as? ICScannerFunctionalUnitDocumentFeeder else { return }
        
        functionalUnit.documentType = { () -> ICScannerDocumentType in
            
            if configuration.config[ScanlineConfigOptionLegal] != nil {
                return .typeUSLegal
            }
            if configuration.config[ScanlineConfigOptionA4] != nil {
                return .typeA4
            }
            if configuration.config[ScanlineConfigOptionLedger] != nil {
                return .typeUSLedger
            }
            
            if configuration.config[ScanlineConfigOptionDocumentType] != nil {
                if let docstring = configuration.config[ScanlineConfigOptionDocumentType] as? String {
                    if let doctype = documentTypes[docstring] {
                        return doctype.documentType
                    } else {
                        logger.log("ERROR: Invalid documenttype \(docstring)")
                        exit(-1)
                    }
                } else {
                    logger.log("ERROR: Invalid documenttype")
                    exit(-1)
                }
            }
            
            return .typeUSLetter
        }()
        
        functionalUnit.duplexScanningEnabled = (configuration.config[ScanlineConfigOptionDuplex] != nil)
    }
    
    fileprivate func configureFlatbed() {
        logger.verbose("Configuring Flatbed")
        
        guard let functionalUnit = scanner.selectedFunctionalUnit as? ICScannerFunctionalUnitFlatbed else { return }

        functionalUnit.measurementUnit = .inches
        let physicalSize = functionalUnit.physicalSize
        functionalUnit.scanArea = NSMakeRect(0, 0, physicalSize.width, physicalSize.height)
    }
}

struct documentTypeSpecification {
    var name: String
    let documentType: ICScannerDocumentType
    var notes: String?
    var dimensionsImperial: String?
    var dimensionsMetric: String?
    var ratio: String?
}

let documentTypes = [
    "default": documentTypeSpecification(name: "Default", documentType: .typeDefault, notes: "This is the platten size. Not valid for scanners without a platten."),
    "a4": documentTypeSpecification(name: "A4", documentType: .typeA4, dimensionsMetric: "210.00 mm x 297.00 mm"),
    "b5": documentTypeSpecification(name: "B5/JIS B5", documentType: .typeB5, dimensionsMetric: "182.00 mm x 257.00 mm"),
    "usletter": documentTypeSpecification(name: "US Letter", documentType: .typeUSLetter, dimensionsImperial: "8.5\" x 11.0\"", dimensionsMetric: "215.90 mm x 279.40 mm"),
    "uslegal": documentTypeSpecification(name: "US Legal", documentType: .typeUSLegal, dimensionsImperial: "8.5\" x 14.0\"", dimensionsMetric: "215.90 mm x 355.60 mm"),
    "a5": documentTypeSpecification(name: "A5", documentType: .typeA5, dimensionsMetric: "148.00 mm x 210.00 mm"),
    "isob4": documentTypeSpecification(name: "B4/ISO B4", documentType: .typeISOB4, dimensionsMetric: "250.00 mm x 353.00 mm"),
    "isob6": documentTypeSpecification(name: "B6/ISO B6", documentType: .typeISOB6, dimensionsMetric: "125.00 mm x 176.00 mm"),
    "usledger": documentTypeSpecification(name: "US Ledger", documentType: .typeUSLedger, dimensionsImperial: "11\" x 17.0\"", dimensionsMetric: "279.40 mm x 431.80 mm"),
    "usexecutive": documentTypeSpecification(name: "US Executive", documentType: .typeUSExecutive, dimensionsImperial: "7.25\" x 10.5\"", dimensionsMetric: "184.15 mm x 266.70 mm"),
    "a3": documentTypeSpecification(name: "A3", documentType: .typeA3, dimensionsMetric: "297.00 mm x 420.00 mm"),
    "isob3": documentTypeSpecification(name: "B3/ISO B3", documentType: .typeISOB3, dimensionsMetric: "353.00 mm x 500.00 mm"),
    "a6": documentTypeSpecification(name: "A6", documentType: .typeA6, dimensionsMetric: "105.00 mm x 148.00 mm"),
    "c4": documentTypeSpecification(name: "C4", documentType: .typeC4, dimensionsMetric: "229.00 mm x 324.00 mm"),
    "c5": documentTypeSpecification(name: "C5", documentType: .typeC5, dimensionsMetric: "162.00 mm x 229.00 mm"),
    "c6": documentTypeSpecification(name: "C6", documentType: .typeC6, dimensionsMetric: "114.00 mm x 162.00 mm"),
    "4a0": documentTypeSpecification(name: "4A0", documentType: .type4A0, dimensionsMetric: "1682.00 mm x 2378.00 mm"),
    "2a0": documentTypeSpecification(name: "2A0", documentType: .type2A0, dimensionsMetric: "1189.00 mm x 1682.00 mm"),
    "a0": documentTypeSpecification(name: "A0", documentType: .typeA0, dimensionsMetric: "841.00 mm x 1189.00 mm"),
    "a1": documentTypeSpecification(name: "A1", documentType: .typeA1, dimensionsMetric: "594.00 mm x 841.00 mm"),
    "a2": documentTypeSpecification(name: "A2", documentType: .typeA2, dimensionsMetric: "420.00 mm x 594.00 mm"),
    "a7": documentTypeSpecification(name: "A7", documentType: .typeA7, dimensionsMetric: "74.00 mm x 105.00 mm"),
    "a8": documentTypeSpecification(name: "A8", documentType: .typeA8, dimensionsMetric: "52.00 mm x 74.00 mm"),
    "a9": documentTypeSpecification(name: "A9", documentType: .typeA9, dimensionsMetric: "37.00 mm x 52.00 mm"),
    "10": documentTypeSpecification(name: "A10", documentType: .type10, dimensionsMetric: "26.00 mm x 37.00 mm"),
    "isob0": documentTypeSpecification(name: "ISO B0", documentType: .typeISOB0, dimensionsMetric: "1000.00 mm x 1414.00 mm"),
    "isob1": documentTypeSpecification(name: "ISO B1", documentType: .typeISOB1, dimensionsMetric: "707.00 mm x 1000.00 mm"),
    "isob2": documentTypeSpecification(name: "ISO B2", documentType: .typeISOB2, dimensionsMetric: "500.00 mm x 707.00 mm"),
    "isob5": documentTypeSpecification(name: "ISO B5", documentType: .typeISOB5, dimensionsMetric: "176.00 mm x 250.00 mm"),
    "isob7": documentTypeSpecification(name: "ISO B7", documentType: .typeISOB7, dimensionsMetric: "88.00 mm x 125.00 mm"),
    "isob8": documentTypeSpecification(name: "ISO B8", documentType: .typeISOB8, dimensionsMetric: "62.00 mm x 88.00 mm"),
    "isob9": documentTypeSpecification(name: "ISO B9", documentType: .typeISOB9, dimensionsMetric: "44.00 mm x 62.00 mm"),
    "isob10": documentTypeSpecification(name: "ISO B10", documentType: .typeISOB10, dimensionsMetric: "31.00 mm x 44.00 mm"),
    "jisb0": documentTypeSpecification(name: "JIS B0", documentType: .typeJISB0, dimensionsMetric: "1030.00 mm x 1456.00 mm"),
    "jisb1": documentTypeSpecification(name: "JIS B1", documentType: .typeJISB1, dimensionsMetric: "728.00 mm x 1030.00 mm"),
    "jisb2": documentTypeSpecification(name: "JIS B2", documentType: .typeJISB2, dimensionsMetric: "515.00 mm x 728.00 mm"),
    "jisb3": documentTypeSpecification(name: "JIS B3", documentType: .typeJISB3, dimensionsMetric: "364.00 mm x 515.00 mm"),
    "jisb4": documentTypeSpecification(name: "JIS B4", documentType: .typeJISB4, dimensionsMetric: "257.00 mm x 364.00 mm"),
    "jisb6": documentTypeSpecification(name: "JIS B6", documentType: .typeJISB6, dimensionsMetric: "128.00 mm x 182.00 mm"),
    "jisb7": documentTypeSpecification(name: "JIS B7", documentType: .typeJISB7, dimensionsMetric: "91.00 mm x 128.00 mm"),
    "jisb8": documentTypeSpecification(name: "JIS B8", documentType: .typeJISB8, dimensionsMetric: "64.00 mm x 91.00 mm"),
    "jisb9": documentTypeSpecification(name: "JIS B9", documentType: .typeJISB9, dimensionsMetric: "45.00 mm x 64.00 mm"),
    "jisb10": documentTypeSpecification(name: "JIS B10", documentType: .typeJISB10, dimensionsMetric: "32.00 mm x 45.00 mm"),
    "c0": documentTypeSpecification(name: "C0", documentType: .typeC0, dimensionsMetric: "917.00 mm x 1297.00 mm"),
    "c1": documentTypeSpecification(name: "C1", documentType: .typeC1, dimensionsMetric: "648.00 mm x 917.00 mm"),
    "c2": documentTypeSpecification(name: "C2", documentType: .typeC2, dimensionsMetric: "458.00 mm x 648.00 mm"),
    "c3": documentTypeSpecification(name: "C3", documentType: .typeC3, dimensionsMetric: "324.00 mm x 458.00 mm"),
    "c7": documentTypeSpecification(name: "C7", documentType: .typeC7, dimensionsMetric: "81.00 mm x 114.00 mm"),
    "c8": documentTypeSpecification(name: "C8", documentType: .typeC8, dimensionsMetric: "57.00 mm x 81.00 mm"),
    "c9": documentTypeSpecification(name: "C9", documentType: .typeC9, dimensionsMetric: "40.00 mm x 57.00 mm"),
    "c10": documentTypeSpecification(name: "C10", documentType: .typeC10, dimensionsMetric: "28.00 mm x 40.00 mm"),
    "usstatement": documentTypeSpecification(name: "US Statement", documentType: .typeUSStatement, dimensionsImperial: "5.5\" x 8.5\"", dimensionsMetric: "139.70 mm x 215.90 mm"),
    "businesscard": documentTypeSpecification(name: "Business Card", documentType: .typeBusinessCard, dimensionsMetric: "90.00 mm x 55.00 mm"),
    "e": documentTypeSpecification(name: "Japanese E", documentType: .typeE, dimensionsImperial: "3.25\" x 4.75\"", dimensionsMetric: "82.55 mm x 120.65 mm"),
    "3r": documentTypeSpecification(name: "3R", documentType: .type3R, dimensionsImperial: "3.5\" x 5\"", dimensionsMetric: "88.90 mm x 127.00 mm", ratio: "7:10"),
    "4r": documentTypeSpecification(name: "4R", documentType: .type4R, dimensionsImperial: "4\" x 6\"", dimensionsMetric: "101.60 mm x 152.40 mm", ratio: "2:3"),
    "5r": documentTypeSpecification(name: "5R", documentType: .type5R, dimensionsImperial: "5\" x 7\"", dimensionsMetric: "127.00 mm x 177.80 mm", ratio: "5:7"),
    "6r": documentTypeSpecification(name: "6R", documentType: .type6R, dimensionsImperial: "6\" x 8\"", dimensionsMetric: "152.40 mm x 203.20 mm", ratio: "3:4"),
    "8r": documentTypeSpecification(name: "8R", documentType: .type8R, dimensionsImperial: "8\" x 10\"", dimensionsMetric: "203.20 mm x 254.00 mm", ratio: "4:5"),
    "10r": documentTypeSpecification(name: "10R", documentType: .type10R, dimensionsImperial: "10\" x 12\"", dimensionsMetric: "254.00 mm x 304.80 mm", ratio: "5:6"),
    "s10r": documentTypeSpecification(name: "S10R", documentType: .typeS10R, dimensionsImperial: "10\" x 15\"", dimensionsMetric: "254.00 mm x 381.00 mm", ratio: "2:3"),
    "11r": documentTypeSpecification(name: "11R", documentType: .type11R, dimensionsImperial: "11\" x 14\"", dimensionsMetric: "279.40 mm x 355.60 mm"),
    "12r": documentTypeSpecification(name: "12R", documentType: .type12R, dimensionsImperial: "12\" x 15\"", dimensionsMetric: "304.80 mm x 381.00 mm", ratio: "4:5"),
    "s12r": documentTypeSpecification(name: "S12R", documentType: .typeS12R, dimensionsImperial: "12\" x 18\"", dimensionsMetric: "304.80 mm x 457.20 mm", ratio: "2:3"),
]

extension ICScannerFunctionalUnitDocumentFeeder {
    func supportedDocumentTypes() -> String {
        return documentTypes.filter( {
            self.supportedDocumentTypes.contains( Int( $0.value.documentType.rawValue ) )
        } ).map( {
            $0.key
        } ).sorted(by: <).joined(separator: "; ")
    }
}

extension ICScannerFunctionalUnitFlatbed {
    func supportedDocumentTypes() -> String {
        return documentTypes.filter( {
            self.supportedDocumentTypes.contains( Int( $0.value.documentType.rawValue ) )
        } ).map( {
            $0.key
        } ).sorted(by: <).joined(separator: "; ")
    }
}


extension Int {
    // format to 2 decimal places
    func f02ld() -> String {
        return String(format: "%02ld", self)
    }
    
    func fld() -> String {
        return String(format: "%ld", self)
    }
}

class ScanlineOutputProcessor {
    let logger: Logger
    let configuration: ScanConfiguration
    let urls: [URL]
    
    init(urls: [URL], configuration: ScanConfiguration, logger: Logger) {
        self.urls = urls
        self.configuration = configuration
        self.logger = logger
    }
    
    func process() -> Bool {
        let wantsPDF = configuration.config[ScanlineConfigOptionJPEG] == nil
            && configuration.config[ScanlineConfigOptionTIFF] == nil
            && configuration.config[ScanlineConfigOptionPNG] == nil
        if !wantsPDF {
            for url in urls {
                outputAndTag(url: url)
            }
        } else {
            // Combine into a single PDF
            if let combinedURL = combine(urls: urls) {
                outputAndTag(url: combinedURL)
            } else {
                logger.log("Error while creating PDF")
                return false
            }
        }
        
        return true
    }
    
    func combine(urls: [URL]) -> URL? {
        let document = PDFDocument()
        
        for url in urls {
            if let page = PDFPage(image: NSImage(byReferencing: url)) {
                document.insert(page, at: document.pageCount)
            }
        }
        
        let tempFilePath = "\(NSTemporaryDirectory())/scan.pdf"
        document.write(toFile: tempFilePath)
        
        return URL(fileURLWithPath: tempFilePath)
    }

    func outputAndTag(url: URL) {
        let gregorian = NSCalendar(calendarIdentifier: .gregorian)!
        let dateComponents = gregorian.components([.year, .hour, .minute, .second], from: Date())
        
        let outputRootDirectory = configuration.config[ScanlineConfigOptionDir] as! String
        var path = outputRootDirectory
        
        // If there's a tag, move the file to the first tag location
        if configuration.tags.count > 0 {
            path = "\(path)/\(configuration.tags[0])/\(dateComponents.year!.fld())"
        }
        
        logger.verbose("Output path: \(path)")

        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.log("Error while creating directory \(path)")
            return
        }
        
        let destinationFileExtension: String
        if configuration.config[ScanlineConfigOptionTIFF] != nil {
            destinationFileExtension = "tif"
        } else if configuration.config[ScanlineConfigOptionJPEG] != nil {
            destinationFileExtension = "jpg"
        } else if configuration.config[ScanlineConfigOptionPNG] != nil {
            destinationFileExtension = "png"
        } else {
            destinationFileExtension = "pdf"
        }
        
        let destinationFileRoot: String = { () -> String in
            if let fileName = self.configuration.config[ScanlineConfigOptionName] {
                return "\(path)/\(fileName)"
            }
            return "\(path)/scan_\(dateComponents.hour!.f02ld())\(dateComponents.minute!.f02ld())\(dateComponents.second!.f02ld())"
        }()
        
        var destinationFilePath = "\(destinationFileRoot).\(destinationFileExtension)"
        var i = 0
        while FileManager.default.fileExists(atPath: destinationFilePath) {
            destinationFilePath = "\(destinationFileRoot).\(i).\(destinationFileExtension)"
            i += 1
        }
        
        logger.verbose("About to copy \(url.absoluteString) to \(destinationFilePath)")

        let destinationURL = URL(fileURLWithPath: destinationFilePath)
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        } catch {
            logger.log("Error while copying file to \(destinationURL.absoluteString)")
            return
        }

        // Alias to all other tag locations
        // TODO: this is super repetitive with above...
        if configuration.tags.count > 1 {
            for tag in configuration.tags.subarray(with: NSMakeRange(1, configuration.tags.count - 1)) {
                logger.verbose("Aliasing to tag \(tag)")
                let aliasDirPath = "\(outputRootDirectory)/\(tag)/\(dateComponents.year!.fld())"
                do {
                    try FileManager.default.createDirectory(atPath: aliasDirPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    logger.log("Error while creating directory \(aliasDirPath)")
                    return
                }
                let aliasFileRoot = { () -> String in
                    if let name = configuration.config[ScanlineConfigOptionName] {
                        return "\(aliasDirPath)/\(name)"
                    }
                    return "\(aliasDirPath)/scan_\(dateComponents.hour!.f02ld())\(dateComponents.minute!.f02ld())\(dateComponents.second!.f02ld())"
                }()
                var aliasFilePath = "\(aliasFileRoot).\(destinationFileExtension)"
                var i = 0
                while FileManager.default.fileExists(atPath: aliasFilePath) {
                    aliasFilePath = "\(aliasFileRoot).\(i).\(destinationFileExtension)"
                    i += 1
                }
                logger.verbose("Aliasing to \(aliasFilePath)")
                do {
                    try FileManager.default.createSymbolicLink(atPath: aliasFilePath, withDestinationPath: destinationFilePath)
                } catch {
                    logger.log("Error while creating alias at \(aliasFilePath)")
                    return
                }
            }
        }
        
        if configuration.config[ScanlineConfigOptionOpen] != nil {
            logger.verbose("Opening file at \(destinationFilePath)")
            NSWorkspace.shared.openFile(destinationFilePath)
        }
    }
}
