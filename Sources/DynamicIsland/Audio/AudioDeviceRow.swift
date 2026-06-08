import SwiftUI

/// 面板底部的输出设备行：扬声器图标 + 当前设备名 + 下拉菜单切换。
struct AudioDeviceRow: View {
    @ObservedObject var audioVM: AudioOutputViewModel

    var body: some View {
        Menu {
            ForEach(audioVM.devices) { device in
                Button { audioVM.select(device.id) } label: {
                    if device.id == audioVM.currentID {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hifispeaker.fill").font(.system(size: 11))
                Text(currentName).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .foregroundStyle(.gray)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onAppear { audioVM.refresh() }
    }

    private var currentName: String {
        audioVM.devices.first { $0.id == audioVM.currentID }?.name ?? "输出设备"
    }
}
