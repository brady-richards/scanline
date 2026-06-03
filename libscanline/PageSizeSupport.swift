//
//  PageSizeSupport.swift
//  libscanline
//

import Foundation
import ImageCaptureCore

private func slStderrWarn(_ msg: String) {
    fputs("\(msg)\n", stderr)
}

/// Normalization for `--page-size` (catalog keys in `ScannerDocumentTypes.swift`).
enum PageSizeCatalog {
    static let defaultCatalogKey = "usletter"

    private static let synonyms: [String: String] = [
        "letter": "usletter",
        "us-letter": "usletter",
        "legal": "uslegal",
        "ledger": "usledger",
        "tabloid": "usledger",
    ]

    /// Width × height in mm² when dimensions can be parsed; used for `--list-page-sizes` ordering.
    private static func areaSquareMillimeters(for catalogKey: String) -> Double? {
        guard let spec = documentTypes[catalogKey] else { return nil }
        if let metric = spec.dimensionsMetric, let pair = parseMillimeterPair(from: metric) {
            return pair.0 * pair.1
        }
        if let imperial = spec.dimensionsImperial, let pair = parseInchPair(from: imperial) {
            let w = pair.0 * 25.4
            let h = pair.1 * 25.4
            return w * h
        }
        return nil
    }

    private static func parseMillimeterPair(from text: String) -> (Double, Double)? {
        let ns = text as NSString
        let pattern = #"(\d+(?:\.\d+)?)\s*mm\s+x\s+(\d+(?:\.\d+)?)\s*mm"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = re.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges == 3,
              let r1 = Range(match.range(at: 1), in: text),
              let r2 = Range(match.range(at: 2), in: text),
              let w = Double(text[r1]),
              let h = Double(text[r2]) else {
            return nil
        }
        return (w, h)
    }

    private static func parseInchPair(from text: String) -> (Double, Double)? {
        let ns = text as NSString
        let pattern = "(\\d+(?:\\.\\d+)?)\\s*\"\\s+x\\s+(\\d+(?:\\.\\d+)?)\\s*\""
        guard let re = try? NSRegularExpression(pattern: pattern, options: []),
              let match = re.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges == 3,
              let r1 = Range(match.range(at: 1), in: text),
              let r2 = Range(match.range(at: 2), in: text),
              let w = Double(text[r1]),
              let h = Double(text[r2]) else {
            return nil
        }
        return (w, h)
    }

    fileprivate static func compareCatalogKeysIncreasingArea(_ a: String, _ b: String) -> Bool {
        let areaA = areaSquareMillimeters(for: a) ?? .infinity
        let areaB = areaSquareMillimeters(for: b) ?? .infinity
        if areaA != areaB {
            return areaA < areaB
        }
        return a < b
    }

    /// Sort a set of preset keys by increasing nominal area (`default` dropped).
    static func sortedCatalogKeysIncreasingArea(uniqueKeys keys: Set<String>) -> [String] {
        keys.filter { $0 != "default" }.sorted(by: compareCatalogKeysIncreasingArea)
    }

    static func sortedCatalogKeys() -> [String] {
        Array(documentTypes.keys).sorted(by: compareCatalogKeysIncreasingArea)
    }

