//
//  ConfigurationTests.swift
//  ConfigurationTests
//
//  Created by Scott J. Kleper on 5/9/21.
//  Copyright © 2021 Scott J. Kleper. All rights reserved.
//

import XCTest
@testable import libscanline

class ConfigurationTests: XCTestCase {
    private lazy var testConfigPath = Bundle(for: ConfigurationTests.self).path(forResource: "config_test", ofType: "conf") ?? ""
        
    func testLoadConfigurationFromFile() {
        let testConfig = ScanConfiguration(arguments: [], configFilePath: testConfigPath)
        
        XCTAssertTrue(testConfig.config[ScanlineConfigOptionDuplex] as? Bool == true)
        XCTAssertFalse(testConfig.config[ScanlineConfigOptionBatch] as? Bool == true)
        XCTAssertFalse(testConfig.config[ScanlineConfigOptionFlatbed] as? Bool == true)
        XCTAssertEqual(testConfig.config[ScanlineConfigOptionName] as? String, "the_name")
    }
    
    func testLoadConfigurationFromFileWithArgumentOverride() {
        let testConfig = ScanConfiguration(arguments: ["-flatbed"], configFilePath: testConfigPath)
        
        XCTAssertTrue(testConfig.config[ScanlineConfigOptionDuplex] as? Bool == true)
        XCTAssertFalse(testConfig.config[ScanlineConfigOptionBatch] as? Bool == true)
        XCTAssertTrue(testConfig.config[ScanlineConfigOptionFlatbed] as? Bool == true)
        XCTAssertEqual(testConfig.config[ScanlineConfigOptionName] as? String, "the_name")
    }
    
    func testGettingTagsFromCommandLine() {
        let testConfig = ScanConfiguration(arguments: ["taxes-2013"], configFilePath: testConfigPath)

        XCTAssertEqual(testConfig.tags.firstObject as? String, "taxes-2013")
    }

    func testFlatbedDoubleDashOption() {
        let testConfig = ScanConfiguration(arguments: ["--flatbed"])
        XCTAssertTrue(testConfig.config[ScanlineConfigOptionFlatbed] as? Bool == true)
    }

    func testStringOptionEqualsSyntax() {
        let testConfig = ScanConfiguration(arguments: ["--resolution=450"])
        XCTAssertEqual(testConfig.config[ScanlineConfigOptionResolution] as? String ?? "", "450")
    }

    func testDefaultFormatIsPdf() {
        let testConfig = ScanConfiguration(arguments: [])
        XCTAssertEqual(testConfig.normalizedScanOutputFormat(), "pdf")
    }

    func testFormatEqualsSyntax() {
        let testConfig = ScanConfiguration(arguments: ["--format=tiff"])
        XCTAssertEqual(testConfig.normalizedScanOutputFormat(), "tiff")
    }

    func testFormatSynonymLowercaseJpg() {
        let testConfig = ScanConfiguration(arguments: ["--format=jpg"])
        XCTAssertEqual(testConfig.normalizedScanOutputFormat(), "jpeg")
    }

    func testInvalidFormatFallsBackToPdf() {
        let testConfig = ScanConfiguration(arguments: ["--format=wav"])
        XCTAssertEqual(testConfig.normalizedScanOutputFormat(), "pdf")
    }

    func testJpegOption() {
        let testConfig = ScanConfiguration(arguments: ["-jpeg"])
        XCTAssertEqual(testConfig.normalizedScanOutputFormat(), "jpeg")
    }

    func testJpegOptionWithJpg() {
        let testConfig = ScanConfiguration(arguments: ["-jpg"])
        XCTAssertEqual(testConfig.normalizedScanOutputFormat(), "jpeg")
    }

    func testResolutionOptionWithNonNumericalValue() {
        let testConfig = ScanConfiguration(arguments: ["-resolution", "booger"])
        
        XCTAssertNil(testConfig.config[ScanlineConfigOptionResolution] as? Int)
    }
    
    func testLetterNotLegalPageSize() {
        let letter = ScanConfiguration(arguments: ["-letter"])
        XCTAssertEqual(letter.normalizedPageSizeCatalogKey(), "usletter")
        XCTAssertNotEqual(letter.normalizedPageSizeCatalogKey(), "uslegal")

        let legal = ScanConfiguration(arguments: ["-legal"])
        XCTAssertEqual(legal.normalizedPageSizeCatalogKey(), "uslegal")
        XCTAssertNotEqual(legal.normalizedPageSizeCatalogKey(), "usletter")
    }

    func testPageSizeEqualsSyntax() {
        let testConfig = ScanConfiguration(arguments: ["--page-size=a4"])
        XCTAssertEqual(testConfig.normalizedPageSizeCatalogKey(), "a4")
    }

    func testLedgerLegacyFlag() {
        let testConfig = ScanConfiguration(arguments: ["--ledger"])
        XCTAssertEqual(testConfig.normalizedPageSizeCatalogKey(), "usledger")
    }

    func testListPageSizesSetsFlag() {
        let testConfig = ScanConfiguration(arguments: ["--list-page-sizes"])
        XCTAssertEqual(testConfig.config[ScanlineConfigOptionListPageSizes] as? Bool, true)
    }

    func testDocumentTypeDeprecatedSynonym() {
        let testConfig = ScanConfiguration(arguments: ["--document-type", "uslegal"])
        XCTAssertEqual(testConfig.normalizedPageSizeCatalogKey(), "uslegal")
    }
    
    func testMissingSecondParameter() {
        // This would throw an array out of bounds error previously.
        _ = ScanConfiguration(arguments: ["-scanner"], configFilePath: testConfigPath)
        
        let testConfig = ScanConfiguration(arguments: ["-scanner", "epson"])
        XCTAssertEqual(testConfig.config[ScanlineConfigOptionScanner] as? String ?? "", "epson")
    }
}
