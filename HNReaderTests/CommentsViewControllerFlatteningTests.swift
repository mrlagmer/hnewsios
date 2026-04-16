import XCTest
@testable import HNReader

final class CommentsViewControllerFlatteningTests: XCTestCase {
    func testFlattenAssignsDepthsInDisplayOrder() {
        let tree = [
            makeNode(
                id: 1,
                parent: 100,
                children: [
                    makeNode(
                        id: 2,
                        parent: 1,
                        children: [
                            makeNode(id: 3, parent: 2)
                        ]
                    ),
                    makeNode(id: 4, parent: 1)
                ]
            )
        ]

        let flattened = CommentTreeFlattener.flatten(tree)

        XCTAssertEqual(flattened.map(\.node.id), [1, 2, 3, 4])
        XCTAssertEqual(flattened.map(\.depth), [0, 1, 2, 1])
    }

    func testFlattenSkipsChildrenOfCollapsedNodes() {
        let tree = [
            makeNode(
                id: 1,
                parent: 100,
                isCollapsed: true,
                children: [
                    makeNode(id: 2, parent: 1),
                    makeNode(id: 3, parent: 1)
                ]
            ),
            makeNode(id: 4, parent: 100)
        ]

        let flattened = CommentTreeFlattener.flatten(tree)

        XCTAssertEqual(flattened.map(\.node.id), [1, 4])
        XCTAssertEqual(flattened.map(\.depth), [0, 0])
    }

    private func makeNode(
        id: Int,
        parent: Int,
        isCollapsed: Bool = false,
        children: [CommentNode] = []
    ) -> CommentNode {
        CommentNode(
            comment: Comment(
                id: id,
                text: "Comment \(id)",
                by: "tester",
                time: id,
                kids: children.map(\.id),
                parent: parent,
                deleted: false,
                dead: false
            ),
            children: children,
            isCollapsed: isCollapsed
        )
    }
}