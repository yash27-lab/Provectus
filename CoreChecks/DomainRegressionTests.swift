import Foundation
import XCTest
@testable import ProvectusCore

final class DomainRegressionTests: XCTestCase {
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
