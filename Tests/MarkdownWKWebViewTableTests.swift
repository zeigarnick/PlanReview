import XCTest
@testable import PlanReview

final class MarkdownWKWebViewTableTests: XCTestCase {
    func testNormalizesPipeRowsWithoutSeparatorIntoTable() {
        let markdown = """
        ## Execution Quality Policy
        gate | stage | required | trigger | executor | command/method | evidence
        oracle-review | pre-submit | yes | before each plan submission | oracle | compressed `oracle-plan-exit-review` | verdict `approve` or `approve_with_conditions`
        plan registration | post-approval | yes | once user approves plan and draft is finalized/renamed | current-agent | `pnpm plan:register --plan <approved docs/exec-plans/active/... path>` | command success and active map entry
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<table>"), "Expected pseudo-pipe rows to render as a table.")
        XCTAssertTrue(html.contains("<th>gate</th>"), "Expected first row to become table header cells.")
        XCTAssertTrue(html.contains("<td>pre-submit</td>"), "Expected data rows to be rendered as table body cells.")
    }

    func testPreservesValidMarkdownTableRendering() {
        let markdown = """
        | gate | stage | required |
        | --- | --- | --- |
        | oracle-review | pre-submit | yes |
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<table>"), "Expected valid markdown tables to keep rendering.")
        XCTAssertTrue(html.contains("<th>gate</th>"), "Expected header cells to stay intact.")
        XCTAssertTrue(html.contains("<td>yes</td>"), "Expected table body cells to stay intact.")
    }
}
