import XCTest
@testable import DynamicIsland

final class ShelfStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lindongdao-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeStore(fileExists: @escaping (URL) -> Bool = { _ in true }) -> ShelfStore {
        ShelfStore(storeURL: tempDir.appendingPathComponent("shelf.json"),
                   fileExists: fileExists)
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testAddAndRemove() {
        let store = makeStore()
        store.add(urls: [url("a.txt"), url("b.txt")])
        XCTAssertEqual(store.items.map(\.url), [url("a.txt"), url("b.txt")])
        store.remove(store.items[0].id)
        XCTAssertEqual(store.items.map(\.url), [url("b.txt")])
    }

    func testRejectsBeyondMaxItems() {
        let store = makeStore()
        let urls = (0..<12).map { url("f\($0).txt") }
        let rejected = store.add(urls: urls)
        XCTAssertEqual(store.items.count, ShelfStore.maxItems)
        XCTAssertEqual(rejected, [url("f10.txt"), url("f11.txt")])
    }

    func testDeduplicatesSameURL() {
        let store = makeStore()
        store.add(urls: [url("a.txt")])
        let rejected = store.add(urls: [url("a.txt")])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(rejected.isEmpty)   // 重复不算拒绝，静默忽略
    }

    func testClear() {
        let store = makeStore()
        store.add(urls: [url("a.txt"), url("b.txt")])
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistsAcrossInstances() {
        let store1 = makeStore()
        store1.add(urls: [url("a.txt")])
        let store2 = makeStore()
        XCTAssertEqual(store2.items.map(\.url), [url("a.txt")])
    }

    func testMissingFileDetection() {
        let store = makeStore(fileExists: { $0.lastPathComponent != "gone.txt" })
        store.add(urls: [url("here.txt"), url("gone.txt")])
        XCTAssertFalse(store.isMissing(store.items[0]))
        XCTAssertTrue(store.isMissing(store.items[1]))
    }

    // 损坏的 shelf.json 应静默回退为空架，且下次保存自愈（spec 错误处理：不崩溃）
    func testCorruptStoreFileFallsBackToEmpty() {
        let storeURL = tempDir.appendingPathComponent("shelf.json")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? Data("not json{{".utf8).write(to: storeURL)
        let store = makeStore()
        XCTAssertTrue(store.items.isEmpty)
        store.add(urls: [url("a.txt")])
        XCTAssertEqual(makeStore().items.map(\.url), [url("a.txt")])   // 保存自愈
    }
}
