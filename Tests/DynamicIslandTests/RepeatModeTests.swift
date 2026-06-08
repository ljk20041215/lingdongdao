import XCTest
@testable import DynamicIsland

final class RepeatModeTests: XCTestCase {
    func testMusicCyclesThreeStates() {
        XCTAssertEqual(RepeatMode.off.next(supportsOne: true), .all)
        XCTAssertEqual(RepeatMode.all.next(supportsOne: true), .one)
        XCTAssertEqual(RepeatMode.one.next(supportsOne: true), .off)
    }
    func testSpotifySkipsOne() {
        XCTAssertEqual(RepeatMode.off.next(supportsOne: false), .all)
        XCTAssertEqual(RepeatMode.all.next(supportsOne: false), .off)
    }
}
