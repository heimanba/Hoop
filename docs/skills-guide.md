# Skills 使用指南

本文档说明 Hoop 项目中 `.agents/skills` 目录下各个 Skill 的选择场景、组合方式和典型用法。

Skill 是给 Agent 使用的专项工作说明。你可以显式点名某个 Skill，例如“用 `swiftui-performance-audit` 检查这个页面”，也可以只描述任务；当任务和 Skill 描述匹配时，Agent 会自动加载对应说明。

## 快速选择

| 你要做什么 | 首选 Skill | 何时搭配其它 Skill |
| --- | --- | --- |
| 写一个新的 SwiftUI 页面或功能 | `swiftui-expert-skill` | 需要具体组件模式时搭配 `swiftui-ui-patterns`；完成后用 `swiftui-pro` review |
| 设计 Tab、NavigationStack、Sheet、List、Form、Search 等 UI 结构 | `swiftui-ui-patterns` | 需要实际落地实现时搭配 `swiftui-expert-skill` |
| Review SwiftUI 代码质量 | `swiftui-pro` | 性能问题明显时搭配 `swiftui-performance-audit` |
| 拆分复杂 SwiftUI View、清理大 body | `swiftui-view-refactor` | 涉及新 UI 结构时搭配 `swiftui-ui-patterns` |
| 诊断滚动卡顿、重绘过多、CPU/内存高 | `swiftui-performance-audit` | 需要直接修复 SwiftUI 代码时搭配 `swiftui-expert-skill` |
| 采用或检查 iOS 26+ Liquid Glass | `swiftui-liquid-glass` | 需要整体页面实现时搭配 `swiftui-expert-skill` |
| 修 Swift 6.2 并发、`@MainActor`、`Sendable`、actor isolation 问题 | `swift-concurrency-expert` | 问题发生在 SwiftUI 状态层时搭配 `swiftui-expert-skill` |
| 运行 Hoop、安装到模拟器、截图或收集日志 | `ios-debugger-agent` | UI 修改完成后用于端到端验证 |
| Review 当前 diff 并清理可复用性、复杂度、效率问题 | `review-and-simplify-changes` | SwiftUI 专项问题再搭配 `swiftui-pro` |
| 写或优化 Supabase/Postgres SQL、schema、RLS、索引 | `supabase-postgres-best-practices` | Auth/权限相关改动需要同时检查客户端边界 |

## SwiftUI Skill 怎么选

SwiftUI 相关 Skill 有 6 个，职责有重叠但侧重点不同。

### `swiftui-expert-skill`

定位：SwiftUI 功能实现、重构和现代化改造的主力 Skill。

适合：

- 新建页面、组件或交互流程。
- 修改现有 SwiftUI 功能。
- 处理状态管理：`@State`、`@Binding`、`@StateObject`、`@ObservedObject`、`@Observable`、`@Bindable`。
- 调整 navigation、sheet、scroll、focus、animation、accessibility。
- 需要边读代码边落地修改。

典型提示：

```text
用 swiftui-expert-skill 实现活动详情页，遵循现有项目结构，状态管理清晰，完成后运行相关验证。
```

```text
用 swiftui-expert-skill 修这个 SwiftUI 页面里的状态同步问题，尽量保持 UI 行为不变。
```

### `swiftui-pro`

定位：SwiftUI 代码审查 Skill。

适合：

- Review 单个 SwiftUI 文件、PR 或当前 diff。
- 找 deprecated API、可访问性、性能、data flow、navigation、代码卫生问题。
- 需要“文件、行号、问题、before/after、优先级”的审查输出。

典型提示：

```text
用 swiftui-pro review HomeView.swift，重点看现代 API、accessibility 和性能，只列真实问题。
```

```text
用 swiftui-pro 对这次 SwiftUI 改动做合并前 review。
```

### `swiftui-ui-patterns`

定位：SwiftUI 组件和页面结构模式库。

适合：

- 设计 TabView、NavigationStack、sheet、form、list、grid、search、toolbar、deeplink。
- 需要组件级参考和示例，而不是泛泛的 SwiftUI 建议。
- 新页面开始前确定状态所有权、依赖注入、路由和 async loading 结构。

典型提示：

```text
用 swiftui-ui-patterns 设计这个页面的 NavigationStack、sheet 和 async loading 状态，然后再实现。
```

