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
        XCTAssertTrue(
            html.contains("<code>&amp;lt;strong&amp;gt;</code>") || html.contains("<code>&lt;strong&gt;</code>"),
            "Inline code should render literal tag text safely encoded."
        )
        XCTAssertTrue(html.contains("<h2>Tests</h2>"), "Heading after inline code should render as a heading, not be swallowed by leaked bold tags.")
    }

    func testSectionsAfterStrongCodeAndTableRenderAsHeadings() {
        let markdown = """
        - Add bold emphasis to key headline tokens (report type/date) where readability benefits, without changing table data semantics, and keep the global max-emphasis cap (<= 3 `<strong>` spans).
        - Mirror the same salutation behavior in static fallback HTML output so runtime fallback does not regress tone.

        ### Tests
        - Add assertions for forecast template salutation output.

        ## Execution Quality Policy
        | gate | stage | required |
        | --- | --- | --- |
        | baseline-quality | pre-merge | yes |

        ## Risks / Out of Scope
        - Risk: bold-emphasis rules can over-highlight text.
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<h3>Tests</h3>"), "Expected Tests section heading to render after the strong-code bullet line.")
        XCTAssertTrue(html.contains("<h2>Execution Quality Policy</h2>"), "Expected Execution Quality Policy heading to render as h2.")
        XCTAssertTrue(html.contains("<div class=\"table-scroll\"><table>"), "Expected execution policy table to render in scroll wrapper.")
        XCTAssertTrue(html.contains("<h2>Risks / Out of Scope</h2>"), "Expected Risks / Out of Scope heading to render as h2.")
        XCTAssertFalse(html.contains("## Execution Quality Policy</li>"), "Execution heading should not be swallowed inside a list item.")
        XCTAssertFalse(html.contains("## Risks / Out of Scope</li>"), "Risks heading should not be swallowed inside a list item.")
    }

    func testHierarchySemanticsLineWithInlineBreakPreservesFollowingSections() {
        let markdown = """
        #### [MODIFY] [convex/schema.ts](convex/schema.ts)
        - Add optional `displayOrder` (or `sortOrder`) to wrRides, wrLaterals, and wrHeadgates, with hierarchical semantics:<br>rides ordered per org, laterals ordered per `rideId`, headgates ordered per `lateralId`.
        - Keep existing name indexes for search/backward compatibility.

        #### [MODIFY] [convex/admin/_organizationAdmin/hierarchy.ts](convex/admin/_organizationAdmin/hierarchy.ts)
        - Add list queries/mutations to read/update canonical sequence for rides/laterals.
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<h4>[MODIFY] <a href=\"convex/schema.ts\">convex/schema.ts</a></h4>"), "Expected first modify section heading to render as h4.")
        XCTAssertTrue(html.contains("rides ordered per org, laterals ordered per <code>rideId</code>, headgates ordered per <code>lateralId</code>"), "Expected hierarchy semantics continuation text to remain in the list item body.")
        XCTAssertTrue(html.contains("<code>rideId</code>"), "Expected inline code after <br> to render as code.")
        XCTAssertTrue(html.contains("<h4>[MODIFY] <a href=\"convex/admin/_organizationAdmin/hierarchy.ts\">convex/admin/_organizationAdmin/hierarchy.ts</a></h4>"), "Expected following modify section heading to render as h4 rather than being swallowed.")
        XCTAssertTrue(html.contains("<li>Keep existing name indexes for search/backward compatibility.</li>"), "Expected second bullet to render as a separate list item.")
        XCTAssertFalse(html.contains("#### [MODIFY] [convex/admin/_organizationAdmin/hierarchy.ts]"), "Expected following markdown heading to be parsed, not rendered as raw text.")
    }

    func testLessThanComparatorInParensDoesNotSwallowFollowingMarkdown() {
        let markdown = """
        #### [MODIFY] [convex/admin/_organizationAdmin/runningOrderDispatch.ts](convex/admin/_organizationAdmin/runningOrderDispatch.ts)
        - Added intent-aware enqueue paths so manual and scheduled sends share one run engine while keeping scheduled enqueue internal-only.
        - Implemented scheduled singleton dedupe, atomic guard order, cooldown re-enqueue for `partial|failed_terminal`, and a 24h rearm cap (<4 runs).
        - Added lock-backed scheduled enqueue and truthful `lock_contended` state to prevent misleading `active_guard` outcomes under contention.

        #### [MODIFY] [convex/admin/_organizationAdmin/reports.ts](convex/admin/_organizationAdmin/reports.ts)
        - Routed manual report enqueue calls through explicit `dispatchIntent: "manual_report"` to prevent behavior drift.
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()

        XCTAssertTrue(html.contains("<code>partial|failed_terminal</code>"), "Expected inline code with pipe content to render safely.")
        XCTAssertTrue(html.contains("24h rearm cap (&lt;4 runs)."), "Expected less-than comparator in parentheses to be HTML-escaped for safe WebKit parsing.")
        XCTAssertTrue(html.contains("<li>Added lock-backed scheduled enqueue and truthful <code>lock_contended</code> state"), "Expected bullet after comparator line to render as a list item.")
        XCTAssertTrue(html.contains("<h4>[MODIFY] <a href=\"convex/admin/_organizationAdmin/reports.ts\">convex/admin/_organizationAdmin/reports.ts</a></h4>"), "Expected following section heading to render as h4.")
        XCTAssertFalse(html.contains("#### [MODIFY] [convex/admin/_organizationAdmin/reports.ts]"), "Expected following markdown heading to be parsed, not emitted as raw markdown text.")
    }
}
