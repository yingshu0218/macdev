# macOS V1 验收清单

本清单把仓库 `TECH_SPEC.md` §40 与 macOS 原生实现对应起来。只有全部条目有运行证据时，第一版才算完成。

## 数据与安全

- [x] 本地 SQLite 持久化，可定位数据文件并备份
- [x] DNSPod / AliDNS 凭证仅保存在 Keychain
- [x] 多个 Provider 账号可添加、测试、编辑和删除
- [x] Secret 不进入界面回显、持久化模型、错误信息和日志

## DNS 工作台

- [x] 所有账号的域名可同步到统一列表
- [x] 域名搜索、Provider / 账号 / 项目 / 标签 / 收藏筛选可组合
- [x] 收藏、项目、多个标签与备注可编辑并持久化
- [x] 最近同步、解析数量、到期未知状态表达正确

## DNS Records

- [x] 可查看 A / AAAA / CNAME / MX / TXT / NS / SRV / CAA
- [x] 可新增、修改、删除记录
- [x] Provider capability 控制动态字段与校验
- [x] 记录读取有 30 秒缓存，写操作后主动失效
- [x] 删除有完整预览与二次确认

## 审计与恢复

- [x] 每次 Record 新增 / 修改 / 删除都有操作日志和快照
- [x] 失败操作也有脱敏日志
- [x] Create / Update / Delete 三类操作都可恢复
- [x] Restore 重新读取当前状态并二次确认，且自身产生新日志

## 搜索与桌面体验

- [x] 全局搜索覆盖域名、项目、标签、备注、Record Value
- [x] A / AAAA 精确值可完成 IP 反查
- [x] 搜索结果显示索引新鲜度并可打开域名详情
- [x] 菜单、键盘、侧栏和主要按钮均可到达核心操作
- [x] macOS 26 使用 Liquid Glass，macOS 15–25 有系统材质回退

## 服务器管理（第一阶段）

- [x] 服务器资产可新增、编辑、删除并通过 SwiftData 持久化
- [x] 搜索、环境 / 服务商 / 状态筛选与收藏可组合
- [x] 主机、端口、SSH 用户、项目、标签、备注和到期日可维护
- [x] 可复制 SSH 命令，且不保存 SSH 密码或私钥
- [x] 可手动执行 TCP 可达性检测并记录最近检查时间和状态
- [x] 首页、侧栏、菜单和服务器工作台之间可原生导航
- [x] 可把 SSH URL 安全交给系统终端，不在应用内托管密钥
- [x] 可配置运行期间的定时 TCP 健康检查和不可达 / 到期通知

## 运维管理

- [x] DNS 可配置运行期间定时同步并对失败连接发送本机通知
- [x] 证书可新增、编辑、删除，展示有效 / 即将到期 / 已过期状态
- [x] 证书支持域名、颁发者、部署位置、到期日期和备注
- [x] 部署记录支持项目、版本、环境、结果、服务器和回滚版本
- [x] 首页、侧栏和 `⌘4` / `⌘5` 可进入证书与部署模块

## Git 远程备份

- [x] 设置页支持仓库、分支、HTTPS Token / SSH 认证配置
- [x] Token 和备份密码仅进入 macOS 钥匙串
- [x] 生成版本化 JSON payload、manifest 和 AES-256-GCM 加密 envelope
- [x] Git 子进程使用参数数组；HTTPS Token 不进入 remote URL 或命令参数
- [x] 默认只管理 `backup/macos` 分支和 `backups/macos` 路径
- [x] 支持测试连接、立即备份、最近备份结果与本地提交历史读取
- [x] Provider Secret、SSH 私钥和钥匙串内容不进入备份

## 发布门槛

- [x] 全部单元测试通过（14/14，2026-08-25）
- [x] Debug 构建成功并通过 `./script/build_and_run.sh --verify`
- [x] Universal Release 构建成功（arm64 + x86_64）
- [x] 真实窗口完成首页、连接、同步、记录 CRUD、历史恢复、搜索与重启持久化验收

## 验收证据

- 数据库：`~/Library/Application Support/DeveloperAssistant/DeveloperAssistant.sqlite`，`PRAGMA journal_mode` 返回 `wal`。
- 备份：`Backups/backup-20260824-230515` 同时包含 SQLite、WAL、SHM，`PRAGMA integrity_check` 返回 `ok`。
- 真实窗口：创建并编辑 A 记录、删除后二次确认、从历史恢复；创建项目和标签并保存备注；精确 IP 反查；锁定界面触发系统认证。
- 重启检查：首页仍加载 1 个连接、2 个域名，项目“官网”、标签“生产”和备注保持；DNS 工作台、详情、历史表格无横向溢出。
- 服务器窗口：资产创建后可在重启后恢复；列表、筛选、编辑器和详情检查器无横向溢出；保留地址 TCP 检测按预期进入“不可达”。
