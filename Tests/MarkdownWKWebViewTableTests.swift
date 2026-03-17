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

    func testRendersDiscoveryLanesStyleWideTableWithScrollableWrapper() {
        let markdown = """
        ### Discovery Lanes

        | Lane | Scope | Paths/URLs | Constraints/Pitfalls | Reusable Patterns | Unknowns | Recommended Next Reads | Confidence |
        | --- | --- | --- | --- | --- | --- | --- | --- |
        | 1 | Hosting/deploy state | `package.json`<br>`apps/web/vite.config.mts`<br>`wrangler.jsonc` | Web build is still coupled to `@cloudflare/vite-plugin` and Wrangler scripts. | Existing monorepo build wrappers (`pnpm --filter @waterroutes/web`). | Final rollback window duration and operational owner. | `docs/prd/implementation-spec.md` | high |
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<div class=\"table-scroll\"><table>"), "Expected tables to be wrapped for horizontal scrolling.")
        XCTAssertTrue(html.contains("<th>Lane</th>"), "Expected Discovery Lanes header to render as table header.")
        XCTAssertTrue(html.contains("apps/web/vite.config.mts"), "Expected path content to remain visible inside table cells.")
    }
}
