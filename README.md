# lindongdao 灵动岛

macOS 灵动岛：悬停刘海展开音乐面板（Apple Music / Spotify）。

> 当前版本专注音乐。文件中转站已实现但暂时下线（代码保留，把
> `FeatureFlags.shelfEnabled` 改回 `true` 即可恢复）。

## 运行（开发）

```bash
swift run lindongdao    # Ctrl+C 退出
```

## 打包

```bash
./scripts/make_app.sh   # 生成 build/lindongdao.app，可拖到 /Applications
```

## 使用

- **悬停刘海** → 展开音乐面板；移开 → 收起
- **音乐**：播放 Music 或 Spotify 时刘海两侧显示封面与波形，展开后可控制播放
- **退出**：菜单栏胶囊图标 → 退出

## 权限

首次控制音乐时系统会请求"自动化"权限，请允许。误拒后到
系统设置 → 隐私与安全性 → 自动化 中重新开启。

注意：每次重新打包（ad-hoc 签名变化）可能使已授予的自动化权限失效，
且部分系统版本表现为静默拒绝而非重新弹框。若重打包后音乐功能异常，先执行：

```bash
tccutil reset AppleEvents io.github.ljk20041215.lindongdao
```

## 测试

```bash
swift test
```
