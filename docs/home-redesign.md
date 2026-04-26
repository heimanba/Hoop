# Hoop 首页终态设计

## 文档目标

这份文档定义首页的终态设计方向，不是局部调整，而是从产品哲学出发重新推导首页应该是什么。

核心问题只有一个：**首页现在是"工具优先"，终态应该是"内容优先"。**

---

## 先说结论

首页终态的三句话：

1. 打开首页，第一眼看到的是**视频动态流**，不是上传按钮。
2. 上传入口是导航栏右上角**一个"+"按钮**，视频选完之后再打标签。
3. 球员和家长看到**同一套页面骨架**，家长多一排成员筛选 chip。

---

## 一、问题诊断

### 1. 两个几乎相同的页面并存

`HomeView`（动态 Tab）和 `VideoFeedView`（存在于 `Feed/` 下、未接入 Tab）功能高度重叠：

- 都有 identityHeader 卡片
- 都有上传按钮区块
- 都有按日期分组的视频列表
- 都有成员过滤逻辑

这不是技术债，而是信息架构没想清楚的直接体现。两个页面争夺"谁才是主链路"这个问题没有回答。

### 2. 上传入口占据首页核心位置

`primaryActionCard` 是首页第二个区块，视觉权重仅次于 identityHeader，内含两个全宽 `PhotosPicker` 按钮。

上传是低频操作——每次训练或比赛上传 1 次，一天最多 2～3 次。但页面把它设计成了主角，把用户真正关心的视频动态挤到了第三区块。

这是优先级倒置。

### 3. 上传前强制做类型决策

用户点击上传时，必须先决定"这是训练视频还是比赛视频"。

但这两个按钮触发的是完全相同的操作：打开相册，选一个视频文件。区别只是 `contentType` 这一个元数据字段。在用户还没选视频的时候就要求做这个决策，制造了一个没有实际意义的摩擦点。

正确的时机是选完视频之后，在确认上传前轻量打标签。

### 4. identityHeader 卡片无实际信息价值

卡片内容：头像 Emoji + 姓名 + "我的视频" + 一句副标题。

用户打开 app 时已经知道自己是谁。这张卡片在解释 app，不在传递信息。一个不需要用文字解释自己的产品，才是真正设计好的产品。

### 5. 两条 AI 分析路径并存，职责混乱

当前存在两个独立的分析入口：

- **首页列表行内「分析」按钮** → `HomeViewModel.startAnalysis()` → `AIAnalysisService.analyzeVideo()`（一次性结构化输出）
- **详情页 AI 教练** → `generateInitialConversation()` → 标签式对话分析

两套逻辑维护成本高，用户也会困惑"首页点了分析"和"详情页再分析"有什么区别。

---

## 二、设计原则

| 原则 | 当前问题 | 终态做法 |
|------|----------|----------|
| 内容是主角 | 打开首页先看到两张功能卡片，视频在第三区块 | 打开首页直接看到视频 feed |
| 操作入口隐形化 | 两个全宽上传按钮撑满页面中心 | 单一"+"按钮收进导航栏右上角 |
| 减少上传摩擦 | 上传前先选类型，再选视频 | 先选视频，选完后轻量打标签 |
| 角色差异最小化 | 球员和家长看到结构完全不同的页面 | 同一份 feed 骨架，家长多一条成员筛选 chip |
| 界面不解释自己 | 每张卡片都有副标题解释它的作用 | 删除所有功能性解释文字，界面自我说明 |
| AI 入口统一 | 两套分析路径并存 | 只保留详情页 AI 教练，删除首页行内分析按钮 |

---

## 三、终态信息架构

```
AppShell
├── 动态 Tab
│   └── HomeView（重写）
│       ├── 导航栏：标题 + [+] 或 [人员管理]
│       ├── 成员筛选 chip（仅家长视角，有成员时显示）
│       └── 视频 feed（按日期分组，直接渲染，无外层 HoopCard）
└── 我的 Tab
    └── ProfileView（不变）
```

