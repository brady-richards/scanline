//
//  ScanlineOutputProcessor.swift
//  libscanline
//
//  Created by Scott J. Kleper on 5/13/21.
//  Copyright © 2021 Scott J. Kleper. All rights reserved.
//

import Foundation
import AppKit
import Quartz

public class ScanlineOutputProcessor {
    let logger: Logger
    let configuration: ScanConfiguration
    let urls: [URL]
    
    public init(urls: [URL], configuration: ScanConfiguration, logger: Logger) {
        self.urls = urls
        self.configuration = configuration
        self.logger = logger
    }
    
    public func process() -> Bool {
        let fmt = configuration.normalizedScanOutputFormat()
        let wantsPDF = fmt == "pdf"

        if !wantsPDF {
            for url in urls {
                outputAndTag(url: url)
            }
        } else {
            // Combine into a single PDF
            if let combinedURL = combine(urls: urls) {
                outputAndTag(url: combinedURL)
            } else {
                return false
            }
        }
        
        return true
    }
    
    public func combine(urls: [URL]) -> URL? {
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

    public func outputAndTag(url: URL) {
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
        switch configuration.normalizedScanOutputFormat() {
        case "tiff":
            destinationFileExtension = "tif"
        case "jpeg":
            destinationFileExtension = "jpg"
        case "png":
            destinationFileExtension = "png"
        default:
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

        logger.log(destinationFilePath)

        // Alias to all other tag locations
        // todo: this is super repetitive with above...
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
        
        openScannedFileIfRequested(at: destinationFilePath)
    }

    private func openScannedFileIfRequested(at destinationFilePath: String) {
        let openWith = configuration.config[ScanlineConfigOptionOpenWith] as? String
        let shouldOpen = configuration.config[ScanlineConfigOptionOpen] != nil
            || (openWith?.isEmpty == false)
        guard shouldOpen else { return }

        logger.verbose("Opening file at \(destinationFilePath)")

        if let openWith, !openWith.isEmpty {
            guard let appURL = Self.applicationURL(for: openWith) else {
                logger.log("scanline: could not find application for --open-with `\(openWith)'")
                return
            }
            if !NSWorkspace.shared.openFile(destinationFilePath, withApplication: appURL.path) {
                logger.log("scanline: error opening file with `\(appURL.path)'")
            }
            return
        }

        NSWorkspace.shared.openFile(destinationFilePath)
    }

    private static func applicationURL(for specifier: String) -> URL? {
        let trimmed = specifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let expandedPath = (trimmed as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath) {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: expandedPath, isDirectory: true)
            }
            return URL(fileURLWithPath: expandedPath)
        }

        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed) {
            return bundleURL
        }

        if let appPath = NSWorkspace.shared.fullPath(forApplication: trimmed) {
            return URL(fileURLWithPath: appPath)
        }

        return nil
    }
}

fileprivate extension Int {
    // format to 2 decimal places
    func f02ld() -> String {
        return String(format: "%02ld", self)
    }
    
    func fld() -> String {
        return String(format: "%ld", self)
    }
}
