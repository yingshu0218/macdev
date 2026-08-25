# 开发管理助手 macOS

面向个人开发者的原生 SwiftUI 管理工具，用一个 macOS 应用集中管理 DNS、服务器、证书和部署记录。

[下载最新版本](https://github.com/yingshu0218/macdev/releases/latest) · 当前版本 `1.0.0`

## 系统要求与安装

- macOS 15.0 或更高版本
- 同时支持 Apple Silicon 与 Intel Mac

从 [Releases](https://github.com/yingshu0218/macdev/releases) 下载 DMG，打开后将 `DeveloperAssistant.app` 拖入“应用程序”。当前版本没有 Apple Developer ID 公证；首次打开请右键应用选择“打开”，或在“系统设置 → 隐私与安全性”中允许打开。

## 当前能力

- 原生 `NavigationSplitView` 桌面布局
- 首页本机应用 Dock：选择已安装的 `.app`、显示真实图标、一键启动、排序和持久化
- 首页四个功能卡片直接展示实时资源指标并进入对应工作台
- macOS 顶部菜单栏状态图标，可快速打开各模块和运行检查
- 腾讯云 DNSPod、阿里云 AliDNS 正式 API 适配器
- 多账号连接、统一域名工作台、项目/标签/收藏/备注与组合筛选
- A、AAAA、CNAME、MX、TXT、NS、SRV、CAA 记录查看及 CRUD
- 30 秒记录缓存、全局搜索、A/AAAA 精确 IP 反查
- 操作日志、变更前后快照、删除二次确认和 Create/Update/Delete 恢复
- 服务器资产统一列表、搜索与环境/服务商/状态筛选、收藏、标签、项目和备注
- 服务器新增/编辑/删除、SSH 连接命令复制，以及手动 TCP 可达性检测
- 使用系统终端打开 SSH，不在应用内读取或托管私钥
- DNS 定时同步、服务器定时健康检查与本机异常通知（应用运行期间）
- Git 远程加密备份：HTTPS Token 或本机 SSH、独立 `backup/macos` 分支、连接测试与立即推送
- 证书到期管理、部署位置追踪和 30 天到期提醒
- 部署历史、版本、环境、结果、回滚版本与服务器关联
- SwiftData SQLite/WAL 持久化、Keychain 凭证、本地备份和 Touch ID/系统密码应用锁
- macOS 26 Liquid Glass；macOS 15–25 使用系统材质回退
- 菜单与键盘导航：`⌘1` 首页、`⌘2` DNS 工作台、`⌘3` 服务器管理、`⌘4` 证书管理、`⌘5` 部署记录、`⇧⌘K` 服务商连接

## 构建

安装 Xcode 以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，然后在仓库根目录运行：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project DeveloperAssistant.xcodeproj \
  -scheme DeveloperAssistant \
  -configuration Debug \
  -derivedDataPath .build \
  build
open .build/Build/Products/Debug/DeveloperAssistant.app
```

工程文件由 XcodeGen 根据 `project.yml` 生成，不手工维护。

运行单元测试：

```bash
xcodegen generate
xcodebuild -project DeveloperAssistant.xcodeproj \
  -scheme DeveloperAssistant \
  -configuration Debug \
  -derivedDataPath .build \
  test
```

## 本地数据

- 主数据库：`~/Library/Application Support/DeveloperAssistant/DeveloperAssistant.sqlite`
- 备份目录：`~/Library/Application Support/DeveloperAssistant/Backups`
- Provider Secret：仅保存于 macOS 钥匙串，不写入 SQLite 或日志
- Git Token 与备份加密密码：仅保存于 macOS 钥匙串，不写入仓库或命令参数

服务器模块不保存 SSH 密码或私钥；连接由系统终端和用户已有的 SSH 配置处理。云厂商实例自动同步、主机 Agent 指标采集和应用退出后的后台任务不在本阶段范围内。

DNS 变更前请添加 DNSPod 或 AliDNS 连接，并为凭证配置最小必要权限。

完整验收结果见 `V1_ACCEPTANCE.md`。

## 隐私与发布状态

- 所有业务数据默认仅保存在本机。
- DNS Provider Secret、Git Token 和备份密码使用 macOS 钥匙串。
- 应用不会保存 SSH 密码或私钥。
- `1.0.0` 是第一版自用 Release，采用本地 ad-hoc 签名，尚未进行 Apple 公证。

## License

当前仓库未授予开源再分发许可；代码与安装包供仓库所有者自用和测试。
