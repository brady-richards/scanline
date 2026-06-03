//
//  ScannerCapabilities.swift
//  libscanline
//

import Foundation
import ImageCaptureCore

private struct FunctionalUnitReport {
    let type: ICScannerFunctionalUnitType
    let pageSizeKeys: [String]
    let resolutions: [Int]
    let preferredResolutions: [Int]
    let bitDepths: [Int]
    let nativeXResolution: Int
    let nativeYResolution: Int
    let measurementUnit: ICScannerMeasurementUnit
    let physicalWidth: Double
    let physicalHeight: Double
    let supportsDuplex: Bool?
    let documentLoaded: Bool?
    let reverseFeederPageOrder: Bool?
    let queriedSeparately: Bool
}

enum ScannerCapabilitiesReporter {
    static func capabilityLinesFromScannerSync(
        scanner: ICScannerDevice,
        timeoutSeconds: TimeInterval = 35
    ) -> [String] {
        let runner = ScannerCapabilitiesRunner(scanner: scanner)
        if Thread.isMainThread {
            return runner.runBlocking(timeout: timeoutSeconds)
        }
        var lines: [String] = []
        DispatchQueue.main.sync {
            lines = runner.runBlocking(timeout: timeoutSeconds)
        }
        return lines
    }
}

private enum ScannerCapabilitiesFormatting {
    static func functionalUnitLabel(_ type: ICScannerFunctionalUnitType) -> String {
        switch type {
        case .flatbed:
            return "Flatbed"
        case .documentFeeder:
            return "Document feeder"
        case .positiveTransparency:
            return "Positive transparency"
        case .negativeTransparency:
            return "Negative transparency"
        @unknown default:
            return "Functional unit \(type.rawValue)"
        }
    }

    static func measurementUnitLabel(_ unit: ICScannerMeasurementUnit) -> String {
        switch unit {
        case .inches:
            return "inches"
        case .centimeters:
            return "centimeters"
        case .picas:
            return "picas"
        case .points:
            return "points"
        case .twips:
            return "twips"
        case .pixels:
            return "pixels"
        @unknown default:
            return "unit \(unit.rawValue)"
        }
    }

    static func sortedInts(from indexSet: IndexSet) -> [Int] {
        indexSet.map { $0 }.sorted()
    }

    static func joinedInts(_ values: [Int]) -> String {
        values.map(String.init).joined(separator: ", ")
    }

    static func resolutionLines(supported: [Int], preferred: [Int]) -> [String] {
        var lines: [String] = []
        guard !supported.isEmpty || !preferred.isEmpty else { return lines }

        if supported.count > 40, let first = supported.first, let last = supported.last,
           last - first + 1 == supported.count {
            lines.append("  Resolutions (dpi): \(first)–\(last) (continuous)")
        } else if !supported.isEmpty {
            lines.append("  Resolutions (dpi): \(joinedInts(supported))")
        }

        if !preferred.isEmpty {
            lines.append("  Preferred resolutions (dpi): \(joinedInts(preferred))")
        }
        return lines
    }

    static func formatSize(width: Double, height: Double, unit: ICScannerMeasurementUnit) -> String {
        let unitLabel = measurementUnitLabel(unit)
        let w = trimmedDecimal(width)
        let h = trimmedDecimal(height)
        return "\(w) x \(h) (\(unitLabel))"
    }

