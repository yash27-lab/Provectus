import Foundation
import XCTest
@testable import ProvectusCore

final class DomainRegressionTests: XCTestCase {
    func testPartialCoverage() {
        let link = TraceabilityLink(citationID: "CIT-001", documentName: "source", pageNumber: 1, excerptPreview: "x", excerptID: "x")
        let report = TraceabilityReport(entries: [TraceabilityEntry(sentenceID: UUID(), sentenceText: "a", links: [link]), TraceabilityEntry(sentenceID: UUID(), sentenceText: "b", links: [])])
        XCTAssertEqual(report.coveragePercentage, 50)
    }

    func testEmptyCoverage() {
        XCTAssertEqual(TraceabilityReport(entries: []).coveragePercentage, 0)
    }
}
