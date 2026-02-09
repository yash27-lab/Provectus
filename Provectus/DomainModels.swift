import Foundation
import CryptoKit

struct ImportedSource: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let data: Data
    let contentType: SourceDocumentType
    let originalURL: URL?

    init(fileName: String, data: Data, contentType: SourceDocumentType, originalURL: URL?) {
        self.id = UUID()
        self.fileName = fileName
        self.data = data
        self.contentType = contentType
        self.originalURL = originalURL
    }
}

enum SourceDocumentType: String, CaseIterable, Hashable {
    case pdf
    case docx
    case doc
    case unknown

    init(fileExtension: String?) {
        guard let ext = fileExtension?.lowercased() else {
            self = .unknown
            return
        }
        switch ext {
        case "pdf": self = .pdf
        case "docx": self = .docx
        case "doc": self = .doc
        default: self = .unknown
        }
    }

    init(mimeType: String) {
        switch mimeType.lowercased() {
        case "application/pdf": self = .pdf
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document": self = .docx
        case "application/msword": self = .doc
        default: self = .unknown
        }
    }

    var preferredFileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .doc: return "doc"
        case .unknown: return "dat"
        }
    }
}

struct SourceDocument: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let type: SourceDocumentType
    let importedAt: Date
    var excerpts: [SourceExcerpt]
    var invalidExcerptCount: Int

    init(id: UUID = UUID(), displayName: String, type: SourceDocumentType, importedAt: Date = .now, excerpts: [SourceExcerpt], invalidExcerptCount: Int = 0) {
        self.id = id
        self.displayName = displayName
        self.type = type
        self.importedAt = importedAt
        self.excerpts = excerpts
        self.invalidExcerptCount = invalidExcerptCount
    }
}

struct SourceExcerpt: Identifiable, Hashable {
    let id: String
    let documentID: UUID
    let pageIndex: Int
    let hashToken: String
    let text: String

    init(documentID: UUID, pageIndex: Int, text: String) {
        let normalized = SourceExcerpt.normalized(text: text)
        let hashToken = SourceExcerpt.makeHash(normalizedText: normalized)
        self.id = SourceExcerpt.makeIdentifier(documentID: documentID, pageIndex: pageIndex, hashToken: hashToken)
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.hashToken = hashToken
        self.text = normalized
    }

    var pageNumber: Int { pageIndex + 1 }

    var preview: String {
        if text.count <= 180 { return text }
        let idx = text.index(text.startIndex, offsetBy: 180)
        return text[text.startIndex..<idx] + "…"
    }

    static func makeIdentifier(documentID: UUID, pageIndex: Int, hashToken: String) -> String {
        "EXC-\(documentID.uuidString.prefix(8))-\(pageIndex + 1)-\(hashToken)"
    }

    private static func normalized(text: String) -> String {
        let components = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    private static func makeHash(normalizedText: String) -> String {
        let digest = SHA256.hash(data: Data(normalizedText.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(12)).uppercased()
    }
}

struct Citation: Identifiable, Hashable {
    let id: String
    let excerptID: String
    let documentID: UUID
    let pageIndex: Int
    let ordinal: Int

    init(excerptID: String, documentID: UUID, pageIndex: Int, ordinal: Int) {
        self.ordinal = ordinal
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.excerptID = excerptID
        let tag = String(format: "CIT-%03d", ordinal)
        self.id = tag
    }

    var displayLabel: String { "[\(id)]" }
    var pageNumber: Int { pageIndex + 1 }
}

struct DraftSentence: Identifiable, Hashable {
    let id: UUID
    var text: String
    var citationIDs: [String]
    var order: Int
    var metadata: [String: String]

    init(id: UUID = UUID(), text: String, citationIDs: [String], order: Int, metadata: [String: String] = [:]) {
        self.id = id
        self.text = text
        self.citationIDs = citationIDs
        self.order = order
        self.metadata = metadata
    }

    var isCited: Bool { !citationIDs.isEmpty }
}

struct DraftSection: Identifiable, Hashable {
    let id: UUID
    let templatePath: String
    var title: String
    var level: Int
    var sentences: [DraftSentence]
    var children: [DraftSection]

    init(id: UUID = UUID(), templatePath: String, title: String, level: Int, sentences: [DraftSentence], children: [DraftSection] = []) {
        self.id = id
        self.templatePath = templatePath
        self.title = title
        self.level = level
        self.sentences = sentences
        self.children = children
    }

    var allSentences: [DraftSentence] {
        sentences + children.flatMap { $0.allSentences }
    }

    var flattenedSections: [DraftSection] {
        [self] + children.flatMap { $0.flattenedSections }
    }
}

struct OutputTemplate: Identifiable, Hashable {
    struct Section: Identifiable, Hashable {
        let id: String
        let title: String
        let level: Int
        let templatePath: String
        var children: [Section]

        init(id: String, title: String, level: Int, templatePath: String, children: [Section] = []) {
            self.id = id
            self.title = title
            self.level = level
            self.templatePath = templatePath
            self.children = children
        }

        var flattened: [Section] {
            [self] + children.flatMap { $0.flattened }
        }

        func headingPaths(currentPath: [String] = []) -> [String] {
            let path = currentPath + [title]
            let childPaths = children.flatMap { $0.headingPaths(currentPath: path) }
            return [path.joined(separator: " > ")] + childPaths
        }
    }

    let id: OutputTemplateID
    let displayName: String
    let description: String
    let defaultFileName: String
    let sections: [Section]

    var flattenedSections: [Section] {
        sections.flatMap { $0.flattened }
    }

    var expectedHeadingPaths: [String] {
        sections.flatMap { $0.headingPaths() }
    }
}

enum OutputTemplateID: String, CaseIterable, Identifiable {
    case ctdModule2
    case ctdModule2ClinicalSummary
    case csrSafetySummary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ctdModule2: return "CTD Module 2 Summary"
        case .ctdModule2ClinicalSummary: return "CTD Module 2.7 Clinical Summary"
        case .csrSafetySummary: return "CSR Safety Summary"
        }
    }
}