Tab 层保持不变。`VideoFeedView` 废弃，逻辑合并至新 `HomeView` 后删除。

---

## 四、HomeView 终态结构

### 4.1 导航栏

```
球员视角:
┌─────────────────────────────────┐
│  ⛹️ 小明的视频              [+] │
└─────────────────────────────────┘

家长视角:
┌─────────────────────────────────┐
│  家庭视频              [👥管理] │
└─────────────────────────────────┘
```

实现要点：
- 去掉 `navigationTitle("首页")`，改为 `.toolbar` 中的 `.principal` item 展示当前成员名
- 球员视角右上角：`+` 按钮（`ToolbarItem(placement: .topBarTrailing)`），触发 `PhotosPicker`
- 家长视角右上角：`person.2.fill` 图标，点击打开 `UserManagementView`（现有 sheet 逻辑不变）
- 上传进行中时，"+"按钮变为不可点击状态

### 4.2 成员筛选 chip（仅家长视角）

家长视角且存在球员成员时，feed 顶部显示一排横向可滚动 chip：

```
┌─────────────────────────────────────────┐
│  [全部]  [⛹️ 小明]  [🏀 小红]  →      │
└─────────────────────────────────────────┘
```

- 替换现有 `Picker(.menu)` 下拉选择器
- 映射至现有 `selectedPlayerFilterID` 状态，filter 逻辑不变
- 选中项高亮（`brand` 色背景），其余灰色
- 无成员时整行不显示

### 4.3 视频 feed 主体

```
今天
┌─────────────────────────────────────────┐
│ [缩略图]  三分线投篮训练                 │
│           2小时前 · 训练                 │
│           "重心不稳，左脚落地偏早"      │
│           [已分析 ✓]                    │
└─────────────────────────────────────────┘

昨天
┌─────────────────────────────────────────┐
│ [缩略图]  比赛第三节               小明 │  ← 家长视角显示成员名
│           昨天 18:30 · 比赛             │
│           [待分析]                      │
└─────────────────────────────────────────┘
```

实现要点：
- 复用现有 `TrainingVideoPostCard` 组件（`Feed/Views/` 目录已有）
- 按 `createdDay` 分组，复用 `VideoFeedSection` 日期分组逻辑（来自 `VideoFeedView`）
- `ScrollView` 直接包含分组列表，**不再有外层 `HoopCard` 包裹**
- 日期标题只显示文字（今天 / 昨天 / 完整日期），删除 `SectionHeader` 的副标题（"N 条视频"）
- `TrainingVideoPostCard` 在家长视角下显示成员头像 Emoji + 名字

### 4.4 空状态

**球员视角，无视频：**
```
┌─────────────────────────────────────────┐
│                                         │
│         🏀                              │
│   还没有视频                            │
│   上传第一条训练或比赛视频，            │
│   开始积累成长记录。                    │
│                                         │
└─────────────────────────────────────────┘
```

**家长视角，无球员成员：**
```
┌─────────────────────────────────────────┐
│   去「我的」添加球员成员后，            │
│   这里会显示家庭视频动态。              │
└─────────────────────────────────────────┘
```

- 不显示任何解释性副标题或 `StatusBadge`
- 不显示上传按钮（空状态下不需要，导航栏已有"+"）

### 4.5 上传进度

上传进行中时，在 feed 顶部插入一条进度行（不遮挡内容）：

```
┌─────────────────────────────────────────┐
│  ████████░░░░  上传中 64%               │
└─────────────────────────────────────────┘
```

- 细进度条 + 状态文字，高度约 44pt，轻量不打断浏览
- 上传完成后进度行消失，新视频卡片出现在当天分组顶部
- 失败时进度行变为错误提示，带"重试"按钮

---

## 五、上传流程终态

### 当前流程

