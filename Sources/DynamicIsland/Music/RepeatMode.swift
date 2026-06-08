/// 循环模式。rawValue 与 Apple Music 的 song repeat 常量名一致（off/all/one），
/// 直接拼进 AppleScript 即为对应常量。
enum RepeatMode: String, Equatable {
    case off, all, one

    /// 按播放器能力切到下一个模式。
    /// supportsOne=true（Apple Music）：off→all→one→off
    /// supportsOne=false（Spotify，无单曲）：off→all→off
    func next(supportsOne: Bool) -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return supportsOne ? .one : .off
        case .one: return .off
        }
    }
}
