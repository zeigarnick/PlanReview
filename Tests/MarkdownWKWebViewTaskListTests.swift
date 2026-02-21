import XCTest
@testable import PlanReview

final class MarkdownWKWebViewTaskListTests: XCTestCase {
    func testUncheckedTaskCheckboxesAreInteractive() {
        let html = "<ul><li>[ ] ship release notes</li></ul>"

        let processed = processTaskListCheckboxHTML(html)

        XCTAssertTrue(processed.contains("<li class=\"task\"><input type=\"checkbox\"> ship release notes"))
        XCTAssertFalse(processed.contains("disabled"))
    }

    func testCheckedTaskCheckboxesAreInteractive() {
        let html = "<ul><li>[x] close regression bug</li></ul>"

        let processed = processTaskListCheckboxHTML(html)

        XCTAssertTrue(processed.contains("<li class=\"task\"><input type=\"checkbox\" checked> close regression bug"))
        XCTAssertFalse(processed.contains("disabled"))
    }
}