```text
这个页面要做搜索和列表筛选，先用 swiftui-ui-patterns 看下推荐结构。
```

### `swiftui-view-refactor`

定位：SwiftUI View 文件清理和结构重构。

适合：

- `body` 太长。
- 一个 View 混合了布局、业务逻辑、网络请求、格式化和路由。
- computed `some View` helper 太多，需要拆成专门 subview。
- 想统一到更清晰的 MV 风格，而不是无意义地新增 ViewModel。
- 调整 Observation 和 dependency injection。

典型提示：

```text
用 swiftui-view-refactor 重构 ActivityListView，目标是拆小 subview、减少 computed some View helper，保持行为不变。
```

### `swiftui-performance-audit`

定位：SwiftUI runtime 性能诊断。

适合：

- 列表滚动卡顿。
- 页面切换慢。
- CPU 或内存异常。
- 图片加载导致卡顿。
- 视图更新范围过大。
- 怀疑 `body` 中有重计算、identity 不稳定或 layout thrash。

典型提示：

```text
用 swiftui-performance-audit 检查这个列表为什么滚动卡顿，先做代码级诊断，必要时告诉我怎么用 Instruments 取证。
```

```text
用 swiftui-performance-audit review 当前 SwiftUI diff，重点看 view invalidation 和列表 identity。
```

### `swiftui-liquid-glass`

定位：iOS 26+ Liquid Glass 专项。

适合：

- 明确要求采用 Liquid Glass。
- 检查 `.glassEffect`、`GlassEffectContainer`、glass button style 是否用对。
- 检查 iOS 26 availability gating 和 fallback。

典型提示：

```text
用 swiftui-liquid-glass 把这个操作栏改成 iOS 26 Liquid Glass，并给旧系统保留 fallback。
```

```text
用 swiftui-liquid-glass review 这个页面的 glassEffect 用法是否正确。
```

注意：不要默认把普通 SwiftUI 页面改成 Liquid Glass。只有产品或任务明确要求时才使用。

## 非 SwiftUI Skill 怎么选

### `swift-concurrency-expert`

定位：Swift 6.2+ 并发诊断和修复。

适合：

- `Sendable` 编译错误。
- actor isolation warning/error。
- `@MainActor` 标注不清。
- UI-bound 类型跨 actor 访问。
- completion handler 迁移到 async/await。
- strict concurrency 开启后出现大量诊断。

典型提示：

```text
用 swift-concurrency-expert 修这些 Swift 6.2 concurrency 编译错误，优先采用最小行为变化。
```

### `ios-debugger-agent`

定位：Hoop iOS app 的模拟器端到端验证。

适合：

- 构建并启动 Hoop。
- UI 修改后截图验证。
- 检查模拟器上是否能正常 launch。
- 收集 app runtime log。
- 诊断安装、启动、截图、bundle id、模拟器相关问题。

默认使用：

```bash
scripts/build-and-launch.sh
```

典型提示：

```text
用 ios-debugger-agent 跑一次端到端启动验证，并把截图路径告诉我。
```

```text
这个页面改完后，用 ios-debugger-agent 在模拟器上启动并截图验证。
```

### `review-and-simplify-changes`

定位：当前 diff 的复用、质量、效率和清晰度检查。

适合：

- 改完代码后做收尾清理。
- 检查是否重复实现已有 helper。
- 简化控制流和冗余状态。
- 找明显可安全修复的代码质量问题。
- 在 PR 前做一次“不要引入没必要复杂度”的整理。

典型提示：

```text
用 review-and-simplify-changes 检查当前 diff，有高置信度的安全简化就直接修。
```

```text
用 review-and-simplify-changes review 当前改动，只报告问题，不改代码。
```

### `supabase-postgres-best-practices`

定位：Supabase/Postgres SQL、schema、RLS、索引和性能。

适合：

- 写 migration。
- 设计表结构、主键、外键、约束。
- 优化查询和索引。
- 检查 RLS policy 的安全和性能。
- 排查 N+1、分页、upsert、batch insert、锁和连接池问题。

典型提示：

```text
用 supabase-postgres-best-practices review 这个 migration，重点看 RLS、索引和外键约束。
```

```text
用 supabase-postgres-best-practices 优化这条查询，并说明需要什么索引。
```

## 推荐组合流程

