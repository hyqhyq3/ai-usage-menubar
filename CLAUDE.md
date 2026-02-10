# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

GLM 用量查询 macOS 菜单栏应用，使用 Swift 和 AppKit 构建。通过调用 GLM Coding Plan API 查询 Token 和 MCP 使用情况，并显示在系统菜单栏中。

## 构建和运行

```bash
# 使用 Xcode 构建项目
xcodebuild -scheme glm-usage -configuration Debug build

# 编译后的应用位于
~/Library/Developer/Xcode/DerivedData/glm-usage-*/Build/Products/Debug/glm-usage.app

# 运行应用
open ~/Library/Developer/Xcode/DerivedData/glm-usage-*/Build/Products/Debug/glm-usage.app
```

## 代码架构

### 核心文件结构

- `App/main.swift` - 应用入口，包含 `ConfigDialog` 和 `AppDelegate` 类
- `App/APIService.swift` - API 服务层，处理与两个 API 服务商的交互
- `App/Models.swift` - 数据模型定义，包含 API 响应模型和 UserDefaults 扩展

### 应用生命周期

1. `AppDelegate.applicationDidFinishLaunching` 初始化应用
2. 检查 UserDefaults 中是否有 API 配置
3. 如无配置，显示 `ConfigDialog` 让用户输入
4. 有配置则立即刷新数据，并启动每 60 秒的定时器

### API 服务商支持

应用支持两个 API 服务商，通过 `baseURL` 自动识别：

| 服务商 | baseURL | API 检测逻辑 |
|--------|---------|-------------|
| z.ai | `https://api.zai.ai` | 默认（URL 不包含 "bigmodel"） |
| bigmodel.cn | `https://open.bigmodel.cn/api` | URL 包含 "bigmodel" |

两种 API 的响应格式完全不同：
- **z.ai**: 返回 `ModelUsageResponse`, `QuotaLimitResponse`, `ToolUsageResponse`
- **bigmodel.cn**: 返回 `BigModelResponse<T>` 包装的数据

`APIService.refreshUsageData()` 根据 baseURL 自动选择对应的解析逻辑。

### 配置存储

使用 UserDefaults 存储配置（Keys 定义在 Models.swift:257-260）：
- `ANTHROPIC_BASE_URL` - API 基础 URL
- `ANTHROPIC_AUTH_TOKEN` - 认证 Token

### 配置对话框设计

`ConfigDialog` 使用固定下拉菜单（`NSPopUpButton`）选择 API 服务商，而非自由文本输入。保存时根据选中项（`indexOfSelectedItem`）映射到对应 URL。

### 数据模型

- `UsageData` - 统一的用量数据结构，屏蔽不同 API 的差异
- `APIError` - 定义了所有 API 相关错误类型，提供中文错误描述

### UI 更新

菜单栏标题显示为 "GLM X%"（X 为用量百分比），出错时显示 "GLM !"。菜单项包括：
- Token 用量百分比和详细数据
- MCP 用量
- 前 3 个模型的使用情况
- 更新时间、刷新按钮、配置按钮、退出按钮
