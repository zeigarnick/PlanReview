import XCTest
@testable import PlanReview

final class MarkdownWKWebViewImageEmbedTests: XCTestCase {
    func testEmbedsAllCodeWrappedScreenshotsInOrderedList() {
        let markdown = """
        ## Screenshots

        1. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.1-passed.png`
           - Login completed and redirected away from `/login`.
        2. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.2-passed.png`
           - Admin organizations index loaded.
        3. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.3-passed.png`
           - Organization detail shows `Farms` and `People` grouping.
        4. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.4-passed.png`
           - Create farm dialog shows required `Farm name` and address/manual entry fields.
        5. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.5-passed.png`
           - Farm creation via manual address fallback succeeded; routed to farm detail page.
        6. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.6-passed.png`
           - Farm detail tabs visible: `Details`, `Users`, `Headgate connections`, `Acre-feet transactions`.
        7. `/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.7-passed.png`
           - Details page state used to validate no lead-time/cutoff controls are present.
        """

        let view = MarkdownWKWebView(markdown: markdown)
        let html = view.generatedHTMLForTesting()
        let embeddedCount = html.components(separatedBy: "<figure class=\"embedded-image\">").count - 1
        let remainingCodePathCount = html.components(separatedBy: "<code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/").count - 1

        XCTAssertEqual(embeddedCount, 7, "Expected 7 embedded images, got \(embeddedCount).")
        XCTAssertEqual(remainingCodePathCount, 0, "Expected 0 remaining code image paths, got \(remainingCodePathCount).")
    }
}
