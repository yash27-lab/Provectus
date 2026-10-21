import Foundation
// Dependency-free checks run with the production model sources in the same module.
private func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T) {
    precondition(actual == expected, "Expected \(expected), got \(actual)")
}
private func XCTAssertNotEqual<T: Equatable>(_ actual: T, _ expected: T) {
    precondition(actual != expected, "Values unexpectedly equal")
}
private func XCTAssertFalse(_ actual: Bool) { precondition(!actual) }

@main
final class DomainRegressionTests {
    static func main() {
        let checks = DomainRegressionTests()
        checks.testNestedSentenceOrder()
        checks.testLeafSection()
        checks.testSentenceMetadata()
        checks.testLinkCitationIdentity()
        checks.testLinkExcerptIdentity()
        checks.testTraceabilitySentenceIdentity()
        checks.testMultipleLinksCoverage()
        checks.testFullCoverage()
        checks.testUncitedCoverage()
        checks.testExplicitExportSections()
        checks.testDefaultExportSections()
        checks.testCitationPresence()
        checks.testEmptyExcerpt()
        checks.testPreviewExactBoundary()
        checks.testPreferredExtensionRoundtrip()
        checks.testExtensionUnknown()
        checks.testExtensionDoc()
        checks.testExtensionWhitespace()
        checks.testEmptyMime()
        checks.testMimeUnknownParameters()
        checks.testMimeLegacyDoc()
        checks.testMimeDocx()
        checks.testMimeCase()
        checks.testMimeWhitespace()
        checks.testMimeParameters()
        checks.testEmptyCoverage()
        checks.testPartialCoverage()
        checks.testWhitespaceNormalization()
        checks.testNormalizedHashStability()
        checks.testPageIdentity()
        checks.testUnicodePreview()
        checks.testShortPreview()
        checks.testCitationLabels()
        checks.testCitationOrdinalBeyondPadding()
        checks.testSourceExtensionCase()
        checks.testUnsupportedSourceType()
        checks.testNestedHeadingPaths()
        checks.testTemplateCompleteness()
        print("29 core-model regression checks passed")
    }
    func testMimeParameters() {
        XCTAssertEqual(SourceDocumentType(mimeType: "application/pdf; charset=binary"), .pdf)
    }

    func testMimeWhitespace() {
        XCTAssertEqual(SourceDocumentType(mimeType: "  application/pdf\n"), .pdf)
    }

    func testMimeCase() {
        XCTAssertEqual(SourceDocumentType(mimeType: "APPLICATION/PDF"), .pdf)
    }

    func testMimeDocx() {
        XCTAssertEqual(SourceDocumentType(mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document; version=1"), .docx)
    }

    func testMimeLegacyDoc() {
        XCTAssertEqual(SourceDocumentType(mimeType: "application/msword; version=1"), .doc)
    }

    func testMimeUnknownParameters() {
        XCTAssertEqual(SourceDocumentType(mimeType: "text/html; charset=utf-8"), .unknown)
    }

    func testEmptyMime() {
        XCTAssertEqual(SourceDocumentType(mimeType: ""), .unknown)
        XCTAssertEqual(SourceDocumentType(mimeType: "; charset=x"), .unknown)
    }

    func testExtensionWhitespace() {
        XCTAssertEqual(SourceDocumentType(fileExtension: " \nPDF\t"), .pdf)
    }

    func testExtensionDoc() {
        XCTAssertEqual(SourceDocumentType(fileExtension: " DOC "), .doc)
    }

    func testExtensionUnknown() {
        XCTAssertEqual(SourceDocumentType(fileExtension: " "), .unknown)
        XCTAssertEqual(SourceDocumentType(fileExtension: "pdf.exe"), .unknown)
    }

    func testPreferredExtensionRoundtrip() {
        for type in [SourceDocumentType.pdf, .docx, .doc] {
            XCTAssertEqual(SourceDocumentType(fileExtension: type.preferredFileExtension), type)
        }
    }

    func testPreviewExactBoundary() {
        let text = String(repeating: "a", count: 180)
        XCTAssertEqual(SourceExcerpt(documentID: UUID(), pageIndex: 0, text: text).preview, text)
    }

    func testEmptyExcerpt() {
        let e = SourceExcerpt(documentID: UUID(), pageIndex: 0, text: " \n\t")
        XCTAssertEqual(e.text, "")
        XCTAssertEqual(e.preview, "")
    }

    func testCitationPresence() {
        var sentence = DraftSentence(text: "claim", citationIDs: [], order: 0)
        XCTAssertEqual(sentence.isCited, false)
        sentence.citationIDs = ["CIT-001"]
        XCTAssertEqual(sentence.isCited, true)
    }

    func testDefaultExportSections() {
        let config = DocxExportConfiguration()
        XCTAssertEqual(config.includeTableOfContents, true)
        XCTAssertEqual(config.includeTraceabilityTable, true)
    }

    func testExplicitExportSections() {
        let config = DocxExportConfiguration(includeTableOfContents: false, includeTraceabilityTable: false)
        XCTAssertEqual(config.includeTableOfContents, false)
        XCTAssertEqual(config.includeTraceabilityTable, false)
    }

    func testUncitedCoverage() {
        let report = TraceabilityReport(entries: [TraceabilityEntry(sentenceID: UUID(), sentenceText: "claim", links: [])])
        XCTAssertEqual(report.coverageFraction, 0)
    }

    func testFullCoverage() {
        let link = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "text", excerptID: "e")
        let report = TraceabilityReport(entries: [TraceabilityEntry(sentenceID: UUID(), sentenceText: "claim", links: [link])])
        XCTAssertEqual(report.coveragePercentage, 100)
    }

    func testMultipleLinksCoverage() {
        let link = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "text", excerptID: "e")
        let report = TraceabilityReport(entries: [TraceabilityEntry(sentenceID: UUID(), sentenceText: "claim", links: [link, link])])
        XCTAssertEqual(report.coverageFraction, 1)
    }

