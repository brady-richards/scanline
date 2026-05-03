//
//  ScannerDocumentTypes.swift
//  libscanline
//
//  Document size catalog shared by ScannerController feeder configuration.
//

import Foundation
import ImageCaptureCore

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
        documentTypes.filter {
            supportedDocumentTypes.contains(Int($0.value.documentType.rawValue))
        }.map { $0.key }.sorted(by: <).joined(separator: "; ")
    }
}

extension ICScannerFunctionalUnitFlatbed {
    func supportedDocumentTypes() -> String {
        documentTypes.filter {
            supportedDocumentTypes.contains(Int($0.value.documentType.rawValue))
        }.map { $0.key }.sorted(by: <).joined(separator: "; ")
    }
}