```
首页 → 选[训练/比赛]按钮 → PhotosPicker → 上传
         ↑
    在选视频之前就要做这个决策
```

### 终态流程

```
导航栏 [+] → PhotosPicker 打开 → 选视频
                                     ↓
                              底部 sheet 弹出：
                              ┌─────────────────────┐
                              │ 这是什么视频？        │
                              │ [训练]  [比赛]        │
                              │                       │
                              │ 训练名称（可选）      │
                              │ ___________________   │
                              │                       │
                              │      [上传]           │
                              └─────────────────────┘
                                     ↓
                              上传进行中（inline 进度）
```

**关键改动：**
- 一个 `PhotosPicker`，绑定单一 `selectedVideoItem: PhotosPickerItem?`
- 选完视频后弹出 `UploadTagSheet`（新组件）
- sheet 内：类型 chip（默认选中"训练"）+ 可选填训练名称（映射到 `TrainingVideoPost.drillName`）
- 确认后调用现有 `uploadViewModel.uploadVideo(from:userID:contentType:context:)` — **上传核心逻辑完全不变**
- 用户可以点"跳过"直接上传（默认 `.training`）

`UploadTagSheet` 是纯展示层，不包含上传逻辑，只负责收集 `contentType` 和 `drillName` 然后回调。

---

## 六、AI 分析入口统一

### 当前两条路径

```
首页列表行 [分析] 按钮
    └─→ HomeViewModel.startAnalysis()
        └─→ AIAnalysisService.analyzeVideo()
            └─→ 一次性结构化输出（headline + summary + focus + recommendation）

详情页 AI 教练
    └─→ AIAnalysisService.generateInitialConversation()
        └─→ 标签式对话分析（支持追问）
```

两套路径产生的数据都写回 `TrainingVideoPost` 的同一组字段（`latestAnalysisHeadline` 等），但调用路径、Prompt 结构、分析深度完全不同，维护成本高。

### 终态：只保留详情页 AI 教练

**列表行改动：**
- 移除行内「分析」/ 「重试」按钮
- 只展示 `analysisStatus` badge（待分析 / 分析中 / 已分析 / 分析失败）
- `analysisStatus == .idle` 时 badge 可点击，点击跳转详情页，详情页自动触发首轮分析

**删除内容：**
- `HomeViewModel.startAnalysis()` 方法
- `HomeViewModel.runAnalysis()` 方法
- 列表行中 `onRunAnalysis` 回调及相关 UI

**保留内容：**
- `HomeViewModel.deletePost()` — 删除逻辑不变
- `HomeViewModel.migrateLegacyRecordsIfNeeded()` — 迁移逻辑不变

---

## 七、要删除 / 合并的内容

| 内容 | 当前位置 | 终态处理 |
|------|----------|----------|
| `identityHeader` 计算属性 | `HomeView` | 删除 |
| `primaryActionCard` 计算属性 | `HomeView` | 删除，上传入口移至导航栏 |
| `videoActivitySection` 外层 `HoopCard` 包裹 | `HomeView` | 删除包裹层，feed 直接渲染 |
| `memberFilterSection`（`Picker(.menu)`） | `HomeView` | 替换为 `MemberFilterChips` 组件 |
| 所有 `SectionHeader` 副标题文字 | `HomeView` | 删除，只保留日期标题 |
| `HomeViewModel.startAnalysis` | `HomeViewModel` | 删除 |
| `HomeViewModel.runAnalysis` | `HomeViewModel` | 删除 |
| `HomeMoreVideoRow` 中 `onRunAnalysis` 入口及相关 UI | `HomeView` | 删除 |
| `VideoFeedView` | `Feed/Views/VideoFeedView.swift` | 合并逻辑至新 `HomeView` 后删除 |
| `SelectedTrainingVideo`（`HomeView` 内的副本） | `HomeView` 末尾 | 合并为一处，或移至共享文件 |

---

## 八、新增组件