    /// Collapses needless trailing zeros after the decimal (`215.90` → `215.9`, `11.0` → `11`).
    private static func compactDecimals(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\d+\.\d+"#, options: []) else {
            return text
        }
        var out = ""
        var lastUpper = text.startIndex
        let full = NSRange(location: 0, length: (text as NSString).length)
        for match in regex.matches(in: text, options: [], range: full) {
            guard let range = Range(match.range, in: text) else { continue }
            out += text[lastUpper..<range.lowerBound]
            let token = String(text[range])
            if let value = Double(token), value.isFinite {
                out += trimmedDecimal(value)
            } else {
                out += token
            }
            lastUpper = range.upperBound
        }
        out += text[lastUpper...]
        return String(out)
    }

    private static func trimmedDecimal(_ x: Double) -> String {
        if abs(x.rounded(.towardZero) - x) < 1e-9 && abs(x) <= Double(Int.max) {
            return String(Int(x))
        }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: x)) ?? String(x)
    }

    /// Third column text: imperial when present, else metric; decimals trimmed (`--page-size` display).
    private static func dimensionsColumn(for spec: documentTypeSpecification) -> String {
        let raw: String
        if let imp = spec.dimensionsImperial {
            raw = imp
        } else if let met = spec.dimensionsMetric {
            raw = met
        } else {
            return ""
        }
        return compactDecimals(raw)
    }

    /// Left-aligned field padded to grapheme-cluster width (`width ≥` each row’s printed width).
    private static func leftPaddedColumn(_ text: String, width: Int) -> String {
        let extra = width - text.count
        guard extra > 0 else {
            return text
        }
        return text + String(repeating: " ", count: extra)
    }

    /** Preset key (column 1), display name (column 2), dimensions (column 3), spaced for alignment within this table. Drops `default`. */
    static func listingTableLines(catalogKeysInOrder keys: [String]) -> [String] {
        let rows: [(String, String, String)] = keys.compactMap { key in
            guard key != "default", let spec = documentTypes[key] else {
                return nil
            }
            return (key, spec.name, dimensionsColumn(for: spec))
        }
        guard !rows.isEmpty else {
            return []
        }
        let presetWidth = rows.map { $0.0.count }.max() ?? 0
        let nameWidth = rows.map { $0.1.count }.max() ?? 0
        return rows.map { preset, name, dim in
            "\(leftPaddedColumn(preset, width: presetWidth))  \(leftPaddedColumn(name, width: nameWidth))  \(dim)"
        }
    }

    static func canonicalCatalogKey(for rawInput: String?) -> String {
        guard let trimmed = rawInput?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return defaultCatalogKey
        }
        let lc = trimmed.lowercased()
        if let mapped = synonyms[lc] {
            return mapped
        }
        if documentTypes[lc] != nil {
            return lc
        }
        slStderrWarn("scanline: invalid --page-size `\(trimmed)' using \(defaultCatalogKey)")
        return defaultCatalogKey
    }

    static func supportedCatalogKeys(for functionalUnit: ICScannerFunctionalUnit) -> [String] {
        if let feeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            return documentTypes.filter {
                feeder.supportedDocumentTypes.contains(Int($0.value.documentType.rawValue))
            }
            .map(\.key)
            .sorted(by: compareCatalogKeysIncreasingArea)
        }
        if let flatbed = functionalUnit as? ICScannerFunctionalUnitFlatbed {
            return documentTypes.filter {
                flatbed.supportedDocumentTypes.contains(Int($0.value.documentType.rawValue))
            }
            .map(\.key)
            .sorted(by: compareCatalogKeysIncreasingArea)
        }
        if let transparency = functionalUnit as? ICScannerFunctionalUnitPositiveTransparency {
            return documentTypes.filter {
                transparency.supportedDocumentTypes.contains(Int($0.value.documentType.rawValue))
            }
            .map(\.key)
            .sorted(by: compareCatalogKeysIncreasingArea)
        }
        if let transparency = functionalUnit as? ICScannerFunctionalUnitNegativeTransparency {
            return documentTypes.filter {
                transparency.supportedDocumentTypes.contains(Int($0.value.documentType.rawValue))
            }
            .map(\.key)
            .sorted(by: compareCatalogKeysIncreasingArea)
        }
        return []
    }
}

extension ScanConfiguration {
    @objc(canonicalizePageSizeStoredConfiguration)
    public func canonicalizePageSizeStoredConfiguration() {
        config[ScanlineConfigOptionPageSize] = PageSizeCatalog.canonicalCatalogKey(
            for: config[ScanlineConfigOptionPageSize] as? String
        )
    }

    @objc(normalizedPageSizeCatalogKey)
    public func normalizedPageSizeCatalogKey() -> String {
        PageSizeCatalog.canonicalCatalogKey(for: config[ScanlineConfigOptionPageSize] as? String)
    }
}

