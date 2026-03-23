# 数独求解器

一个同时包含 macOS 桌面版、iPhone 版和命令行工具的数独项目。

它支持：

- 手动输入题面
- 从截图中自动识别数独盘面和已有数字
- 检查题面冲突、无解和多解
- 仅在唯一解存在时输出答案
- 把答案叠加回原截图并导出 PNG

## 截图预览

### 题面识别示例

![原始棋盘截图](docs/screenshots/board-input.png)

### 答案叠加示例

![答案叠加截图](docs/screenshots/board-solved.png)

## 项目结构

```text
.
├── Sources/
│   ├── SudokuCore/          # 求解、识别、图片渲染核心
│   ├── SudokuDesktopApp/    # macOS SwiftUI App
│   ├── SudokuMobileApp/     # iPhone SwiftUI App
│   └── SudokuImageSolver/   # 命令行入口
├── iOS/
│   └── SudokuMobileApp.xcodeproj
├── docs/screenshots/        # README 截图
├── .github/workflows/       # GitHub Actions 发布流程
├── build_app.sh             # 构建 macOS App
├── build_ios_sim.sh         # 构建 iOS 模拟器 App
└── Package.swift
```

## 功能概览

### macOS 版

- 点击棋盘格后输入数字
- 支持键盘 `1-9`、方向键、`Delete` / `Backspace`
- 导入截图后自动识别题面
- 一键求解
- 导出叠加答案图

### iPhone 版

- 触摸选中棋盘格并输入数字
- 从相册或文件导入截图
- 自动识别题面
- 一键求解
- 导出答案图

### 命令行工具

- 支持整图识别后求解
- 支持通过 `--givens` 直接传入 81 位题面字符串

## 环境要求

- macOS 13 及以上
- Xcode 16 或更新版本
- Swift 6.2 toolchain

## 本地运行

### 1. 构建 macOS App

```bash
./build_app.sh
open SudokuDesktopApp.app
```

### 2. 打开 iPhone 工程

```bash
open iOS/SudokuMobileApp.xcodeproj
```

如果只想编译模拟器版本：

```bash
./build_ios_sim.sh
```

构建完成后产物在：

```text
iOS/build/Debug-iphonesimulator/SudokuMobileApp.app
```

### 3. 命令行工具

先构建：

```bash
swift build -c release
```

自动识别模式：

```bash
.build/release/sudoku-image-solver input.png output.png
```

手动给题面模式：

```bash
.build/release/sudoku-image-solver input.png output.png \
  --givens 800049502450032069090000804004020091070010008021970305019403287060000050200700010
```

其中：

- 题面字符串共 `81` 位
- `0` 表示空格
- 顺序为从左到右、从上到下

## 自动识别说明

当前自动识别流程是：

1. 定位数独棋盘外框
2. 做透视校正
3. 将棋盘切分为 `9x9`
4. 对每格进行单独 OCR
5. 再用数独规则校验识别结果

这一版已经可以用于实际使用，但 OCR 仍然属于辅助功能，建议在求解前人工检查一遍识别结果。

## GitHub Release 发布

仓库已经附带自动发布工作流：

- 文件位置：`.github/workflows/release.yml`
- 触发方式：推送 `v*` 标签
- 发布内容：
  - `SudokuDesktopApp-macos.zip`
  - `SudokuMobileApp-ios-simulator.zip`
  - `sudoku-image-solver-macos.zip`
  - `SHA256SUMS.txt`

发布一个新版本时可以这样做：

```bash
git tag v1.0.0
git push origin v1.0.0
```

注意：

- iOS 产物是未签名的模拟器版本，适合演示和开发验证
- 真机安装仍需要你在本地 Xcode 中使用自己的签名配置


