import Foundation

/// 当前展开页。常驻（由 AppDelegate 持有），收起再展开记住上次页；不跨重启。
final class IslandPagesModel: ObservableObject {
    @Published private(set) var current: IslandPage = .music

    func go(to page: IslandPage) { current = page }

    /// 相对移动并钳制到首末页（不回绕）
    func advance(by delta: Int) {
        let clamped = max(0, min(IslandPage.allCases.count - 1, current.rawValue + delta))
        if let page = IslandPage(rawValue: clamped) { current = page }
    }
}
