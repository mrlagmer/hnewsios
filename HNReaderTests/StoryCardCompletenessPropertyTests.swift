import XCTest
@testable import HNReader

final class StoryCardCompletenessPropertyTests: XCTestCase {
    func testStoryCardCompleteness_initialRender() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        let topComment = Comment(id: 10, text: "<p>Nice story</p>", by: "alice", time: 0, kids: nil, parent: 1, deleted: false, dead: false)
        var story = Story(id: 1, title: "Example Title", score: 42, descendants: 3, url: nil, by: "bob", time: 0, kids: nil)
        story.topComment = topComment

        cell.configure(with: story)

        XCTAssertEqual(cell.titleLabel.text, "Example Title")
        XCTAssertFalse(cell.topCommentLabel.isHidden, "Top comment should be shown when present")
        XCTAssertTrue(cell.socialImageView.isHidden, "Social image should be hidden when no socialImageURL")
    }
}
