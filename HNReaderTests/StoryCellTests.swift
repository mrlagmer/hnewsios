import XCTest
@testable import HNReader

final class StoryCellTests: XCTestCase {

    func testRenderHTMLComment_basic() {
        let cell = StoryCell()
        let html = "<p>Hello <a href=\"https://example.com\">link</a></p>"
        let attr = cell.renderHTMLComment(html)
        XCTAssertNotNil(attr)

        // check that a link attribute exists
        var foundLink = false
        attr?.enumerateAttribute(.link, in: NSRange(location: 0, length: attr?.length ?? 0), options: []) { value, _, _ in
            if value != nil { foundLink = true }
        }

        XCTAssertTrue(foundLink, "Expected rendered HTML to contain a link attribute")
    }

    func testConfigure_setsTitleAndButtons_andHandlesMissingImageAndComment() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let story = Story(id: 1, title: "Test Story", score: 5, descendants: 2, url: nil, by: nil, time: 0, kids: nil)

        cell.configure(with: story)

        XCTAssertEqual(cell.titleLabel.text, "Test Story")
        XCTAssertEqual(cell.scoreButton.title(for: .normal), "5 ▲")
        XCTAssertEqual(cell.commentsButton.title(for: .normal), "2 comments")
        XCTAssertTrue(cell.socialImageView.isHidden, "socialImageView should be hidden when there is no socialImageURL")
        XCTAssertTrue(cell.topCommentLabel.isHidden, "topCommentLabel should be hidden when there is no topComment")
    }
}
