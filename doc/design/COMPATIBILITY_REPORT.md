# AISudoLogic iOS 15 / macOS 12 兼容性分析报告

> 生成日期: 2026-08-10
> 当前部署目标: iOS 26.1, macOS 15.7
> 目标部署目标: iOS 15.0, macOS 12.0

---

## 目录

1. [概述](#概述)
2. [不兼容问题清单](#不兼容问题清单)
3. [已实施的修复](#已实施的修复)
4. [风险说明](#风险说明)

---

## 概述

项目当前使用 Xcode 26.1 (Swift 5.x) 创建,部署目标设置为 iOS 26.1 / macOS 15.7(分别对应实际 OS 版本的 iOS 18.x / macOS 15.x SDK)。目标将最低版本降低至 **iOS 15.0** 和 **macOS 12.0**,使得应用能在双端多版本中正常运行。

本次分析覆盖了全部 `.swift` 源文件(23 个文件),识别出 **5 类不兼容问题**,均已修复。

---

## 不兼容问题清单

### 1. ❌ SwiftData 框架 (iOS 17.0+, macOS 14.0+)

**严重程度: 🔴 致命 — 编译失败**

SwiftData 要求 iOS 17.0 / macOS 14.0 以上。项目中多处使用了 SwiftData API:

| 文件 | 行号 | 使用方式 |
|------|------|----------|
| `GameSession.swift` | `@Model` 宏 | `GameSession` 和 `Trophy` 类使用 `@Model` 注解 |
| `ContentView.swift` | `@Query` 属性包装器 | 查询已保存的 `GameSession` 和 `Trophy` |
| `AISudoLogicApp.swift` | `.modelContainer(for:)` | 注册 SwiftData 模型容器 |
| `ContentView.swift` | `@Environment(\.modelContext)` | 获取 ModelContext 进行增删 |
| `ContentView.swift` | `modelContext.insert()` / `modelContext.save()` | 持久化操作 |

**修复方案**: 用 `Codable` struct + 文件持久化 (`JSONEncoder`/`JSONDecoder`) 替换整个 SwiftData 层。

- `GameSession` 和 `Trophy` 改为 `Codable` struct
- 新建 `PersistenceStore` 类管理 JSON 文件读写
- 通过 `@StateObject` + `.environmentObject()` 注入应用

---

### 2. ❌ `.onChange(of:initial:_:)` 双参数闭包 (iOS 17.0+, macOS 14.0+)

**严重程度: 🔴 致命 — 编译失败**

SwiftUI 在 iOS 17 / macOS 14 引入了带有 `initial` 参数的双参数闭包版本。iOS 15 / macOS 12 只支持单参数闭包版本。

| 文件 | 行号 | 代码 |
|------|------|------|
| `AISudoLogicApp.swift` | 49 | `.onChange(of: pinManager.isPinned) { _, _ in ... }` |
| `ContentView.swift` | 122, 136 | `.onChange(of: viewModel.isCompleted) { _, completed in ... }` |
| `ContentView.swift` | 136 | `.onChange(of: isInGame) { _, _ in ... }` |
| `GameView.swift` | 119, 122 | `.onChange(of: viewModel.isPaused) { _, paused in ... }` |
| `AICoachView.swift` | 58, 62, 67 | `.onChange(of: coach.messages.count) { _, _ in ... }` |

**修复方案**: 将所有双参数闭包改为单参数形式 `{ newValue in ... }`。

---

### 3. ❌ 键盘/焦点相关 API (iOS 17.0+, macOS 14.0+)

**严重程度: 🔴 致命 — 编译失败**

| API | 最低版本 | 文件 |
|-----|----------|------|
| `.focusable()` | iOS 17.0, macOS 14.0 | `GameView.swift:126` |
| `.focusEffectDisabled()` | iOS 17.0, macOS 14.0 | `GameView.swift:128` |
| `.onKeyPress(...)` | iOS 17.0, macOS 14.0 | `GameView.swift:129-142` |

这些 API 提供了实体键盘 / 蓝牙键盘操作支持。在低于 iOS 17 / macOS 14 的平台上,键盘输入功能不可用。

**修复方案**: 使用 `if #available(iOS 17.0, macOS 14.0, *)` 条件编译守卫,在旧版本中优雅降级(触摸操作正常工作,仅实体键盘方向键/数字键不可用)。

---

### 4. ⚠️ `.scrollContentBackground(.hidden)` (iOS 16.0+, macOS 13.0+)

**严重程度: 🟡 警告 — 低于目标编译报错**

| API | 最低版本 | 文件 |
|-----|----------|------|
| `.scrollContentBackground(.hidden)` | iOS 16.0, macOS 13.0 | `AICoachView.swift:171` |

虽然 iOS 16/macOS 13 仍然高于我们的最低目标(iOS 15 / macOS 12),此 API 在 iOS 15 上不可用。在旧版本中降级为无操作。

**修复方案**: 添加 `#available(iOS 16.0, macOS 13.0, *)` 守卫。

---

### 5. ⚠️ `.defaultSize(width:height:)` (macOS 13.0+)

**严重程度: 🟡 警告 — macOS 12 下编译报错**

| API | 最低版本 | 文件 |
|-----|----------|------|
| `.defaultSize(width:height:)` | macOS 13.0 | `AISudoLogicApp.swift:55` |

**修复方案**: 添加 `#available(macOS 13.0, *)` 守卫。macOS 12 中通过 `NSWindow.setContentSize()` 设置窗口大小(已有相关逻辑)。

---

## 兼容性良好的 API (无需修改)

以下 API 在 iOS 15 / macOS 12 及以上均可使用,无需修改:

| 类别 | API | 说明 |
|------|-----|------|
| 并发 | `async/await`, `Task`, `Task.detached`, `@MainActor` | Swift 5.5+, iOS 15 / macOS 12 完全支持 |
| 网络 | `URLSession.shared.bytes(for:)`, `AsyncSequence.lines` | iOS 15 / macOS 12 完全支持 |
| SwiftUI | `@StateObject`, `@EnvironmentObject`, `@Published`, `ObservableObject` | iOS 14+ |
| SwiftUI | `LazyVGrid`, `ScrollView`, `ScrollViewReader`, `GeometryReader` | iOS 14+ |
| SwiftUI | `.sheet()`, `.overlay()`, `.focused()` | iOS 15 兼容 |
| SwiftUI | `.textSelection(.enabled)` | iOS 15+, macOS 12+ |
| SwiftUI | `Menu`, `Toggle`, `SecureField`, `TextEditor` | iOS 15 兼容 |
| SwiftUI | `#if os(macOS)` / `#if os(iOS)` 条件编译 | 所有版本支持 |
| 编译选项 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | 编译期特性,不依赖运行时版本 |
| 编译选项 | `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | 编译期特性 |
| 编译选项 | `SWIFT_APPROACHABLE_CONCURRENCY` | 编译期特性 |

---

## 已实施的修复

### 修复 1: 替换 SwiftData (PersistenceStore)

- ✅ `GameSession.swift`: `@Model class` → `Codable struct` (含 `UUID id`)
- ✅ `Trophy`: `@Model class` → `Codable struct` (含 `UUID id`)
- ✅ 新建 `PersistenceStore.swift`: 管理 JSON 文件 CRUD,支持 `@Published`
- ✅ `ContentView.swift`: 移除 `@Environment(\.modelContext)` 和 `@Query`,改用 `@EnvironmentObject var store: PersistenceStore`
- ✅ `AISudoLogicApp.swift`: `.modelContainer(for:)` → `.environmentObject(PersistenceStore())`
- ✅ `GameViewModel.swift`: `save(to: GameSession)` → `exportSession(id:isDailyChallenge:) -> GameSession`
- ✅ `StatsView.swift` / `DailyChallengeView.swift`: 移除 `import SwiftData`
- ✅ `MarkdownBubble.blocks`: 属性改为 `internal` 访问级别(保持测试兼容)

### 修复 2: `.onChange` 双参数 → 单参数闭包

- ✅ 所有 `.onChange(of:)` 闭包从 `{ _, new in }` 改为 `{ new in }`

### 修复 3: 键盘 API 可用性守卫

- ✅ `.focusable()`, `.focusEffectDisabled()`, `.onKeyPress()` 包裹在 `if #available(iOS 17.0, macOS 14.0, *)` 中

### 修复 4: `.scrollContentBackground` 可用性守卫

- ✅ `AICoachView.swift:171`: 添加 `#available(iOS 16.0, macOS 13.0, *)` 守卫

### 修复 5: `.defaultSize` 可用性守卫

- ✅ `AISudoLogicApp.swift:55`: 添加 `#available(macOS 13.0, *)` 守卫

### 修复 6: 部署目标更新

- ✅ `project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET` = 15.0 (全部 target: App + Tests + UITests)
- ✅ `project.pbxproj`: `MACOSX_DEPLOYMENT_TARGET` = 12.0 (全部 target)

---

## 风险说明

### 1. 键盘操作降级

在 iOS 15-16 和 macOS 12-13 上,实体键盘的以下功能不可用:
- 方向键移动选格
- 数字键(1-9)直接输入
- Delete 键擦除
- Escape 键暂停
- Return 键恢复

**影响**: 仅影响外接/蓝牙键盘用户。触摸/鼠标操作完全正常。**这是 SwiftUI 框架限制,无法通过替代方案绕过。**

### 2. Vision Pro (xros) 平台

当前 `XROS_DEPLOYMENT_TARGET = 26.1` 未作修改(用户仅要求调整 iOS/macOS 目标)。若需支持更低版本 visionOS,请额外评估。

### 3. 用户数据迁移

**现有用户数据将丢失**。SwiftData 存储格式与新的 JSON 文件格式不兼容。如应用已有用户,需编写数据迁移脚本。

### 4. Xcode 版本

项目使用 Xcode 26.1 (objectVersion=77) 创建。降低部署目标后,仍需使用相同或更高版本的 Xcode 进行编译。在更旧的 Xcode 版本中可能无法打开此项目。

---

## 总结

| 类别 | 数量 | 状态 |
|------|------|------|
| 🔴 致命不兼容 | 3 (SwiftData, onChange, 键盘API) | ✅ 已修复 |
| 🟡 警告不兼容 | 2 (scrollContentBackground, defaultSize) | ✅ 已修复 |
| 🟢 兼容 | 所有其他 API | 无需修改 |

全部 5 类兼容性问题已修复,代码现在可以在 iOS 15.0+ / macOS 12.0+ 上编译和运行。
