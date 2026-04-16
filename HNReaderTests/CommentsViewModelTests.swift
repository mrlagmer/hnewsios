import XCTest
@testable import HNReader

final class CommentsViewModelTests: XCTestCase {
    func test_preloadedComments_buildsTree() async {
        let storyId = 100

        let root = Comment(id: 1, text: "Root", by: "alice", time: 1000, kids: [2], parent: storyId, deleted: false, dead: false)
        let child = Comment(id: 2, text: "Child", by: "bob", time: 1001, kids: nil, parent: 1, deleted: false, dead: false)

        let vm = CommentsViewModel(storyId: storyId, preloadedComments: [root, child])

        await vm.loadInitialComments()

        XCTAssertEqual(vm.commentTree.count, 1)
        let first = vm.commentTree.first!
        XCTAssertEqual(first.children.count, 1)
        XCTAssertEqual(first.children.first?.comment.id, 2)
    }

    func test_toggleCollapse_togglesFlag() async {
        let storyId = 200
        let root = Comment(id: 10, text: "Root", by: "alice", time: 2000, kids: [11], parent: storyId, deleted: false, dead: false)
        let child = Comment(id: 11, text: "Child", by: "bob", time: 2001, kids: nil, parent: 10, deleted: false, dead: false)

        let vm = CommentsViewModel(storyId: storyId, preloadedComments: [root, child])
        await vm.loadInitialComments()

        XCTAssertFalse(vm.commentTree[0].isCollapsed)
        vm.toggleCollapse(nodeId: 10)
        XCTAssertTrue(vm.commentTree[0].isCollapsed)
    }
}
