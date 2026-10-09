import Foundation
import XCTest
@testable import ProvectusCore

final class DomainRegressionTests: XCTestCase {
    func testEmptyCoverage() {
        XCTAssertEqual(TraceabilityReport(entries: []).coveragePercentage, 0)
    }
}
