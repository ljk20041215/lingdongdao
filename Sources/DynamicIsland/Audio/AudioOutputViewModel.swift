import Foundation
import CoreAudio

final class AudioOutputViewModel: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var currentID: AudioDeviceID?

    private let provider: AudioOutputProviding

    init(provider: AudioOutputProviding) {
        self.provider = provider
        provider.onChange = { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func refresh() {
        devices = provider.outputDevices()
        currentID = provider.currentDefaultID()
    }

    func select(_ id: AudioDeviceID) {
        provider.setDefault(id)
        refresh()
    }
}
