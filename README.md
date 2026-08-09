# Tianxuan Flutter

面向运维、站长、个人开发者的跨平台桌面端服务器管理工具，兼容宝塔 & 1Panel。

- **UI**：Flutter（Impeller/Skia 原生渲染，不使用 webview）
- **SSH/SFTP**：dartssh2（纯 Dart）
- **终端**：xterm (Dart)
- **面板**：webview_flutter_windows（WebView2，唯一 webview）
- **凭证**：flutter_secure_storage（Windows 凭据管理器）
- **状态**：riverpod

## 开发

```bash
flutter pub get
flutter run -d windows
```

## 测试

```bash
flutter analyze
flutter test
```

## 构建

```bash
flutter build windows --release
```

## 路线图

- [x] 骨架（导航 + 主题）
- [x] 主机管理（CRUD + 凭证）
- [x] SSH 终端（dartssh2 + xterm）
- [x] 主机工作区（终端 + 监控/文件侧栏）
- [x] 指标采集（CPU/内存/磁盘/IO/网络）
- [x] SFTP 文件管理（双击/右键菜单）
- [x] 总览（前台 1s / 后台 10s 刷新）
- [x] 批量命令（并发 + 历史）
- [x] 面板（WebView2 + 双击/右键）
