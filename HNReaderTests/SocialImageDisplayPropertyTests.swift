import XCTest
@testable import HNReader

final class SocialImageDisplayPropertyTests: XCTestCase {
    func testSocialImageDisplay_setsButtonsAndScore() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        var story = Story(id: 3, title: "Full Story", score: 7, descendants: 4, url: "https://example.org", by: nil, time: 0, kids: nil)
        story.socialImageURL = URL(string: "https://example.org/pic.png")
        story.topComment = Comment(id: 20, text: "<p>Great</p>", by: "carol", time: 0, kids: nil, parent: 3, deleted: false, dead: false)

        cell.configure(with: story)

        XCTAssertEqual(cell.scoreButton.title(for: .normal), "7 ▲")
        XCTAssertEqual(cell.commentsButton.configuration?.title, "4 comments")
        XCTAssertFalse(cell.topCommentLabel.isHidden)
        XCTAssertFalse(cell.socialImageView.isHidden)
    }
}