### 新 SwiftUI 功能

1. `swiftui-ui-patterns`：先确定页面结构、路由、sheet、async state。
2. `swiftui-expert-skill`：实现功能。
3. `swiftui-pro`：做 SwiftUI 质量 review。
4. `ios-debugger-agent`：启动模拟器并截图验证。

示例：

```text
先用 swiftui-ui-patterns 设计 ActivityDetailView 的结构，再用 swiftui-expert-skill 实现。完成后用 swiftui-pro review，并用 ios-debugger-agent 启动截图验证。
```

### 复杂 View 清理

1. `swiftui-view-refactor`：拆分大 View、整理状态和依赖。
2. `swiftui-pro`：检查 refactor 后有没有 SwiftUI 风险。
3. `review-and-simplify-changes`：检查当前 diff 是否还有可安全简化的地方。

示例：

```text
用 swiftui-view-refactor 重构这个大 View，保持行为不变。完成后用 swiftui-pro 和 review-and-simplify-changes 做收尾检查。
```

### 性能问题

1. `swiftui-performance-audit`：先做代码级诊断，明确性能假设。
2. `swiftui-expert-skill`：修复状态、identity、布局、图片或计算问题。
3. `ios-debugger-agent`：运行 app，必要时截图或收集日志。

示例：

```text
用 swiftui-performance-audit 找出这个列表滚动卡顿的最可能原因，然后用 swiftui-expert-skill 修复高置信度问题。
```

### Swift 并发编译错误

1. `swift-concurrency-expert`：修 compiler diagnostics。
2. 如果改动影响 SwiftUI 状态层，再用 `swiftui-expert-skill` 检查 UI-bound 状态是否合理。
3. 运行相关 build。

示例：

```text
用 swift-concurrency-expert 修当前 Swift 6.2 并发错误，保持行为变化最小；如果涉及 SwiftUI 状态，再用 swiftui-expert-skill 检查。
```

### 发布或合并前收尾

1. `review-and-simplify-changes`：检查 diff 的复用、复杂度和效率。
2. `swiftui-pro`：如果改动包含 SwiftUI，做专项 review。
3. `ios-debugger-agent`：如果有 UI 影响，跑模拟器验证。

示例：

```text
用 review-and-simplify-changes 检查当前 diff。如果包含 SwiftUI，再用 swiftui-pro 做专项 review。UI 有变化的话用 ios-debugger-agent 验证。
```

## 避免误用

- 不要把 `swiftui-pro` 当成主要实现工具。它更适合 review。
- 不要把 `swiftui-performance-audit` 用在普通小 UI 改动上，除非有性能症状或高风险列表/动画/图片路径。
- 不要默认使用 `swiftui-liquid-glass`。只有明确要求 iOS 26+ Liquid Glass 时使用。
- 不要用 `swiftui-view-refactor` 做大范围行为改动。它适合行为保持的结构清理。
- 不要用 `review-and-simplify-changes` 做产品逻辑重写。它只适合高置信度、行为保持的简化。
- 不要把客户端 SwiftUI 权限判断当安全边界；数据库权限、RLS 和策略要用 `supabase-postgres-best-practices` 检查。

## 常用提示模板

Review SwiftUI：

```text
用 swiftui-pro review <文件或当前 diff>，重点看现代 API、状态管理、accessibility 和性能，只列真实问题。
```

实现 SwiftUI：

```text
用 swiftui-expert-skill 实现 <功能>。遵循现有项目结构，状态管理清晰，不引入第三方库，完成后运行相关验证。
```

重构 SwiftUI：

```text
用 swiftui-view-refactor 重构 <文件>。目标是拆小 subview、减少 body 复杂度、保持 UI 和行为不变。
```

性能诊断：

```text
用 swiftui-performance-audit 诊断 <页面/列表> 的 <卡顿/高 CPU/内存增长>，先给代码证据，再给修复路径。
```

并发修复：

```text
用 swift-concurrency-expert 修 <文件或当前 build> 的 Swift concurrency 诊断，优先最小安全修复。
```

数据库 review：

```text
用 supabase-postgres-best-practices review <SQL/migration/policy>，重点看索引、RLS、约束和查询性能。
```

模拟器验证：

```text
用 ios-debugger-agent 运行 Hoop，完成 build、launch 和 screenshot 验证，并报告截图路径。
```