    private static func trimmedDecimal(_ x: Double) -> String {
        if abs(x.rounded(.towardZero) - x) < 1e-9 && abs(x) <= Double(Int.max) {
            return String(Int(x))
        }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: x)) ?? String(x)
    }

    private static func unitSortOrder(_ type: ICScannerFunctionalUnitType) -> Int {
        switch type {
        case .flatbed: return 0
        case .documentFeeder: return 1
        case .positiveTransparency: return 2
        case .negativeTransparency: return 3
        @unknown default: return 99
        }
    }

    static func lines(for scanner: ICScannerDevice, reports: [FunctionalUnitReport]) -> [String] {
        var lines: [String] = []
        let scannerName = scanner.name ?? "selected scanner"
        lines.append("Scanner: \(scannerName)")

        let availableTypes = scanner.availableFunctionalUnitTypes
            .compactMap { ICScannerFunctionalUnitType(rawValue: $0.uintValue) }
        let unitLabels = availableTypes.map { functionalUnitLabel($0).lowercased() }
        if !unitLabels.isEmpty {
            lines.append("Available functional units: \(unitLabels.joined(separator: ", "))")
        }
        lines.append("")

        let reportsByType = Dictionary(uniqueKeysWithValues: reports.map { ($0.type, $0) })
        let typesToShow = availableTypes.isEmpty ? reports.map(\.type) : availableTypes

        for type in typesToShow.sorted(by: { unitSortOrder($0) < unitSortOrder($1) }) {
            guard let report = reportsByType[type] else {
                lines.append(functionalUnitLabel(type))
                lines.append("  (capabilities unavailable from driver)")
                lines.append("")
                continue
            }

            lines.append(functionalUnitLabel(report.type))
            if !report.queriedSeparately {
                lines.append("  (driver returned shared capabilities for this unit; see above)")
                lines.append("")
                continue
            }
            appendPageSizes(to: &lines, keys: report.pageSizeKeys)
            lines.append(contentsOf: resolutionLines(supported: report.resolutions, preferred: report.preferredResolutions))
            appendBitDepths(to: &lines, bitDepths: report.bitDepths)
            appendNativeResolution(to: &lines, report: report)
            appendPaperHandling(to: &lines, report: report)
            if report.physicalWidth > 0 || report.physicalHeight > 0 {
                lines.append("  Scan area: \(formatSize(width: report.physicalWidth, height: report.physicalHeight, unit: report.measurementUnit))")
            }
            lines.append("")
        }

        if lines.last == "" {
            lines.removeLast()
        }
        return lines
    }

    private static func appendPageSizes(to lines: inout [String], keys: [String]) {
        lines.append("  Page sizes:")
        if keys.isEmpty {
            lines.append("    (none reported)")
            return
        }
        for line in PageSizeCatalog.listingTableLines(catalogKeysInOrder: keys) {
            lines.append("    \(line)")
        }
    }

    private static func appendBitDepths(to lines: inout [String], bitDepths: [Int]) {
        if !bitDepths.isEmpty {
            lines.append("  Bit depths: \(joinedInts(bitDepths))")
        }
    }

    private static func appendNativeResolution(to lines: inout [String], report: FunctionalUnitReport) {
        if report.nativeXResolution > 0 || report.nativeYResolution > 0 {
            lines.append("  Native optical resolution: \(report.nativeXResolution) x \(report.nativeYResolution) dpi")
        }
    }

    private static func appendPaperHandling(to lines: inout [String], report: FunctionalUnitReport) {
        if let supportsDuplex = report.supportsDuplex {
            lines.append("  Duplex scanning: \(supportsDuplex ? "supported" : "not supported")")
        }
        if let documentLoaded = report.documentLoaded {
            lines.append("  Document loaded: \(documentLoaded ? "yes" : "no")")
        }
        if let reverseFeederPageOrder = report.reverseFeederPageOrder {
            lines.append("  Reverse feeder page order: \(reverseFeederPageOrder ? "yes" : "no")")
        }
    }
}

private final class ScannerCapabilitiesRunner: NSObject, ICScannerDeviceDelegate {
    private let scanner: ICScannerDevice
    private let priorDelegate: ICDeviceDelegate?
    private var completed = false
    private var resultLines: [String] = []

    private var pendingUnitTypes: [ICScannerFunctionalUnitType] = []
    private var collectedReports: [FunctionalUnitReport] = []
    private var issuedInitialSelectionAfterBecomeReady = false

    init(scanner: ICScannerDevice) {
        self.scanner = scanner
        self.priorDelegate = scanner.delegate
        super.init()
    }

