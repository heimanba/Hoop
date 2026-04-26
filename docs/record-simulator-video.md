# record-simulator-video.sh 使用文档

录制 iOS 模拟器屏幕视频的便捷脚本。默认流程为：构建并启动 Hoop 应用 → 开始录屏 → 按 Ctrl+C 停止并保存 `.mov` 文件。

## 快速开始

```bash
# 构建、启动应用并录制
./scripts/record-simulator-video.sh

# 仅录制（不重新构建，录制当前已启动的模拟器）
./scripts/record-simulator-video.sh --record-only
```

## 命令行选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--record-only` | 跳过构建和启动，直接录制当前已启动的模拟器 | 关闭 |
| `--simulator NAME` | 指定模拟器名称 | `iPhone 17` |
| `--output PATH` | 录像输出路径（相对路径基于仓库根目录） | `.build/recordings/hoop-YYYYMMDD-HHMMSS.mov` |
| `--codec CODEC` | 视频编码：`h264` 或 `hevc` | `h264` |
| `-h`, `--help` | 显示帮助信息 | — |

## 环境变量

也可以通过环境变量覆盖默认配置：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `SIMULATOR_NAME` | 模拟器名称 | `iPhone 17` |
| `VIDEO_PATH` | 输出文件路径 | `.build/recordings/hoop-YYYYMMDD-HHMMSS.mov` |
| `VIDEO_CODEC` | 视频编码（`h264` / `hevc`） | `h264` |
| `RECORD_ONLY` | 设为 `1` 等同于 `--record-only` | `0` |

## 使用示例

```bash
# 默认流程：构建 + 启动 + 录制
./scripts/record-simulator-video.sh

# 仅录制当前模拟器画面
./scripts/record-simulator-video.sh --record-only

# 指定模拟器型号
./scripts/record-simulator-video.sh --simulator "iPhone 17 Pro"

# 指定输出路径
./scripts/record-simulator-video.sh --output .build/recordings/demo.mov

# 使用 HEVC 编码（文件更小）
./scripts/record-simulator-video.sh --codec hevc

# 通过环境变量配置
SIMULATOR_NAME="iPhone 17 Pro" ./scripts/record-simulator-video.sh

# 组合：仅录制 + 指定路径
VIDEO_PATH=".build/recordings/demo.mov" ./scripts/record-simulator-video.sh --record-only
```

## 工作流程

1. **非 `--record-only` 模式**：调用 `build-and-launch.sh` 构建并启动应用到指定模拟器，然后开始录屏。
2. **`--record-only` 模式**：
   - 优先查找当前已启动的模拟器进行录制。
   - 如果没有已启动的模拟器，则启动指定名称的模拟器后录制。
3. 按 **Ctrl+C** 停止录制，视频文件自动保存到指定路径。

## 输出

- 视频格式为 `.mov`
- 默认保存在 `.build/recordings/` 目录下，文件名包含时间戳
- 如果输出路径为相对路径，会自动基于仓库根目录解析

## 依赖

- Xcode 命令行工具（`xcrun simctl`）
- Python 3（用于解析模拟器列表 JSON）
- `build-and-launch.sh`（非 `--record-only` 模式时需要）
