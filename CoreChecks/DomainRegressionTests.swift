import Foundation
import XCTest
@testable import ProvectusCore

final class DomainRegressionTests: XCTestCase {
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