/// Samples supported page-size catalog keys from a scanner (session + functional unit).
private final class PageSizeListerRunner: NSObject, ICScannerDeviceDelegate {
    private let scanner: ICScannerDevice
    private let wantsFlatbedOnly: Bool
    private let priorDelegate: ICDeviceDelegate?
    private var completed = false
    private var resultKeys: [String] = []

    private var pendingExpectedUnitType: ICScannerFunctionalUnitType = .documentFeeder
    private var issuedInitialSelectionAfterBecomeReady = false
    /// ADF round done; awaiting flatbed `didSelect`. Unused when listing flatbed-only.
    private var awaitingFlatbedAfterFeederRound = false
    private var feederKeysCollected: Set<String> = []

    init(scanner: ICScannerDevice, wantsFlatbed: Bool) {
        self.scanner = scanner
        self.wantsFlatbedOnly = wantsFlatbed
        self.priorDelegate = scanner.delegate
        super.init()
    }

    func runBlocking(timeout: TimeInterval) -> [String] {
        completed = false
        resultKeys = []
        feederKeysCollected = []
        awaitingFlatbedAfterFeederRound = false
        issuedInitialSelectionAfterBecomeReady = false
        pendingExpectedUnitType = wantsFlatbedOnly ? .flatbed : .documentFeeder

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
        return resultKeys
    }

    private func finish(_ keys: [String]) {
        guard !completed else { return }
        completed = true
        resultKeys = keys
        if scanner.hasOpenSession {
            scanner.requestCloseSession()
        }
        scanner.delegate = priorDelegate
    }

    private func fail() {
        finish([])
    }

    private func keysSnapshot(from functionalUnit: ICScannerFunctionalUnit, error: Error?) -> Set<String> {
        if error != nil {
            return []
        }
        let address = unsafeBitCast(functionalUnit, to: Int.self)
        if address == 0 || functionalUnit.type != pendingExpectedUnitType {
            return []
        }
        return Set(PageSizeCatalog.supportedCatalogKeys(for: functionalUnit))
    }

    func device(_ device: ICDevice, didEncounterError error: Error?) {
        fail()
    }

    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        if error != nil {
            fail()
        }
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
        guard !issuedInitialSelectionAfterBecomeReady else { return }
        issuedInitialSelectionAfterBecomeReady = true
        pendingExpectedUnitType = wantsFlatbedOnly ? .flatbed : .documentFeeder
        scanner.requestSelect(pendingExpectedUnitType)
    }

    func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        guard scanner === self.scanner else { return }
        guard !completed else { return }

        if wantsFlatbedOnly {
            let keys = PageSizeCatalog.sortedCatalogKeysIncreasingArea(
                uniqueKeys: keysSnapshot(from: functionalUnit, error: error)
            )
            finish(keys)
            return
        }

        if !awaitingFlatbedAfterFeederRound {
            feederKeysCollected = keysSnapshot(from: functionalUnit, error: error)
            awaitingFlatbedAfterFeederRound = true
            pendingExpectedUnitType = .flatbed
            scanner.requestSelect(.flatbed)
            return
        }

        let flatKeys = keysSnapshot(from: functionalUnit, error: error)
        let merged = feederKeysCollected.union(flatKeys)
        finish(PageSizeCatalog.sortedCatalogKeysIncreasingArea(uniqueKeys: merged))
    }
}

enum PageSizeLister {
    /// Blocking call — must run on main thread (`RunLoop.current` pumps ImageCapture callbacks).
    static func supportedCatalogKeysFromScannerSync(scanner: ICScannerDevice, wantsFlatbed: Bool, timeoutSeconds: TimeInterval = 35) -> [String] {
        let runner = PageSizeListerRunner(scanner: scanner, wantsFlatbed: wantsFlatbed)
        if Thread.isMainThread {
            return runner.runBlocking(timeout: timeoutSeconds)
        }
        var keys: [String] = []
        DispatchQueue.main.sync {
            keys = runner.runBlocking(timeout: timeoutSeconds)
        }
        return keys
    }
}
