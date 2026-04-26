# Hoop 核心视频主流程改造计划

## 文档目标

这份 plan 文档用于把 [core-video-flow-redesign.md](/Users/mamba/workspace/ios-app/Hoop/docs/core-video-flow-redesign.md) 的产品设计，落成一份可以直接指导代码修改的实现计划。

它关注三件事：

- 设计目标如何映射到当前代码结构
- 需要新增或调整哪些模型、页面和状态
- 按什么顺序实施，才能在每个阶段都保持可运行、可验证

---

## 设计目标摘要

本次改造的最终目标不是“把首页做得更丰富”，而是把当前分散的流程收敛成一条明确主链路：

`拍视频 / 选视频 -> 上传 -> 出现在视频动态流 -> 用户手动触发当前视频 AI 分析 -> 结果回写同一条视频 -> 按日期持续沉淀`

对应到产品结构上，要完成下面三个核心变化：

- 核心内容单元从“上传记录”升级为“视频动态”
- 核心入口从“概览卡片 + 分散功能页”升级为“按日期分组的视频流”
- AI 从独立一级页面回归为“当前视频上的附着能力”

---

## 当前代码现状

结合现有代码，当前实现已经具备部分基础能力，但和目标态仍有明显差距。

### 已有能力

- 本地身份和成员体系已存在
  - [LocalUserProfile.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Users/Models/LocalUserProfile.swift)
  - [ProfileManager.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Users/ViewModels/ProfileManager.swift)
- 视频上传到 OSS 已存在
  - [OSSUploadService.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Core/Services/OSSUploadService.swift)
  - [TrainingUploadViewModel.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/ViewModels/TrainingUploadViewModel.swift)
- 本地上传记录已存在
  - [UploadedTrainingVideoRecord.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/Models/UploadedTrainingVideoRecord.swift)

### 当前结构性问题

- 一级导航仍是五个并列入口
  - [AppTab.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Shell/Models/AppTab.swift)
  - [AppShellView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Shell/Views/AppShellView.swift)
- 首页 [HomeView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Home/Views/HomeView.swift) 以静态概览和演示文案为主，没有真实视频流
- 训练页 [TrainingView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/Views/TrainingView.swift) 承担上传，但仍是“训练计划 + 今日上传”结构
- AI 页 [AIAnalysisView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/AI/Views/AIAnalysisView.swift) 是独立展示页，没有绑定具体视频
- `UploadedTrainingVideoRecord` 只有上传日志语义，无法承载视频动态、分析状态和摘要

---

## 实现范围

本轮 plan 以“先把主链路跑通”为原则，范围分为必须完成和后续增强两层。

### 本轮必须完成

- 新的动态首页骨架
- 按日期分组的视频流
- 上传后立即写入并显示在视频流
- 每条视频具备 AI 状态
- AI 入口从独立 Tab 移回视频卡片或视频详情
- 零数据状态替换当前演示数据
- 导航收敛为 `动态 + 我的`

### 可延后增强

- 视频缩略图生成
- 完整 AI 结果结构化建模
- 同动作历史对比策略
- 家长端的重点跟进标记
- 分页加载和更长时间线

---

## 目标架构

## 1. 导航结构

目标导航结构：

- `动态`
- `我的`

实现原则：

- `动态` 成为默认首页，承接视频流、上传入口、AI 分析入口
- `我的` 保留身份、成员管理、设置等内容
- 原 `Training`、`Match`、`AI` 不再保留为一级 Tab

代码影响：

- 精简 [AppTab.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Shell/Models/AppTab.swift)
- 重写 [AppShellView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Shell/Views/AppShellView.swift) 的 `TabView`

## 2. 核心数据模型

建议引入新的展示核心实体 `TrainingVideoPost`，让业务中心从“上传记录”升级为“视频动态”。

建议第一阶段字段：

