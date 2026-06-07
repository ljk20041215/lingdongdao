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
}
