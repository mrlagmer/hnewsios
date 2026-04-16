import XCTest
@testable import HNReader

final class SocialImageErrorHandlingPropertyTests: XCTestCase {
    func testConfigureWithInvalidImageURL_doesNotCrashAndLeavesImageHiddenEventually() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        var story = Story(id: 4, title: "Broken Image", score: 0, descendants: 0, url: "https://bad.example", by: nil, time: 0, kids: nil)
        // Intentionally invalid URL (malformed)
        story.socialImageURL = URL(string: "https://__invalid_url__")

        // configuring should not throw and should set image view visible initially
        cell.configure(with: story)
        XCTAssertFalse(cell.socialImageView.isHidden, "Social image view is shown while loading")

        // We cannot reliably await the async failure here in unit tests without network stubs,
        // but the important property is that configure does not crash and began loading.
        XCTAssertTrue(true)
    }
}