```swift
@Model
final class TrainingVideoPost {
    @Attribute(.unique) var id: String
    var playerID: String
    var objectKey: String
    var fileName: String
    var createdDay: Date
    var uploadedAt: Date
    var fileSize: Int64

    var contentTypeRawValue: String
    var drillName: String?
    var note: String?
    var analysisStatusRawValue: String
    var latestAnalysisSummary: String?
    var latestRecommendation: String?
    var baselineVideoPostID: String?
}
```

建议同时新增两个轻量枚举：

- `TrainingVideoContentType`
  - `training`
  - `match`
- `VideoAnalysisStatus`
  - `idle`
  - `processing`
  - `completed`
  - `failed`

阶段策略：

- 第一阶段可以先把“最新分析结果”直接挂在 `TrainingVideoPost`
- 第二阶段再决定是否拆出 `VideoAnalysisRecord`

代码建议位置：

- `Hoop/Features/Training/Models/TrainingVideoPost.swift`
- `Hoop/Features/Training/Models/VideoAnalysisStatus.swift`
- `Hoop/Features/Training/Models/TrainingVideoContentType.swift`

其中 `contentTypeRawValue` 不是预留字段，而是要真正承接被移除一级导航后的内容来源：

- `training`
  - 来自球员端主动上传的训练视频
  - 默认复用当前训练视频上传链路
- `match`
  - 来自比赛视频上传
  - 第一阶段可先复用同一套 OSS 上传能力和本地写入逻辑
  - 区别只体现在写入 `TrainingVideoPost` 时 `contentType = .match`

这意味着“比赛并入动态”不是只改展示，而是要让比赛内容和训练内容共用同一条入库路径，只在内容类型、卡片文案和后续筛选上区分。

## 3. 页面结构

### 动态首页

动态首页需要同时替代当前：

- `HomeView`
- `TrainingView` 的主流程职责
- `MatchCenterView` 的一级导航位置
- `AIAnalysisView` 的一级导航位置

推荐新结构：

- 顶部身份信息
- 主 CTA
  - 球员端：上传/拍摄视频
  - 家长端：成员筛选或成员管理入口
- 日期分组视频流
- 零数据状态

家长端必须保留与球员端一致的“日期 -> 视频卡片”骨架，差异只体现在顶栏过滤态和卡片上的成员信息。

#### 家长端成员过滤

这是设计要求的一部分，不能只停留在文案层。

第一阶段建议支持以下过滤状态：

- `全部成员`
- `单个成员`

对应实现建议：

- 顶部提供一个轻量筛选控件
  - 可先用 `Menu`、`Picker` 或分段控件，不要求第一版做复杂筛选器
- 家长端进入动态页时默认展示 `全部成员`
- 选择单个成员后：
  - 日期分组规则保持不变
  - 只过滤该成员的 `TrainingVideoPost`
  - 空状态文案切换为“该成员还没有视频”

验收上必须能回答两个问题：

- 家长是否可以在“全家混排流”和“单个成员流”之间切换
- 切换后页面骨架是否保持一致，只变化数据范围

### 视频卡片

卡片最少应展示：

- 成员信息
- 上传时间
- 内容类型
- 文件名或动作标题
- AI 状态
- 最新 AI 摘要
- `开始 AI 分析` 或 `重新分析`

### 视频详情页

建议在第一阶段就预留详情页入口，即便内容先保持轻量。

第一阶段详情页最少展示：

- 视频基础信息
- AI 状态
- 最新摘要
- 最新建议
- 触发分析按钮

代码建议位置：

- `Hoop/Features/Feed/Views/VideoFeedView.swift`
- `Hoop/Features/Feed/Views/Components/TrainingVideoPostCard.swift`
- `Hoop/Features/Feed/Views/TrainingVideoPostDetailView.swift`

如果当前不想新开 `Feed` 模块，也可以先在 `Home` 模块内落地，但建议命名上避免继续沿用“Home 概览页”语义。

---

## 数据迁移策略

当前上传流程已经落在 `UploadedTrainingVideoRecord`，因此 plan 里必须明确迁移方式，避免后续实现中一边保留旧模型、一边又新写一套 UI。

### 推荐方案

