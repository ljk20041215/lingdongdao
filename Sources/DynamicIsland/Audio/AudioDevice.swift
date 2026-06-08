import CoreAudio

/// 一个音频输出设备。id 为 CoreAudio 的设备号。
struct AudioDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let name: String
}