struct TraceabilityLink: Identifiable, Hashable {
    let id: String
    let citationID: String
    let documentName: String
    let pageNumber: Int
    let excerptPreview: String
    let excerptID: String

    init(citationID: String, documentName: String, pageNumber: Int, excerptPreview: String, excerptID: String) {
        self.citationID = citationID
        self.documentName = documentName
        self.pageNumber = pageNumber
        self.excerptPreview = excerptPreview
        self.excerptID = excerptID
        self.id = "\(citationID)-\(excerptID)"
    }
}

struct TraceabilityEntry: Identifiable, Hashable {
    let id: UUID
    let sentenceText: String
    let links: [TraceabilityLink]

    init(sentenceID: UUID, sentenceText: String, links: [TraceabilityLink]) {
        self.id = sentenceID
        self.sentenceText = sentenceText
        self.links = links
    }
}

struct TraceabilityReport: Hashable {
    var entries: [TraceabilityEntry]

    var coverageFraction: Double {
        guard !entries.isEmpty else { return 0 }
        let citedCount = entries.filter { !$0.links.isEmpty }.count
        return Double(citedCount) / Double(entries.count)
    }

    var coveragePercentage: Double {
        coverageFraction * 100.0
    }
}

enum RegulatoryLintSeverity: String, CaseIterable, Hashable {
    case info
    case warning
    case error
}

enum RegulatoryLintKind: String, Hashable {
    case headingHierarchy
    case missingCitation
    case numericWithoutCitation
    case undefinedAcronym
    case brokenCrossReference
    case badSourceCapture
}

struct RegulatoryLint: Identifiable, Hashable {
    let id: UUID
    let severity: RegulatoryLintSeverity
    let kind: RegulatoryLintKind
    let message: String
    let hint: String?
    let sectionID: UUID?
    let sentenceID: UUID?

    init(id: UUID = UUID(), severity: RegulatoryLintSeverity, kind: RegulatoryLintKind, message: String, hint: String? = nil, sectionID: UUID? = nil, sentenceID: UUID? = nil) {
        self.id = id
        self.severity = severity
        self.kind = kind
        self.message = message
        self.hint = hint
        self.sectionID = sectionID
        self.sentenceID = sentenceID
    }
}

struct DraftDocument: Hashable {
    let template: OutputTemplate
    let sections: [DraftSection]
    let citationsByID: [String: Citation]
    let sourceDocuments: [SourceDocument]
    let generatedAt: Date
    let traceability: TraceabilityReport
    let lints: [RegulatoryLint]

    var allSections: [DraftSection] {
        sections.flatMap { $0.flattenedSections }
    }

    var allSentences: [DraftSentence] {
        sections.flatMap { $0.allSentences }
    }
}

struct DocxExportConfiguration: Hashable {
    var includeTableOfContents: Bool
    var includeTraceabilityTable: Bool

    init(includeTableOfContents: Bool = true, includeTraceabilityTable: Bool = true) {
        self.includeTableOfContents = includeTableOfContents
        self.includeTraceabilityTable = includeTraceabilityTable
    }
}

struct DocxExportArtifact: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let data: Data

    init(id: UUID = UUID(), fileName: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.data = data
    }
}