采用“新模型接管，旧模型逐步退出”的方式。

#### 第一阶段

- 新增 `TrainingVideoPost`
- 上传完成后，优先写入 `TrainingVideoPost`
- 现有 `UploadedTrainingVideoRecord` 暂时保留，避免一次性删改过大
- 动态首页只读取 `TrainingVideoPost`
- 训练视频与比赛视频都要写入 `TrainingVideoPost`

#### 兼容策略

如果担心已有本地测试数据丢失，可在第一阶段增加一次性迁移逻辑：

- App 启动或动态页首次进入时
- 读取 `UploadedTrainingVideoRecord`
- 对尚未迁移的数据生成 `TrainingVideoPost`
- 成功后不再依赖旧表渲染 UI

#### 第二阶段

- 所有读写都迁移到 `TrainingVideoPost`
- 删除 `UploadedTrainingVideoRecord` 在页面层的依赖
- 评估是否保留旧模型仅做兼容，或直接移除

### 不建议的方案

- 长期让 UI 同时查询两个模型并做拼接
- 继续在 `UploadedTrainingVideoRecord` 上硬加大量展示字段

这样会让“上传日志”和“视频动态”语义混杂，后续 AI、详情、对比都很难继续演进。

---

## 按模块改造计划

## 阶段 1：建立新的数据主干

目标：

- 让“视频动态”成为新的真实数据来源
- 上传流程写入新模型

修改点：

1. 新增 `TrainingVideoPost`
2. 新增 `VideoAnalysisStatus`
3. 新增 `TrainingVideoContentType`
4. 调整 SwiftData schema 注册
   - [HoopApp.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/App/HoopApp.swift)
   - [AuthRootView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Auth/Views/AuthRootView.swift)
   - [SignInView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Auth/Views/SignInView.swift)
   - [ProfileGateView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Users/Views/ProfileGateView.swift)
   - [OnboardingCreateProfileView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Users/Views/OnboardingCreateProfileView.swift)
5. 调整 [TrainingUploadViewModel.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/ViewModels/TrainingUploadViewModel.swift)
   - 上传成功后写入 `TrainingVideoPost`
   - 默认 `analysisStatus = .idle`
   - 默认 `contentType = .training`
6. 为后续比赛内容接入预留统一写入接口
   - 训练上传和比赛上传共用写入 `TrainingVideoPost` 的逻辑
   - 不允许训练、比赛各自落不同本地模型

验收标准：

- 上传视频后，本地可产生 `TrainingVideoPost`
- 新记录具备稳定的 `createdDay`
- 新记录的默认分析状态为 `idle`
- 同一模型可承接训练和比赛两类视频内容

## 阶段 2：把首页改造成动态页

目标：

- 用真实视频流取代静态概览
- 先完成球员端和家长端的零数据与基础列表

修改点：

1. 重写 [HomeView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Home/Views/HomeView.swift)
2. 让首页直接查询 `TrainingVideoPost`
3. 构建按日期分组逻辑
   - 日期组按新到旧
   - 组内视频按 `uploadedAt` 倒序
4. 替换所有演示数据卡片
   - 连续打卡
   - 成长值
   - 最近一次分析
   - 本周观察重点
   - 默认训练任务
5. 增加真实空状态
   - 球员端空状态
   - 家长端空状态
6. 增加家长端成员过滤
   - 默认 `全部成员`
   - 支持切换到单个成员
   - 过滤后仍按日期分组展示

验收标准：

- 新用户无视频时，不再出现任何伪造统计
- 上传后的视频能在“今天”分组看到
- 家长端可看到全家视频流或家庭空状态
- 家长端可在全家流与单成员流之间切换

## 阶段 3：把上传入口并回动态页

目标：

- 用户不再需要切到训练页才能完成核心操作

修改点：

