# 百工雅集 · Baigong Yaji

国风传统器物题材的策略桌面卡牌游戏（Godot 4.7 / GDScript）。
采集玉、瓷、竹、砂、墨五种材料，打造三阶传世器物，邀请历代名士共赴雅集，率先达到目标声望者胜。

> 游戏机制受经典“引擎构筑类”桌游启发；题材、数值、美术、文本均为原创。

## 运行

```powershell
godot --path .              # 启动游戏
godot -e --path .           # 打开编辑器
```

## 测试与检查

```powershell
powershell -File tools/run_tests.ps1             # 导入 + 场景加载 + 全部单测/模拟
powershell -File tools/run_tests.ps1 -Snapshot   # 额外生成多分辨率截图到 tools/out/
```

## 目录结构

```
assets/          美术、字体、音频（来源与授权见 assets/LICENSES.md）
data/            器物与名士数据表（JSON）
docs/            路线图、设计文档
scenes/          场景
scripts/
  autoload/      全局单例：EventBus、Settings
  core/          纯逻辑（规则、AI、存档），不依赖 UI，可无头运行
  ui/            界面层
tests/           自动化测试（test_*.gd）
tools/           开发工具：测试脚本、截图、数值模拟
```

## 目标平台

- Windows / macOS / Linux 桌面
- Android / iOS（横屏，触控）
- Web（HTML5 试玩）

## 路线图

见 [docs/ROADMAP.md](docs/ROADMAP.md)。

## 许可

代码：MIT（待定）。第三方素材授权见 `assets/LICENSES.md`。
