# lindongdao 灵动岛

macOS 灵动岛：悬停刘海展开，左侧音乐播放（Apple Music / Spotify），右侧文件中转站。

## 运行（开发）

```bash
swift run lindongdao    # Ctrl+C 退出
```

## 打包

```bash
./scripts/make_app.sh   # 生成 build/lindongdao.app，可拖到 /Applications
```

## 使用

- **悬停刘海** → 展开面板；移开 → 收起
- **音乐**：播放 Music 或 Spotify 时刘海两侧显示封面与波形，展开后可控制播放
- **文件架**：拖文件到刘海暂存（最多 10 个），从架上拖出到任意位置使用；× 移除，重启不丢失
- **退出**：菜单栏胶囊图标 → 退出

## 权限

首次控制音乐时系统会请求"自动化"权限，请允许。误拒后到
系统设置 → 隐私与安全性 → 自动化 中重新开启。

## 测试

```bash
swift test
```