1. 将 [TrainingView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/Views/TrainingView.swift) 的上传能力迁入动态页
2. 保留 `PhotosPicker` 触发方式
3. 让球员端顶部 CTA 直接触发上传
4. 上传完成后保持在当前页，并立即看到新视频卡片
5. 移除“训练计划 + 动作清单 + 今日上传”的旧主结构
6. 为比赛内容提供并入动态页的入口策略
   - 第一阶段允许训练和比赛先共用同一个上传入口
   - 如果需要区分，可在上传前增加“训练 / 比赛”内容类型选择
   - 无论从哪个入口进入，最终都写入 `TrainingVideoPost`

验收标准：

- 球员端在动态页即可完成上传
- 上传后无需切页即可看到结果
- 核心主链路从“进入训练页上传”变为“在动态页上传”
- 比赛内容不依赖独立 Tab，也能进入动态流

## 阶段 4：将 AI 挂回视频卡片和详情页

目标：

- AI 不再作为一级页面存在
- 每条视频具备自己的分析状态和触发入口

修改点：

1. 新增视频卡片上的 AI 状态展示
2. 新增视频详情页
3. 在卡片和详情页增加操作入口
   - `开始 AI 分析`
   - `重新分析`
4. 新增一个本地占位的分析动作链路
   - 点击后先将状态设为 `processing`
   - 完成后回写 `latestAnalysisSummary`
   - 如尚未接入真实 AI，可先以受控 mock 或 TODO 占位，但文案必须真实表明“尚未接入正式分析”
5. 下线或弱化 [AIAnalysisView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/AI/Views/AIAnalysisView.swift)

验收标准：

- 每条视频都能显示自己的 AI 状态
- 用户可以针对单条视频触发分析
- 结果会回到原视频卡片，而不是跳到独立页面

## 阶段 5：收敛导航结构

目标：

- 产品信息架构与设计文档一致

修改点：

1. 精简 [AppTab.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Shell/Models/AppTab.swift)
   - 保留 `feed`
   - 保留 `profile`
2. 调整 [AppShellView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Shell/Views/AppShellView.swift)
3. 移除 `Training`、`Match`、`AI` 一级 Tab
4. 评估以下页面的去留
   - `TrainingView`
   - `MatchCenterView`
   - `AIAnalysisView`
5. 确认比赛入口迁移完成
   - 删除比赛一级 Tab 前，比赛视频必须已经能够从动态页进入统一流

验收标准：

- 主导航只剩 `动态` 和 `我的`
- 主要用户链路可以在 `动态` 内闭环完成
- 删除比赛 Tab 后，比赛内容仍然可新增、可查看、可在动态中区分

## 阶段 6：增强项

目标：

- 为后续真实 AI 和历史对比打基础

增强内容：

1. 引入 `VideoAnalysisRecord`
2. 支持重新分析历史记录
3. 支持优先查找“最近同动作视频”作为对比基线
4. 增加家长端“待跟进”标识
5. 增加视频缩略图与更完整的详情信息

---

## 页面状态定义

为了避免实现阶段再次回到“演示页”，页面状态必须先定义清楚。

### 球员端动态页

应支持以下状态：

1. 从未上传过视频
2. 当天无视频，但历史有视频
3. 当天已有视频，且全部未分析
4. 当天已有视频，部分分析中
5. 当天已有视频，部分分析完成

### 家长端动态页

应支持以下状态：

1. 家庭内没有任何球员
2. 有球员，但没有任何视频
3. 有视频，但当天没有新内容
4. 有视频，且可以按日期查看混排内容

### 视频卡片

每条卡片应支持以下 AI 状态：

- `idle`
- `processing`
- `completed`
- `failed`

每种状态的展示规则要固定：

- `idle`：展示“开始 AI 分析”
- `processing`：展示进行中态，不允许重复触发
- `completed`：展示摘要和“重新分析”
- `failed`：展示失败提示和重试入口

---

## 查询与排序规则

动态流的查询规则建议统一封装，避免分散在多个 View 里各写一套过滤。

### 统一规则

- 分组键使用 `createdDay`
- `createdDay` 统一取本地自然日开始时间
- 顶层日期组按降序
- 日期组内视频按 `uploadedAt` 降序

