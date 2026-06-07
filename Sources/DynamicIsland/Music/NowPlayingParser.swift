import Foundation

enum NowPlayingParser {
    /// 解析 AppleScript 输出。格式：标题\n歌手\n位置\n时长\n状态\n封面URL
    static func parse(_ raw: String, source: NowPlayingInfo.Source) -> NowPlayingInfo? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lines = raw.components(separatedBy: "\n")
        guard lines.count >= 5 else { return nil }
        guard let position = parseNumber(lines[2]),
              let duration = parseNumber(lines[3]) else { return nil }
        let state = lines[4].trimmingCharacters(in: .whitespaces).lowercased()
        let artworkRaw = lines.count >= 6 ? lines[5].trimmingCharacters(in: .whitespaces) : ""
        return NowPlayingInfo(
            source: source,
            title: lines[0],
            artist: lines[1],
            isPlaying: state == "playing",
            positionSec: position,
            durationSec: duration,
            artworkURL: artworkRaw.isEmpty ? nil : URL(string: artworkRaw))
    }

    /// AppleScript 数字可能用逗号作小数点（地区设置），统一替换后解析
    private static func parseNumber(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
