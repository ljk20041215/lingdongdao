import XCTest
@testable import DynamicIsland

final class NowPlayingParserTests: XCTestCase {
    func testParsesSpotifyPlayingOutput() {
        let raw = "Bohemian Rhapsody\nQueen\n123.45\n354.0\nplaying\nhttps://i.scdn.co/image/abc"
        let info = NowPlayingParser.parse(raw, source: .spotify)
        XCTAssertEqual(info, NowPlayingInfo(
            source: .spotify, title: "Bohemian Rhapsody", artist: "Queen",
            isPlaying: true, positionSec: 123.45, durationSec: 354.0,
            artworkURL: URL(string: "https://i.scdn.co/image/abc")))
    }

    func testParsesPausedState() {
        let raw = "Song\nArtist\n10\n200\npaused\n"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(info?.isPlaying, false)
        XCTAssertNil(info?.artworkURL)
    }

    func testParsesCommaDecimalSeparator() {
        let raw = "Song\nArtist\n12,5\n200,0\nplaying\n"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(info?.positionSec, 12.5)
        XCTAssertEqual(info?.durationSec, 200.0)
    }

    func testEmptyOutputReturnsNil() {
        XCTAssertNil(NowPlayingParser.parse("", source: .music))
    }

    func testMalformedOutputReturnsNil() {
        XCTAssertNil(NowPlayingParser.parse("only\nthree\nlines", source: .spotify))
        XCTAssertNil(NowPlayingParser.parse("t\na\nNaN??\n200\nplaying\n", source: .spotify))
    }

    func testNonFiniteOrNegativeNumbersReturnNil() {
        XCTAssertNil(NowPlayingParser.parse("t\na\nnan\n200\nplaying\n", source: .music))
        XCTAssertNil(NowPlayingParser.parse("t\na\ninf\n200\nplaying\n", source: .music))
        XCTAssertNil(NowPlayingParser.parse("t\na\n-5\n200\nplaying\n", source: .music))
    }

    func testParsesSpotifyShuffleAndRepeat() {
        // Spotify 第 7 行 shuffling、第 8 行 repeating，均为 true/false
        let raw = "S\nA\n10\n200\nplaying\nhttps://x\ntrue\ntrue"
        let info = NowPlayingParser.parse(raw, source: .spotify)
        XCTAssertEqual(info?.shuffle, true)
        XCTAssertEqual(info?.repeatMode, .all)   // Spotify true → all
    }

    func testParsesMusicShuffleAndRepeat() {
        // Music 第 6 行空（封面占位）、第 7 行 shuffle、第 8 行 song repeat
        let raw = "S\nA\n10\n200\nplaying\n\nfalse\none"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(info?.shuffle, false)
        XCTAssertEqual(info?.repeatMode, .one)
    }

    func testMissingShuffleRepeatStaysNil() {
        // 旧的 6 行输出：shuffle/repeat 应为 nil，不影响其余解析
        let raw = "S\nA\n10\n200\nplaying\n"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertNil(info?.shuffle)
        XCTAssertNil(info?.repeatMode)
    }
}
