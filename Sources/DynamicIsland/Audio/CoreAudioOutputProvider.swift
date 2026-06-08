import CoreAudio
import Foundation

/// 基于 CoreAudio 的系统输出设备读取/切换。改的是整机默认输出（影响所有 app）。
final class CoreAudioOutputProvider: AudioOutputProviding {
    var onChange: (() -> Void)?

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    /// 已注册的监听（地址 + 同一 block 引用），deinit 时按原引用注销，避免悬挂注册
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init() {
        addListener(kAudioHardwarePropertyDevices)
        addListener(kAudioHardwarePropertyDefaultOutputDevice)
    }

    deinit {
        for (addr, block) in listeners {
            var a = addr
            AudioObjectRemovePropertyListenerBlock(systemObject, &a, DispatchQueue.main, block)
        }
    }

    func outputDevices() -> [AudioDevice] {
        allDeviceIDs().compactMap { id in
            guard hasOutputChannels(id), let name = deviceName(id) else { return nil }
            return AudioDevice(id: id, name: name)
        }
    }

    func currentDefaultID() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &id)
        // id==0 即 kAudioObjectUnknown（设备切换瞬间可能短暂无默认输出），按"无"处理
        return (status == noErr && id != 0) ? id : nil
    }

    func setDefault(_ id: AudioDeviceID) {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var deviceID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(systemObject, &addr, 0, nil, size, &deviceID)
    }

    // MARK: - helpers

    private func address(_ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func hasOutputChannels(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        for buffer in list where buffer.mNumberChannels > 0 { return true }
        return false
    }

    private func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = address(kAudioObjectPropertyName)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name)
        return status == noErr ? (name as String) : nil
    }

    private func addListener(_ selector: AudioObjectPropertySelector) {
        var addr = address(selector)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.onChange?() }
        AudioObjectAddPropertyListenerBlock(systemObject, &addr, DispatchQueue.main, block)
        listeners.append((addr, block))
    }
}
