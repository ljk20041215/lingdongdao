import XCTest
@testable import DynamicIsland

final class NotchGeometryTests: XCTestCase {
    // 14" MacBook Pro 典型值：屏幕 1512x982 pt，安全区顶部 32pt，刘海两侧各 622pt
    func testComputesNotchRectFromScreenValues() {
        let g = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeTopInset: 32,
            leftAuxWidth: 622,
            rightAuxWidth: 622)
        XCTAssertTrue(g.hasNotch)
        XCTAssertEqual(g.notchRect, CGRect(x: 622, y: 950, width: 268, height: 32))
    }

    func testScreenWithOriginOffset() {
        let g = NotchGeometry.compute(
            screenFrame: CGRect(x: 100, y: 50, width: 1512, height: 982),
            safeTopInset: 32,
            leftAuxWidth: 622,
            rightAuxWidth: 622)
        XCTAssertEqual(g.notchRect, CGRect(x: 722, y: 1000, width: 268, height: 32))
    }

    // 防御：无刘海时回退为顶部居中 184x32 胶囊（spec 错误处理表）
    func testNoNotchFallback() {
        let g = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeTopInset: 0,
            leftAuxWidth: nil,
            rightAuxWidth: nil)
        XCTAssertFalse(g.hasNotch)
        XCTAssertEqual(g.notchRect, CGRect(x: 868, y: 1048, width: 184, height: 32))
    }
}
