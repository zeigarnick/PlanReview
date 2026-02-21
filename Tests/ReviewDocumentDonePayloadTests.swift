import XCTest
@testable import PlanReview

@MainActor
final class ReviewDocumentDonePayloadTests: XCTestCase {
    func testApproveIncludesTaskStatesInDonePayload() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlanReviewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let markdownURL = tempDir.appendingPathComponent("sample.md")
        try "- [ ] first task\n- [x] second task\n".write(to: markdownURL, atomically: true, encoding: .utf8)

        let document = ReviewDocument(filePath: markdownURL.path)
        document.updateTaskStates([
            TaskListState(index: 0, text: "first task", checked: true),
            TaskListState(index: 1, text: "second task", checked: false)
        ])

        document.approve()

        let doneURL = tempDir.appendingPathComponent("sample.done")
        XCTAssertTrue(FileManager.default.fileExists(atPath: doneURL.path))

        let data = try Data(contentsOf: doneURL)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(payload?["status"] as? String, "approved")
        XCTAssertEqual(payload?["commentCount"] as? Int, 0)

        let taskStates = payload?["taskStates"] as? [[String: Any]]
        XCTAssertEqual(taskStates?.count, 2)
        XCTAssertEqual(taskStates?[0]["text"] as? String, "first task")
        XCTAssertEqual(taskStates?[0]["checked"] as? Bool, true)
        XCTAssertEqual(taskStates?[1]["text"] as? String, "second task")
        XCTAssertEqual(taskStates?[1]["checked"] as? Bool, false)
    }
}