    func runBlocking(timeout: TimeInterval) -> [String] {
        completed = false
        resultLines = []
        collectedReports = []
        issuedInitialSelectionAfterBecomeReady = false
        pendingUnitTypes = []

        scanner.delegate = self
        if scanner.hasOpenSession {
            scanner.requestCloseSession()
        }
        scanner.requestOpenSession()

        let deadline = Date().addingTimeInterval(timeout)
        while !completed && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))
        }

        if !completed {
            if scanner.hasOpenSession {
                scanner.requestCloseSession()
            }
            scanner.delegate = priorDelegate
            return []
        }
        return resultLines
    }

    private func beginFunctionalUnitQueryIfNeeded() {
        guard !issuedInitialSelectionAfterBecomeReady else { return }

        let unitTypes = scanner.availableFunctionalUnitTypes
            .compactMap { ICScannerFunctionalUnitType(rawValue: $0.uintValue) }
        guard !unitTypes.isEmpty else { return }

        issuedInitialSelectionAfterBecomeReady = true
        pendingUnitTypes = unitTypes
        selectNextFunctionalUnit()
    }

    private func finish(_ lines: [String]) {
        guard !completed else { return }
        completed = true
        resultLines = lines
        if scanner.hasOpenSession {
            scanner.requestCloseSession()
        }
        scanner.delegate = priorDelegate
    }

    private func fail() {
        finish([])
    }

    private func functionalUnitIsUsable(_ functionalUnit: ICScannerFunctionalUnit) -> Bool {
        let address = unsafeBitCast(functionalUnit, to: Int.self)
        return address != 0
    }

    private func report(from functionalUnit: ICScannerFunctionalUnit, labelAs type: ICScannerFunctionalUnitType, queriedSeparately: Bool) -> FunctionalUnitReport {
        let pageSizeKeys = PageSizeCatalog.supportedCatalogKeys(for: functionalUnit)
        var supportsDuplex: Bool?
        var documentLoaded: Bool?
        var reverseFeederPageOrder: Bool?
        if let feeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            supportsDuplex = feeder.supportsDuplexScanning
            documentLoaded = feeder.documentLoaded
            reverseFeederPageOrder = feeder.reverseFeederPageOrder
        }
        let physicalSize = functionalUnit.physicalSize
        return FunctionalUnitReport(
            type: type,
            pageSizeKeys: pageSizeKeys,
            resolutions: ScannerCapabilitiesFormatting.sortedInts(from: functionalUnit.supportedResolutions),
            preferredResolutions: ScannerCapabilitiesFormatting.sortedInts(from: functionalUnit.preferredResolutions),
            bitDepths: ScannerCapabilitiesFormatting.sortedInts(from: functionalUnit.supportedBitDepths),
            nativeXResolution: Int(functionalUnit.nativeXResolution),
            nativeYResolution: Int(functionalUnit.nativeYResolution),
            measurementUnit: functionalUnit.measurementUnit,
            physicalWidth: Double(physicalSize.width),
            physicalHeight: Double(physicalSize.height),
            supportsDuplex: supportsDuplex,
            documentLoaded: documentLoaded,
            reverseFeederPageOrder: reverseFeederPageOrder,
            queriedSeparately: queriedSeparately
        )
    }

    private func selectNextFunctionalUnit() {
        guard let nextType = pendingUnitTypes.first else {
            finish(ScannerCapabilitiesFormatting.lines(for: scanner, reports: collectedReports))
            return
        }
        scanner.requestSelect(nextType)
    }

    func device(_ device: ICDevice, didEncounterError error: Error?) {
        fail()
    }

    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        if error != nil {
            fail()
            return
        }
        // Some drivers are ready immediately after session open without deviceDidBecomeReady.
        beginFunctionalUnitQueryIfNeeded()
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
    }

    func didRemove(_ device: ICDevice) {
    }

    func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
    }

    func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
    }

    func deviceDidBecomeReady(_ device: ICDevice) {
        guard device === scanner else { return }
        beginFunctionalUnitQueryIfNeeded()
    }

    func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        guard scanner === self.scanner else { return }
        guard !completed else { return }
        guard let requestedType = pendingUnitTypes.first else {
            finish(ScannerCapabilitiesFormatting.lines(for: scanner, reports: collectedReports))
            return
        }

        if error == nil, functionalUnitIsUsable(functionalUnit) {
            let queriedSeparately = functionalUnit.type == requestedType
            collectedReports.append(report(from: functionalUnit, labelAs: requestedType, queriedSeparately: queriedSeparately))
        }

        pendingUnitTypes.removeFirst()
        selectNextFunctionalUnit()
    }
}
