import XCTest
@testable import HNReader

final class StoryDisplayWithSocialImagesPropertyTests: XCTestCase {
    func testStoryDisplaysSocialImage_whenURLPresent() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        var story = Story(id: 2, title: "Image Story", score: 10, descendants: 0, url: "https://example.com", by: nil, time: 0, kids: nil)
        story.socialImageURL = URL(string: "https://example.com/image.png")

        cell.configure(with: story)

        XCTAssertFalse(cell.socialImageView.isHidden, "Social image view should be visible when a socialImageURL is provided")
    }
}
