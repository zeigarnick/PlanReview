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

    func testRendersExecutionPolicyTableWithInlineCodeCells() {
        let markdown = """
        ## Execution Quality Policy

        | gate | stage | required | trigger | executor | command/method | evidence |
        | --- | --- | --- | --- | --- | --- | --- |
        | notification-email-contract-tests | pre-merge | yes | any change to email notification copy/composition | implementer/general | `pnpm test:convex:run -- convex/waterroutesNotifications.test.ts` | passing targeted test output with salutation + legacy-guidance assertions |
        | baseline-quality | pre-merge | yes | always | implementer/general | `pnpm lint && pnpm test:run && pnpm build` | passing outputs or documented unrelated blockers |
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<div class=\"table-scroll\"><table>"), "Expected execution policy table to be wrapped for scrolling.")
        XCTAssertTrue(html.contains("<th>gate</th>"), "Expected table header cells to render.")
        XCTAssertTrue(html.contains("implementer/general"), "Expected slash-containing executor values to render inside table cells.")
    }

    func testInlineCodeWithStrongTagDoesNotLeakBoldToFollowingSections() {
        let markdown = """
        - Add bold emphasis to key headline tokens and keep the cap (<= 3 `<strong>` spans).
        - Mirror the same salutation behavior in static fallback HTML output.

        ## Tests
        - Ensure formatting remains stable.
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertFalse(html.contains("<code><strong>"), "Inline code should escape raw HTML tags instead of creating live tags.")
        XCTAssertTrue(html.contains("<code>&amp;lt;strong&amp;gt;</code>"), "Inline code should render literal tag text safely encoded.")
        XCTAssertTrue(html.contains("<h2>Tests</h2>"), "Heading after inline code should render as a heading, not be swallowed by leaked bold tags.")
    }
}
