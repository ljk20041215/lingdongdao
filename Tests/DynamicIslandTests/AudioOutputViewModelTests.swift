import XCTest
import CoreAudio
@testable import DynamicIsland

private final class FakeOutputProvider: AudioOutputProviding {
    var onChange: (() -> Void)?
    var devices: [AudioDevice]
    var current: AudioDeviceID?
    private(set) var setCalls: [AudioDeviceID] = []
    init(devices: [AudioDevice], current: AudioDeviceID?) {
        self.devices = devices; self.current = current
    }
    func outputDevices() -> [AudioDevice] { devices }
    func currentDefaultID() -> AudioDeviceID? { current }
    func setDefault(_ id: AudioDeviceID) { setCalls.append(id); current = id }
}

final class AudioOutputViewModelTests: XCTestCase {
    private func twoDevices() -> FakeOutputProvider {
        FakeOutputProvider(devices: [AudioDevice(id: 1, name: "A"),
                                     AudioDevice(id: 2, name: "B")], current: 1)
    }

    func testRefreshLoadsDevicesAndCurrent() {
        let vm = AudioOutputViewModel(provider: twoDevices())
        vm.refresh()
        XCTAssertEqual(vm.devices.map(\.id), [1, 2])
        XCTAssertEqual(vm.currentID, 1)
    }

    func testSelectSetsDefaultAndUpdatesCurrent() {
        let p = twoDevices()
        let vm = AudioOutputViewModel(provider: p)
        vm.refresh()
        vm.select(2)
        XCTAssertEqual(p.setCalls, [2])
        XCTAssertEqual(vm.currentID, 2)
    }
}