### `UploadTagSheet`
**位置：** `Hoop/Features/Home/Views/Components/UploadTagSheet.swift`

职责：收集上传前的元数据，不包含上传逻辑。

```
输入：
  - selectedVideoItem: PhotosPickerItem（已选中的视频）
  - onConfirm: (TrainingVideoContentType, String?) -> Void

UI：
  - 类型 chip 选择（训练 / 比赛，默认训练）
  - drillName 文本输入框（可选，placeholder "训练名称"）
  - 确认按钮 / 取消
```

### `MemberFilterChips`
**位置：** `Hoop/Features/Home/Views/Components/MemberFilterChips.swift`

职责：横向可滚动的成员筛选 chip 组，仅在家长视角且有球员成员时显示。

```
输入：
  - profiles: [LocalUserProfile]（只传 role == .player 的）
  - selectedID: Binding<String>（对应 selectedPlayerFilterID）

输出：
  - 选中变化时更新 selectedID binding
```

---

## 九、受影响的文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| [`Hoop/Features/Home/Views/HomeView.swift`](../Hoop/Features/Home/Views/HomeView.swift) | 重写 | 去掉三张卡片，实现新 feed 骨架 |
| [`Hoop/Features/Home/ViewModels/HomeViewModel.swift`](../Hoop/Features/Home/ViewModels/HomeViewModel.swift) | 删减 | 删除 `startAnalysis` / `runAnalysis`，保留删除和迁移 |
| [`Hoop/Features/Feed/Views/VideoFeedView.swift`](../Hoop/Features/Feed/Views/VideoFeedView.swift) | 废弃删除 | 逻辑合并至新 `HomeView` |
| [`Hoop/Features/Shell/Views/AppShellView.swift`](../Hoop/Features/Shell/Views/AppShellView.swift) | 微调 | Tab 标题对齐（视具体文案决定） |
| `Hoop/Features/Home/Views/Components/UploadTagSheet.swift` | 新增 | 上传标签浮层 |
| `Hoop/Features/Home/Views/Components/MemberFilterChips.swift` | 新增 | 横向成员筛选 chip |

---

## 十、不在本次范围内的内容

以下内容当前文档不涉及，留待后续迭代：

- **详情页 `TrainingVideoPostDetailView` 结构** — 保持现有 AI 教练会话设计不变
- **`TrainingVideoPost` 数据模型** — 字段不变，`contentType` 仍在上传时写入
- **OSS 上传服务** — `OSSUploadService` 和 `TrainingUploadViewModel` 核心逻辑不变
- **`AIAnalysisService`** — prompt 结构不变，`contentType` 仍作为上下文传入
- **`VideoAnalysisTag`** — 按 `contentType` 返回标签子集的逻辑不变
- **`ProfileView`（我的 Tab）** — 不变
- **认证和用户管理流程** — 不变

---

## 附：关键决策记录

**Q：为什么不用微信式"+"菜单让用户在上传前选训练/比赛？**

微信的"+"菜单选项（图片、文件、位置）是操作路径完全不同的分叉，值得在菜单层分流。训练和比赛视频的上传操作完全相同，区别只是一个元数据标签，放在菜单层分叉会让菜单的权重超过它应有的位置。正确的时机是选完视频之后轻量打标签。

**Q：为什么删除首页列表行内的"分析"按钮？**

首页行内分析（`analyzeVideo`）和详情页 AI 教练（`generateInitialConversation`）是两套不同深度的分析接口，对用户来说都叫"AI 分析"但产出完全不同，会制造困惑。统一入口到详情页，减少维护两套逻辑的成本，同时引导用户进入更深的 AI 教练体验。

**Q：为什么家长视角不显示上传按钮？**

家长是观察者，不是内容生产者。家长上传视频意味着"代替孩子上传"，这个场景在家长视角下没有清晰的身份归属（视频属于谁？）。如需支持，应在球员成员管理流程中解决，而不是在首页共用上传按钮。
