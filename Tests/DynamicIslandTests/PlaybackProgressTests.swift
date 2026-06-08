import XCTest
@testable import DynamicIsland

final class PlaybackProgressTests: XCTestCase {
    private func info(playing: Bool, position: Double, duration: Double = 200) -> NowPlayingInfo {
        NowPlayingInfo(source: .spotify, title: "t", artist: "a",
                       isPlaying: playing, positionSec: position, durationSec: duration)
    }

    func testPlayingAdvancesByElapsed() {
        let p = PlaybackProgress.position(base: info(playing: true, position: 10), elapsed: 1.5)
        XCTAssertEqual(p, 11.5, accuracy: 0.0001)
    }

    func testPausedHoldsPosition() {
        let p = PlaybackProgress.position(base: info(playing: false, position: 10), elapsed: 5)
        XCTAssertEqual(p, 10, accuracy: 0.0001)
    }

    func testClampsAtDuration() {
        // 临近结尾时本地推进越界，应停在 100% 等下次轮询纠正，而不是溢出
        let p = PlaybackProgress.position(base: info(playing: true, position: 199, duration: 200), elapsed: 10)
        XCTAssertEqual(p, 200, accuracy: 0.0001)
    }

    func testNegativeElapsedDoesNotRewind() {
        // 时钟回拨/抖动不得让进度倒退到同步点之前
        let p = PlaybackProgress.position(base: info(playing: true, position: 10), elapsed: -3)
        XCTAssertEqual(p, 10, accuracy: 0.0001)
    }

    func testNeverNegative() {
        let p = PlaybackProgress.position(base: info(playing: false, position: -5), elapsed: 0)
        XCTAssertEqual(p, 0, accuracy: 0.0001)
    }
}