### 角色差异

- 球员端：仅查询当前球员的 `TrainingVideoPost`
- 家长端：默认查询所有球员的 `TrainingVideoPost`
- 家长端选择单个成员后：仅查询该成员的 `TrainingVideoPost`

### 内容类型差异

- 默认动态流同时展示 `training` 与 `match`
- 卡片上使用内容类型 badge 区分
- 如后续增加筛选，必须建立在统一 `TrainingVideoPost` 流之上，而不是恢复独立比赛页

### 建议

后续可把查询和分组整理成独立的 feed 组装层，例如：

- `VideoFeedSection`
- `VideoFeedBuilder`

但第一阶段不必为了抽象而抽象，先保证逻辑集中、命名清晰即可。

---

## 风险与决策点

## 1. 是否保留旧模型

建议：

- 第一阶段保留 `UploadedTrainingVideoRecord`
- 第二阶段开始停止页面读取
- 第三阶段再决定是否彻底删除

原因：

- 可以降低一次性改动风险
- 可以保留现有上传链路的回退空间

## 2. 是否马上拆出 `VideoAnalysisRecord`

建议：

- 不在第一阶段强制拆表
- 先把“最新状态 + 最新摘要”挂在 `TrainingVideoPost`

原因：

- 当前主要目标是完成主链路闭环
- 提前拆复杂分析模型会拉长实现周期

## 3. 是否继续保留 Training 页面

建议：

- 改造完成后不再保留为一级入口
- 如果还需临时保留，可降级为内部过渡页，而不是用户主流程页

## 4. 比赛入口何时移除独立页面

建议：

- 只有在比赛视频已经能从动态页进入 `TrainingVideoPost` 后，才能移除 `Match` 一级入口

原因：

- 否则会出现设计上删了比赛 Tab，但产品上没有真实比赛内容入口的断层

---

## 具体实施顺序

推荐按下面顺序推进，避免 UI 先改完但数据不通，或数据改完却没有真实页面承接。

1. 新增 `TrainingVideoPost` 和相关枚举，接入 SwiftData schema。
2. 修改统一写入链路，让训练/比赛上传都写入 `TrainingVideoPost`。
3. 重写动态首页的数据查询、零数据状态和家长端成员过滤，但先不动导航。
4. 把上传入口迁到动态页，保证主链路在一个页面里闭环。
5. 确认比赛内容已经能从动态页进入统一流，再移除比赛一级入口。
6. 为视频卡片增加 AI 状态和视频详情页。
7. 去掉独立 `AI`、`Training`、`Match` 一级入口，收敛为 `动态 + 我的`。
8. 再做同动作对比、分析记录、缩略图等增强项。

---

## 验收清单

代码修改完成后，至少需要按下面清单验证。

### 功能验证

- 球员端首次进入时，动态页为空状态，无演示数据
- 球员端可直接在动态页选择视频上传
- 上传成功后，新视频出现在今天分组
- 家长端能看到家庭维度的视频流或真实空状态
- 家长端可切换全部成员与单个成员视角
- 比赛视频可不依赖独立 Tab 进入动态流
- 每条视频都具备 AI 状态展示
- AI 操作绑定单条视频，而不是跳转独立页面
- 主导航收敛为 `动态 + 我的`

### 回归验证

- 本地身份选择仍可正常工作
- 成员管理入口仍可从 `我的` 进入
- 视频上传到 OSS 不受本次改造影响
- SwiftData 新模型不会导致启动时崩溃

### 建议执行命令

- 构建验证：使用仓库现有 iOS 构建流程
- 联调验证：必要时运行 `scripts/build-and-launch.sh`

---

## 文档与代码同步要求

实施过程中，如果实际代码方案偏离这份 plan，需要同步更新本文档，尤其是下面几类变化：

- 核心实体命名变化
- AI 状态模型变化
- 导航结构变化
- 迁移方案变化
- 阶段边界变化

这样这份 plan 才能持续作为后续代码修改的依据，而不是一次性草稿。