    func testTraceabilitySentenceIdentity() {
        let id = UUID()
        let entry = TraceabilityEntry(sentenceID: id, sentenceText: "claim", links: [])
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.sentenceText, "claim")
    }

    func testLinkExcerptIdentity() {
        let a = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "x", excerptID: "a")
        let b = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "x", excerptID: "b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testLinkCitationIdentity() {
        let a = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "x", excerptID: "a")
        let b = TraceabilityLink(citationID: "CIT-002", documentName: "source", pageNumber: 1, excerptPreview: "x", excerptID: "a")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testSentenceMetadata() {
        let sentence = DraftSentence(text: "claim", citationIDs: [], order: 3, metadata: ["review": "pending"])
        XCTAssertEqual(sentence.metadata["review"], "pending")
        XCTAssertEqual(sentence.order, 3)
    }

    func testLeafSection() {
        let section = DraftSection(templatePath: "1", title: "Leaf", level: 1, sentences: [])
        XCTAssertEqual(section.flattenedSections.map { $0.id }, [section.id])
        XCTAssertEqual(section.allSentences.count, 0)
    }

    func testNestedSentenceOrder() {
        let a = DraftSentence(text: "parent", citationIDs: [], order: 0)
        let b = DraftSentence(text: "child", citationIDs: [], order: 1)
        let child = DraftSection(templatePath: "1.1", title: "Child", level: 2, sentences: [b])
        let root = DraftSection(templatePath: "1", title: "Root", level: 1, sentences: [a], children: [child])
        XCTAssertEqual(root.allSentences.map { $0.text }, ["parent", "child"])
    }

    func testTemplateCompleteness() {
        for id in OutputTemplateID.allCases {
            let template = OutputTemplateLibrary.shared.template(for: id)
            XCTAssertEqual(template.id, id)
            XCTAssertFalse(template.flattenedSections.isEmpty)
            XCTAssertEqual(Set(template.flattenedSections.map { $0.id }).count, template.flattenedSections.count)
        }
    }

    func testNestedHeadingPaths() {
        let child = OutputTemplate.Section(id: "c", title: "Child", level: 2, templatePath: "c")
        let parent = OutputTemplate.Section(id: "p", title: "Parent", level: 1, templatePath: "p", children: [child])
        XCTAssertEqual(parent.headingPaths(), ["Parent", "Parent > Child"])
        XCTAssertEqual(parent.flattened.map { $0.id }, ["p", "c"])
    }

    func testUnsupportedSourceType() {
        XCTAssertEqual(SourceDocumentType(fileExtension: "html"), .unknown)
        XCTAssertEqual(SourceDocumentType(mimeType: "text/html"), .unknown)
        XCTAssertEqual(SourceDocumentType.unknown.preferredFileExtension, "dat")
    }

    func testSourceExtensionCase() {
        XCTAssertEqual(SourceDocumentType(fileExtension: "PDF"), .pdf)
        XCTAssertEqual(SourceDocumentType(fileExtension: "DoCx"), .docx)
        XCTAssertEqual(SourceDocumentType(fileExtension: nil), .unknown)
    }

    func testCitationOrdinalBeyondPadding() {
        let c = Citation(excerptID: "x", documentID: UUID(), pageIndex: 0, ordinal: 1000)
        XCTAssertEqual(c.id, "CIT-1000")
    }

    func testCitationLabels() {
        let c = Citation(excerptID: "x", documentID: UUID(), pageIndex: 2, ordinal: 7)
        XCTAssertEqual(c.displayLabel, "[CIT-007]")
        XCTAssertEqual(c.pageNumber, 3)
    }

    func testShortPreview() {
        let e = SourceExcerpt(documentID: UUID(), pageIndex: 0, text: "short excerpt")
        XCTAssertEqual(e.preview, e.text)
    }

    func testUnicodePreview() {
        let e = SourceExcerpt(documentID: UUID(), pageIndex: 0, text: String(repeating: "🧬", count: 181))
        XCTAssertEqual(e.preview, String(repeating: "🧬", count: 180) + "…")
    }

    func testPageIdentity() {
        let id = UUID()
        let a = SourceExcerpt(documentID: id, pageIndex: 0, text: "same")
        let b = SourceExcerpt(documentID: id, pageIndex: 1, text: "same")
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(b.pageNumber, 2)
    }

    func testNormalizedHashStability() {
        let id = UUID()
        let a = SourceExcerpt(documentID: id, pageIndex: 0, text: "one two")
        let b = SourceExcerpt(documentID: id, pageIndex: 0, text: " one\n two ")
        XCTAssertEqual(a.id, b.id)
    }

    func testWhitespaceNormalization() {
        let e = SourceExcerpt(documentID: UUID(), pageIndex: 0, text: "  one\n\t two  ")
        XCTAssertEqual(e.text, "one two")
    }

    func testPartialCoverage() {
        let link = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "x", excerptID: "x")
        let report = TraceabilityReport(entries: [TraceabilityEntry(sentenceID: UUID(), sentenceText: "a", links: [link]), TraceabilityEntry(sentenceID: UUID(), sentenceText: "b", links: [])])
        XCTAssertEqual(report.coveragePercentage, 50)
    }

    func testEmptyCoverage() {
        XCTAssertEqual(TraceabilityReport(entries: []).coveragePercentage, 0)
    }
}
