# 发布与打包清单（v1.0.0）

## 1. 自动化验收
- [x] `powershell -File tools/run_tests.ps1 -Snapshot` 全部通过（18 项单测 + 4 套分辨率截图）
- [x] `godot --headless --path . --script res://tools/balance_sim.gd` 600 场平衡模拟通过
- [x] `godot --headless --path . --script res://tools/ai_benchmark.gd` 宗师 AI 胜率 ≥ 65%（实测 81.7%）
- [x] 所有第三方资产登记于 `assets/LICENSES.md`（SIL OFL 1.0 + 原创 SVG）

## 2. 导出步骤（需先安装 Godot 4.7.2 Export Templates）
在 Godot 编辑器中点击：`编辑器 -> 管理导出模板 -> 下载并安装`（约 1 GB）。安装完成后即可直接命令行导出：

```powershell
# Windows 桌面版（单文件内嵌 PCK）
New-Item -ItemType Directory -Force -Path build\windows | Out-Null
godot --headless --path . --export-release "Windows Desktop" build/windows/baigong-yaji.exe

# Web HTML5 试玩版（可直接部署到 GitHub Pages / itch.io）
New-Item -ItemType Directory -Force -Path build\web | Out-Null
godot --headless --path . --export-release "Web" build/web/index.html

# Android 安装包（需配置 Android SDK 与 debug/release keystore）
New-Item -ItemType Directory -Force -Path build\android | Out-Null
godot --headless --path . --export-release "Android" build/android/baigong-yaji.apk
```
