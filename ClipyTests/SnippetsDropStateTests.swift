//
//  SnippetsDropStateTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import XCTest
@testable import Clipy

/// The sidebar's drag feedback bookkeeping.
///
/// The drag itself is a pointer over an `NSTableView` row and cannot be driven from here, but the
/// state it writes is what decides whether an insertion line is drawn — and a line that outlives
/// its drag is the bug this type exists to make unrepresentable.
final class SnippetsDropStateTests: XCTestCase {

    private var state: SnippetsDropState!

    override func setUpWithError() throws {
        try super.setUpWithError()
        state = SnippetsDropState()
    }

    override func tearDownWithError() throws {
        state = nil
        try super.tearDownWithError()
    }

    func testOnlyOneRowIsEverTheTarget() {
        state.hover(.before, over: .folder("a"))
        XCTAssertEqual(state.indicator(for: .folder("a")), .before)

        state.hover(.after, over: .snippet("s"))
        XCTAssertNil(state.indicator(for: .folder("a")), "the previous row must stop drawing a line")
        XCTAssertEqual(state.indicator(for: .snippet("s")), .after)
    }

    func testTheSameRowCanSwapEdges() {
        state.hover(.before, over: .snippet("s"))
        state.hover(.after, over: .snippet("s"))

        XCTAssertEqual(state.indicator(for: .snippet("s")), .after)
    }

    func testClearingLeavesNothingDrawn() {
        state.hover(.into, over: .folder("a"))
        state.clear()

        XCTAssertNil(state.target)
        XCTAssertNil(state.indicator(for: .folder("a")))
        XCTAssertNil(state.dragged)
    }

    func testBeginRecordsThePayloadAndClearsTheLastDrag() {
        state.hover(.before, over: .folder("a"))

        state.begin(.snippet("s"))

        XCTAssertNil(state.indicator(for: .folder("a")), "a new drag starts from a clean slate")
        XCTAssertEqual(state.dragged, .snippet("s"))
    }

    func testIsDraggedMatchesOnlyTheRowInFlight() {
        state.begin(.snippet("s"))

        XCTAssertTrue(state.isDragged(.snippet("s")))
        XCTAssertFalse(state.isDragged(.snippet("other")))
        // Same identifier, different kind: identifiers are UUIDs, but the kinds must not be
        // compared by string alone.
        XCTAssertFalse(state.isDragged(.folder("s")))
    }

    func testNothingIsDraggedBeforeADragStarts() {
        XCTAssertFalse(state.isDragged(.folder("a")))
        XCTAssertFalse(state.isDragged(.snippet("s")))
    }
}
