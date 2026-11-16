# 更新日志

## [0.4.0] - 2026-11-16 · P1 规则内核重构与自研数值平衡
- 新增 `GameAction`、`GameController`、`NetTransport` 占位接口，所有状态变更统一经 `RulesEngine.apply_action` 验证并产出领域事件，支持确定性 `replay()` 与无快照悔棋。
- 新增 `PASS` 合法跳过处理及完整边界单测（18 项全部通过）。
- 使用 `tools/rebuild_craft_data.gd` 重制 90 张器物自研费用曲线，并通过 `tools/balance_sim.gd` 完成 600 场模拟验证，产出 `docs/BALANCE_REPORT.md`。

## [0.3.0] - 2026-11-16 · P0 工程基建
- 初始化 git 仓库，补充 `.gitignore` / `.gitattributes`。
- 新增 Autoload：`EventBus`（全局信号）、`Settings`（持久化设置，user://settings.cfg）。
- 新增 `tools/run_tests.ps1` 一键检查、`tools/snapshot.gd` 多分辨率截图（含手机横屏 2400×1080）。
- 项目配置：横屏方向、鼠标模拟触控、ETC2/ASTC 纹理压缩（移动端准备）、版本号。
- 新增 README、路线图、素材授权登记表。

## [0.2.0] - 2026-11-16
- 7 枚原创 SVG 图标、三阶卡牌底色区分、库房整行点选、悔棋、自动存档续玩、战绩统计、五声音阶合成音效。

## [0.1.0] - 2026-11-16
- 首个可玩版本：完整规则引擎、2~4 人、两档 AI、主菜单与对局桌面。
