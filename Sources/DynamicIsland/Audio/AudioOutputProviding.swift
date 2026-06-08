import CoreAudio

/// 输出设备数据源协议。注入以便用假实现测试 ViewModel。
protocol AudioOutputProviding: AnyObject {
    func outputDevices() -> [AudioDevice]
    func currentDefaultID() -> AudioDeviceID?
    func setDefault(_ id: AudioDeviceID)
    /// 设备增减 / 默认输出变化时回调（主线程）
    var onChange: (() -> Void)? { get set }
}
