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
}
