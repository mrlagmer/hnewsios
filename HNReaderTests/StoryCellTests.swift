import XCTest
@testable import HNReader

final class StoryCellTests: XCTestCase {

    func testRenderHTMLComment_basic() {
        let cell = StoryCell()
        let html = "<p>Hello <a href=\"https://example.com\">link</a></p>"
        let attr = cell.renderHTMLComment(html)
        XCTAssertNotNil(attr)
        XCTAssertEqual(attr?.string, "Hello link")
    }

    func testRenderHTMLComment_decodesNumericEntitiesAndPreservesParagraphBreaks() {
        let cell = StoryCell()
        let html = "<p>https:&#x2F;&#x2F;github.com&#x2F;repo and you&#x27;re here</p><p>Second line</p>"

        let attr = cell.renderHTMLComment(html)

        XCTAssertEqual(attr?.string, "https://github.com/repo and you're here\n\nSecond line")
    }

    func testCommentCellRenderHTMLText_decodesHexEntities() {
        let cell = CommentCell(style: .default, reuseIdentifier: CommentCell.reuseIdentifier)
        let html = "<p>https:&#x2F;&#x2F;floss.social&#x2F;@hko&#x2F;116459621169318785 and GnuPG&#x27;s</p>"

        let attr = cell.renderHTMLText(html)

        XCTAssertEqual(attr?.string, "https://floss.social/@hko/116459621169318785 and GnuPG's")
    }

    func testConfigure_setsTitleAndButtons_andHandlesMissingImageAndComment() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let story = Story(id: 1, title: "Test Story", score: 5, descendants: 2, url: nil, by: nil, time: 0, kids: nil)

        cell.configure(with: story)

        XCTAssertEqual(cell.titleLabel.text, "Test Story")
        XCTAssertEqual(cell.scoreButton.title(for: .normal), "5 ▲")
        XCTAssertEqual(cell.commentsButton.configuration?.title, "2 comments")
        XCTAssertTrue(cell.socialImageView.isHidden, "socialImageView should be hidden when there is no socialImageURL")
        XCTAssertTrue(cell.topCommentLabel.isHidden, "topCommentLabel should be hidden when there is no topComment")
    }

    func testConfigure_stylesCommentsButtonAsInlineLink() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let story = Story(id: 1, title: "Test Story", score: 5, descendants: 19, url: nil, by: nil, time: 0, kids: nil)

        cell.configure(with: story)

        XCTAssertEqual(cell.commentsButton.configuration?.title, "19 comments")
        XCTAssertEqual(cell.commentsButton.configuration?.contentInsets.top, 4)
        XCTAssertEqual(cell.commentsButton.configuration?.contentInsets.leading, 0)
        XCTAssertEqual(cell.commentsButton.configuration?.imagePadding, 4)
        XCTAssertEqual(cell.commentsButton.backgroundColor, .clear)
    }

    func testConfigure_setsTopCommentAttributedTextImmediately() {
        let cell = StoryCell(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let topComment = Comment(id: 10, text: "<p>Visible on first layout</p>", by: "alice", time: 0, kids: nil, parent: 1, deleted: false, dead: false)
        var story = Story(id: 1, title: "Test Story", score: 5, descendants: 2, url: nil, by: nil, time: 0, kids: nil)
        story.topComment = topComment

        cell.configure(with: story)

        XCTAssertFalse(cell.topCommentLabel.isHidden)
        XCTAssertEqual(cell.topCommentLabel.attributedText?.string.trimmingCharacters(in: .whitespacesAndNewlines), "Visible on first layout")
    }
}
