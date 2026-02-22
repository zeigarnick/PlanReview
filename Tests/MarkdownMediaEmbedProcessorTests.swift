import XCTest
@testable import PlanReview

final class MarkdownMediaEmbedProcessorTests: XCTestCase {
    func testConvertsStandaloneWebMMarkdownLinkToInlineVideo() {
        let html = #"<p><a href="./artifacts/demo.webm">Demo Recording</a></p>"#

        let processed = MarkdownMediaEmbedProcessor.processEmbeds(in: html)

        XCTAssertTrue(processed.contains("<figure class=\"embedded-video\">"))
        XCTAssertTrue(processed.contains("<video controls preload=\"metadata\" playsinline>"))
        XCTAssertTrue(processed.contains("<source src=\"./artifacts/demo.webm\" type=\"video/webm\">"))
        XCTAssertTrue(processed.contains("<figcaption>Demo Recording</figcaption>"))
    }

    func testLeavesNonVideoLinksUnchanged() {
        let html = #"<p><a href="https://example.com/spec">Spec</a></p>"#

        let processed = MarkdownMediaEmbedProcessor.processEmbeds(in: html)

        XCTAssertEqual(processed, html)
    }

    func testConvertsStandaloneWebMImageToInlineVideo() {
        let html = #"<p><img src="./artifacts/demo.webm" alt="Capture" /></p>"#

        let processed = MarkdownMediaEmbedProcessor.processEmbeds(in: html)

        XCTAssertTrue(processed.contains("<source src=\"./artifacts/demo.webm\" type=\"video/webm\">"))
        XCTAssertTrue(processed.contains("<figcaption>Capture</figcaption>"))
    }

    func testConvertsStandaloneCodeWrappedImagePathToInlineImage() {
        let html = #"<p><code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.1-passed.png</code></p>"#

        let processed = MarkdownMediaEmbedProcessor.processEmbeds(in: html)

        XCTAssertTrue(processed.contains("<figure class=\"embedded-image\">"))
        XCTAssertTrue(processed.contains("<img src=\"/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.1-passed.png\""))
        XCTAssertFalse(processed.contains("loading=\"lazy\""))
    }

    func testConvertsListItemCodeWrappedImagePathToInlineImage() {
        let html = #"<ol><li><code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.2-passed.png</code><ul><li>Rendered screenshot</li></ul></li></ol>"#

        let processed = MarkdownMediaEmbedProcessor.processEmbeds(in: html)

        XCTAssertTrue(processed.contains("<figure class=\"embedded-image\">"))
        XCTAssertTrue(processed.contains("<img src=\"/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.2-passed.png\""))
        XCTAssertTrue(processed.contains("<ul><li>Rendered screenshot</li></ul>"))
    }

    func testConvertsAllScreenshotPathsInOrderedList() {
        let html = #"""
<ol>
<li><code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.1-passed.png</code><ul><li>first</li></ul></li>
<li><code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.2-passed.png</code><ul><li>second</li></ul></li>
<li><code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/A1.3-passed.png</code><ul><li>third</li></ul></li>
</ol>
"""#

        let processed = MarkdownMediaEmbedProcessor.processEmbeds(in: html)
        let embeddedCount = processed.components(separatedBy: "<figure class=\"embedded-image\">").count - 1

        XCTAssertEqual(embeddedCount, 3)
        XCTAssertFalse(processed.contains("<code>/Users/nick/Projects/work/Waterroutes/e2e/artifacts/2026-02-21-2341/screenshots/"))
    }
}
