# Hoop AI 分析设计稿

## 文档目标

这份文档用于明确 Hoop 当前“AI 分析部分”的下一步设计与接入方案，目标是把现有本地占位分析升级成一条真实、可迭代、便于 review 的产品链路。

本稿聚焦以下问题：

1. 如何把 `docs/reference/qwen36.md` 里的 Qwen3.6 视频理解能力接入现有 iOS 项目
2. 如何在不大改当前 SwiftData 结构的前提下，细化 AI 分析结果
3. 如何让首页、动态页、详情页对分析状态和结果的表达更清晰
4. 如何控制第一阶段改造范围，避免把项目拖进过重的后端或任务系统设计

---

## 当前现状

当前项目里与 AI 分析直接相关的代码主要有：

- [HomeView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Home/Views/HomeView.swift)
- [VideoFeedView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Feed/Views/VideoFeedView.swift)
- [TrainingVideoPostDetailView.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Feed/Views/TrainingVideoPostDetailView.swift)
- [TrainingVideoPost.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/Models/TrainingVideoPost.swift)
- [VideoAnalysisStatus.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Features/Training/Models/VideoAnalysisStatus.swift)
- [OSSUploadService.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Core/Services/OSSUploadService.swift)
- [qwen36.md](/Users/mamba/workspace/ios-app/Hoop/docs/reference/qwen36.md)

当前行为可以概括为：

1. 用户上传视频后，视频被存成 `TrainingVideoPost`
2. 首页和动态页可以点击“开始 AI 分析”
3. 当前“分析”只是本地延时后写入 mock 文案
4. 详情页已经有比较完整的 AI 模块结构，但承载的仍是占位内容

也就是说，目前产品骨架已经在了，差的是“真实分析能力”和“更细的结果表达”。

---

## 设计目标

第一阶段 AI 分析改造建议只做三件事：

1. 接入真实 Qwen3.6 视频分析 API
2. 把分析结果从“摘要 + 建议”细化为更稳定的结构化结果
3. 让页面明确区分“状态”、“结果”、“失败原因”和“下次动作”

本阶段不建议引入：

- 服务端任务队列
- 分析历史版本管理
- 复杂评分体系
- 多模型路由
- 后台轮询任务中心

原因很简单：现在项目已经有可用的视频详情和状态展示骨架，最优策略是先把单条视频分析做通，再看是否需要扩展成更大的 AI 平台能力。

---

## 产品定位

Hoop 的 AI 分析不应只返回“这个视频里发生了什么”，而应该回到训练产品语境里，输出用户真正能用的内容：

1. 这条视频最值得注意的动作结论是什么
2. 当前最该盯住的 2 到 3 个观察点是什么
3. 下一次拍摄或训练应该怎么做

所以第一阶段建议把 AI 输出设计成四层：

1. `headline`
   一句短标题，适合在卡片和详情页顶部快速浏览
2. `summary`
   对本条视频的核心观察总结
3. `focus_points`
   2 到 3 条最重要的观察点
4. `recommendation`
   直接可执行的下一步建议

相比当前只有“摘要 + 建议”，这种结构更适合后续扩展，也更适合 UI 分层。

---

## 接入原则

### 1. 优先复用现有 OSS 链路

当前视频已经上传到 OSS，并且 [OSSUploadService.swift](/Users/mamba/workspace/ios-app/Hoop/Hoop/Core/Services/OSSUploadService.swift) 能生成播放地址。

这意味着 AI 分析不需要重新上传文件，也不需要先做本地转 base64。第一阶段应直接复用远程视频 URL，把 OSS 地址作为 Qwen 的视频输入。

这样做的好处：

- 不引入额外上传步骤
- 不增加 App 端内存压力
- 和当前视频播放能力共享同一份视频源

### 2. 采用 OpenAI 兼容接口

根据 [qwen36.md](/Users/mamba/workspace/ios-app/Hoop/docs/reference/qwen36.md)，Qwen3.6 支持 OpenAI 兼容模式，视频输入时消息内容中使用 `video_url`。

第一阶段建议使用：

- Base URL: `https://dashscope.aliyuncs.com/compatible-mode/v1`
- Endpoint: `/chat/completions`
- Model: `qwen3.6-plus`

原因：

- 接口形态简单，适合 App 端快速落地
- 后续如要替换模型或升级提示词，改动范围较小
- 结构与其他主流 LLM API 习惯一致，便于维护

### 3. 配置方式沿用现有模式

当前项目已经通过 `Secrets.xcconfig -> Info.plist -> Swift Configuration` 的方式读取本地登录和 OSS 配置。

AI 配置建议沿用相同机制，新增以下配置项：

- `DASHSCOPE_API_KEY`
- `AI_ANALYSIS_MODEL`
- `AI_ANALYSIS_BASE_URL`

其中：

- `DASHSCOPE_API_KEY` 为必填
- `AI_ANALYSIS_MODEL` 可默认 `qwen3.6-plus`
- `AI_ANALYSIS_BASE_URL` 可默认 `https://dashscope.aliyuncs.com/compatible-mode/v1`

这样可以保持项目配置风格统一，也便于后续切测试环境或切模型。

---

## 推荐架构

第一阶段建议增加一个轻量服务层：

- `AIAnalysisConfiguration`
- `AIAnalysisService`

职责划分建议如下。

### AIAnalysisConfiguration

负责：

- 从 `Info.plist` 或环境变量读取 AI 配置
- 校验 `DASHSCOPE_API_KEY`
- 给出默认模型和默认 base URL

不负责：

- 请求逻辑
- 业务结果拼装

### AIAnalysisService

负责：

- 为指定 `TrainingVideoPost` 解析可访问的视频 URL
- 调用 DashScope OpenAI 兼容接口
- 把模型输出解析为本地结构化结果
- 向视图层返回统一的结果或错误

不负责：

- 直接操作 SwiftData
- 决定按钮文案或视图表现

这能保持边界清楚：服务层只管“拿结果”，视图层只管“改状态和展示”。

---

## 数据模型建议

当前 `TrainingVideoPost` 已有：

- `analysisStatus`
- `latestAnalysisSummary`
- `latestRecommendation`

这对“能显示”已经够了，但对“细化分析结果”还不够。

第一阶段建议只补少量字段，不做重型模型改造：

- `latestAnalysisHeadline: String?`
- `latestAnalysisFocus: String?`
- `latestAnalysisErrorMessage: String?`
- `analysisModelName: String?`
- `analysisUpdatedAt: Date?`

说明如下。

### latestAnalysisHeadline

用于承载 AI 输出的一句短标题，例如：

- 起步更顺，但收球前还能更低
- 回合选择更积极，终结前重心略高

这个字段很适合首页卡片和详情页标题区。

### latestAnalysisFocus

第一阶段不建议直接上复杂嵌套数组模型，避免 SwiftData 存储和迁移复杂度上升。

建议先把 `focus_points` 存成一个以换行拼接的字符串，UI 层再拆成 bullet 列表。

这样可以保留结构化输出能力，同时让数据层保持轻量。

### latestAnalysisErrorMessage

用于承载“为什么失败”，与 `latestAnalysisSummary` 分开。

因为“失败原因”和“分析结果”是两类不同信息，不应该混在同一字段里。

### analysisModelName

用于记录当前结果由哪个模型产出，例如：

- `qwen3.6-plus`

这对后续排查、灰度切模型、UI 展示都有帮助。

### analysisUpdatedAt

用于标识最近一次成功或失败分析的时间，便于详情页显示“最近更新于”。

---

## 多轮对话支持

可以支持，而且建议明确分成两层能力。

### 第一层：围绕单条视频的追问式对话

这是最适合优先落地的形态。

典型场景包括：

- “你说重心偏高，具体是在哪个动作段落？”
- “这条建议更适合训练视频还是比赛视频？”
- “如果我下次继续拍，机位应该怎么放？”
- “这次最先要改的是哪一个问题？”

这类问题的特点是：

- 上下文集中在同一条视频
- 已经有一版初始分析结果
- 用户是在继续深挖，而不是重新做完整分析

所以第一阶段的多轮对话，建议定义为：

基于“同一条视频 + 当前分析结果 + 对话历史”的跟进问答。

### 第二层：跨多条视频的长期陪练式对话

这层也可以做，但不建议在第一阶段一起上。

典型场景包括：

- “我最近三条视频里最重复的问题是什么？”
- “和上周比，我的起步有没有进步？”
- “接下来两周我应该优先练什么？”

这类能力会涉及更多复杂问题：

- 多条视频怎么选
- 历史结果怎么裁剪
- 长期记忆存在哪里
- 成本如何控制
- UI 入口怎么设计

因此建议先把“单视频追问”做顺，再决定是否扩展到“长期陪练”。

---

## 多轮对话的产品定位

这里不建议把它做成一个泛化聊天机器人，而应保持“视频分析助手”的产品边界。

也就是说，多轮对话的核心目标不是陪聊，而是围绕一条视频继续解释、澄清、细化和指导。

推荐支持的问题类型：

1. 解释型
   例如解释某条观察是什么意思
2. 定位型
   例如追问问题大概发生在哪类动作段落
3. 对比型
   例如当前视频里哪个问题更优先
4. 执行型
   例如下一次拍摄和训练怎么做

不建议第一阶段支持的问题类型：

- 与视频无关的泛话题聊天
- 长期训练计划生成
- 多视频自动横向比较
- 高置信度伤病或医学判断

这样可以避免产品边界失控，也能让 prompt 更稳定。

---

## 多轮对话的数据建议

如果要支持单条视频的追问式对话，建议新增一组轻量消息模型，而不是把对话历史硬塞进 `TrainingVideoPost` 的单个字符串字段。

推荐新增模型：

- `VideoAnalysisConversation`
- `VideoAnalysisMessage`

职责建议如下。

### VideoAnalysisConversation

建议字段：

- `id`
- `postID`
- `createdAt`
- `updatedAt`
- `lastUserMessage`
- `lastAssistantMessage`

作用：

- 表示某条视频下的一段会话
- 便于详情页只加载该视频自己的聊天上下文
- 后续如果需要“新建会话”或“清空会话”，扩展更自然

### VideoAnalysisMessage

建议字段：

- `id`
- `conversationID`
- `role`
- `content`
- `createdAt`
- `referencedAnalysisVersion`

其中：

- `role` 只需要 `user` / `assistant` / `system`
- `referencedAnalysisVersion` 第一阶段可以只是可选字符串，用来标记这条对话基于哪次分析结果

如果你希望第一阶段再轻一点，也可以先不建 `VideoAnalysisConversation`，只建 `VideoAnalysisMessage`，通过 `postID` 直接挂在视频下。

但从可维护性看，我更推荐保留 conversation 这一层，因为后续做“重新开始追问”会更清楚。

---

## 多轮对话的上下文组织

第一阶段不建议把完整历史无限制地发给模型，而是采用“固定上下文包”的方式。

每次追问时，建议送给模型的内容包括：

1. system prompt
   明确它是篮球视频分析助手，而不是泛聊天助手
2. 当前视频基础信息
   包括 `contentType`、`drillName`、`note`
3. 当前这条视频最近一次分析结果
   即 `headline`、`summary`、`focus_points`、`recommendation`
4. 最近若干轮对话历史
   建议先带最近 6 到 8 条消息
5. 当前用户问题

这样做有几个好处：

- 上下文稳定
- 成本可控
- 回答更聚焦
- 不容易把模型带偏成闲聊机器人

### 为什么不建议每轮都重新喂整个视频

第一阶段追问式对话里，建议默认不要每一轮都重新把 `video_url` 发给模型。

原因：

- 成本更高
- 速度更慢
- 很多追问其实是在解释已有分析，不需要重新“看视频”

更合理的策略是：

1. 首次分析时，模型真正看视频并产出结构化结果
2. 后续追问默认基于“已有分析结果 + 对话历史”回答
3. 只有当用户明确要求“重新看看视频”或问题必须重新观察视频时，再走一次带 `video_url` 的重分析或再观察流程

这个区分很重要，否则多轮对话的成本会明显上升。

---

## 多轮对话的回答策略

多轮对话建议与“首次分析”使用不同输出模式。

### 首次分析

返回严格 JSON，便于落库和结构化展示。

### 追问对话

返回自然语言文本，不必强制 JSON。

原因：

- 追问回答本质上是对已有结论的解释和展开
- UI 更像聊天气泡，不需要强结构
- 强制 JSON 反而会让交互显得生硬

不过仍建议保留一些系统约束：

1. 只基于已有分析和可观察视频内容回答
2. 不确定时明确说明
3. 不做医学诊断
4. 尽量给出具体、可执行建议

---

## 多轮对话的 UI 建议

### 入口位置

最适合的入口是视频详情页 AI 分析区底部。

建议在 `completed` 状态下增加一个入口：

- “继续追问”
- “问问 AI”

点击后展开或跳转到一个轻量聊天区。

### 展示形态

第一阶段建议使用“详情页下半区内嵌聊天卡片”，而不是新开一个独立 AI 页面。

原因：

- 用户上下文仍然停留在这条视频里
- 可以边看视频边问
- 不会把产品心智带偏成一个泛聊天页

推荐结构：

1. 会话标题
   例如“继续追问这条视频”
2. 推荐问题快捷入口
   例如：
   - “这条视频最先改什么？”
   - “下次怎么拍更清楚？”
   - “你说的问题大概在哪段动作？”
3. 消息流
4. 输入框

### 推荐问题

为了降低首次使用门槛，建议预置 3 到 4 个快捷问题。

这比直接给一个空输入框更友好，也更容易把用户引导到高价值问题上。

---

## 多轮对话的状态建议

第一阶段不建议给多轮对话引入新的复杂状态机。

只需要区分：

- 会话为空
- 正在发送
- 回复成功
- 回复失败

如果当前视频还没有初始分析结果，则不建议开放追问入口。

因为没有首轮分析时，对话上下文会很弱，模型也更容易答散。

所以推荐门槛是：

只有 `analysisStatus == .completed`，或者至少有一版可用分析结果时，才显示“继续追问”。

---

## 多轮对话的错误处理

相比首次分析，多轮对话更适合轻量失败提示。

建议包括：

### 1. 当前视频还没有可用分析

提示建议：

请先完成这条视频的 AI 分析，再继续追问。

### 2. 会话请求失败

提示建议：

这次回复没有成功，可以重新发送一次。

### 3. 上下文过长

第一阶段建议直接裁剪旧消息，不需要把“上下文过长”暴露给用户。

也就是说，这应由客户端在请求前自动处理，而不是让用户理解 token 限制。

---

## 分阶段实施建议

如果要把多轮对话纳入整体规划，建议这样分。

### AI 第一阶段

只做单次视频分析。

范围：

- 真实视频分析请求
- 结构化结果落库
- 详情页结果展示

### AI 第二阶段

增加单视频多轮追问。

范围：

- 视频详情页聊天入口
- 会话与消息模型
- `AIChatService` 或在 `AIAnalysisService` 中补充追问能力
- 最近 6 到 8 条消息上下文裁剪

验收标准：

- 用户可以围绕同一条视频持续追问
- 回答聚焦这条视频
- 会话可持久化

### AI 第三阶段

再评估是否做长期陪练式对话。

范围可能包括：

- 跨视频对比
- 历史问题归纳
- 周度训练建议
- 记忆与画像

这部分要等前两阶段跑通后再判断。

---

## 模型输出设计

第一阶段建议要求模型严格输出 JSON，不返回 Markdown，不返回额外解释。

建议输出结构如下：

```json
{
  "headline": "起步更顺，但收球前还能更低",
  "summary": "这条训练视频里，起步节奏比常见初学阶段更连贯，左右脚衔接也更自然。需要继续关注收球前的重心高度，否则会影响后续出手稳定性。",
  "focus_points": [
    "第一步启动更果断，动作没有明显停顿",
    "收球前上半身有提前抬起的趋势",
    "如果能保持更低重心，后续衔接会更稳"
  ],
  "recommendation": "下次建议从侧前方继续拍摄完整起步到出手的连续动作，重点观察收球前肩膀是否提前抬起。"
}
```

这个结构满足三个目标：

1. 卡片可用 `headline`
2. 详情页可用 `summary + focus_points + recommendation`
3. 数据层依然足够简单

---

## Prompt 设计建议

AI 分析不是通用视频描述，它更像“青少年篮球训练观察助手”。

因此 system prompt 不应泛泛而谈，而要强调以下约束：

1. 只基于视频中能观察到的内容作答
2. 看不清、画面遮挡、机位不足时要明确说明，不要编造
3. 输出口吻应偏训练反馈，而不是学术分析或文学描述
4. 建议必须可执行，适合下次拍摄或下次训练
5. 返回严格 JSON

推荐 prompt 方向如下：

### system

你是一名青少年篮球视频分析助手。你只根据视频中实际可观察到的动作、节奏、重心、衔接和场上选择输出结论。看不清的部分要明确说明，不要猜测。输出必须是严格 JSON，不要 Markdown，不要代码块，不要额外解释。

### user

请分析这条篮球视频，并输出以下字段：

- `headline`: 18 字以内的短标题，适合直接显示在卡片顶部
- `summary`: 2 到 3 句总结，说明这条视频最值得注意的动作或判断
- `focus_points`: 2 到 3 条重点观察点，每条一句
- `recommendation`: 1 到 2 句可执行建议，指导下次训练或拍摄

附加上下文可按需带上：

- 视频类型：训练 / 比赛
- 训练名称：如果有
- 用户备注：如果有

---

## 页面细化建议

### 1. 首页和动态页卡片

当前卡片已经有：

- 标题
- 状态
- 摘要
- 分析按钮

建议细化为：

1. 优先展示 `headline`
2. 次级文案展示 `summary`
3. 状态仍使用 `VideoAnalysisStatus`
4. `completed` 时可在卡片底部弱化展示模型来源，例如“Qwen AI”

这样用户在流里扫一眼就能看懂这条视频最关键的结论，而不是只看到一段泛泛摘要。

### 2. 详情页 AI 分析区

当前详情页结构已经不错，建议继续沿用，只调整内容层级。

推荐从上到下改成：

1. 状态行
2. 分析标题
3. 动作总结
4. 观察重点
5. 下一步建议
6. 最近更新时间 / 模型信息
7. 操作按钮

具体表现建议如下。

#### idle

- 显示“还没有分析结果”
- 文案说明点击后会生成动作总结与建议

#### processing

- 显示“AI 正在分析”
- 显示进度占位和等待说明
- 如果之前有成功结果，可考虑保留旧结果作为参考，但用状态提示“正在生成新结果”

#### completed

- 顶部展示 `headline`
- 中间展示 `summary`
- 新增“观察重点” bullet 列表
- 底部展示 `recommendation`
- 弱化展示 `analysisModelName` 与 `analysisUpdatedAt`

#### failed

- 单独展示失败原因
- 如果以前有旧结果，不建议清空旧结果，可继续展示“上次可用结果”
- 操作按钮显示“重新分析”

这个点很重要：失败状态不应直接把页面变成“什么都没有”，否则体验会倒退。

---

## 状态流转建议

第一阶段建议保持现有四态，不新增复杂状态：

- `idle`
- `processing`
- `completed`
- `failed`

但状态语义建议更明确：

### idle

从未发起过真实分析

### processing

当前正在向模型请求并等待结果

### completed

最近一次分析成功，页面展示的是最新成功结果

### failed

最近一次分析失败，但可以保留上一版成功结果作为参考

这个语义下，`failed` 不是“没有结果”，而是“本次更新失败”。

---

## 错误处理建议

第一阶段至少区分以下几类错误：

### 1. 配置错误

例如：

- 没有配置 `DASHSCOPE_API_KEY`
- `AI_ANALYSIS_BASE_URL` 非法

用户提示建议：

请先在 `Config/Secrets.xcconfig` 中补充 AI 配置。

### 2. 视频地址错误

例如：

- OSS 预签名地址生成失败
- 视频 URL 为空

用户提示建议：

当前视频地址暂不可用于分析，请稍后重试。

### 3. 模型请求失败

例如：

- HTTP 非 2xx
- 接口超时
- 网络中断

用户提示建议：

AI 服务暂时不可用，请稍后重试。

### 4. 模型返回格式不符合预期

例如：

- 返回内容不是 JSON
- 缺字段

用户提示建议：

分析结果解析失败，请重新尝试。

这几类错误不需要在第一阶段做很复杂的用户引导，但至少要做到“失败原因能看懂”。

---

## 工程实现建议

这一节把方案进一步落到“代码怎么拆”的粒度，方便后续直接开工。

### 推荐文件结构

建议新增或调整为下面这组文件：

- `Hoop/Core/Configuration/AIAnalysisConfiguration.swift`
- `Hoop/Core/Services/AIAnalysisService.swift`
- `Hoop/Features/Training/Models/AIAnalysisResult.swift`
- `Hoop/Features/Training/Models/AIAnalysisConversation.swift`
- `Hoop/Features/Training/Models/AIAnalysisMessage.swift`

如果第一阶段只做单次分析，则至少需要前三个文件。

如果进入第二阶段多轮对话，再补：

- `AIAnalysisConversation.swift`
- `AIAnalysisMessage.swift`

这样做的好处是：

- 配置、服务、业务模型分层清楚
- 第一阶段和第二阶段的新增文件边界明显
- 不会把所有 AI 逻辑都塞进 View 文件

### 第一阶段建议新增的 Swift 类型

#### AIAnalysisResult

这是服务层返回给界面层的结构化结果，建议不要直接拿 API DTO 在 UI 层到处传。

建议字段：

```swift
struct AIAnalysisResult: Sendable, Codable {
    let headline: String
    let summary: String
    let focusPoints: [String]
    let recommendation: String
    let modelName: String
    let generatedAt: Date
}
```

说明：

- `focusPoints` 在内存里保留数组
- 写入 `TrainingVideoPost` 时再转换成换行字符串
- `modelName` 和 `generatedAt` 直接跟结果一起返回，方便落库

#### AIAnalysisRequestContext

建议额外定义一个轻量上下文类型，避免服务层直接过度依赖 View。

```swift
struct AIAnalysisRequestContext: Sendable {
    let postID: String
    let contentType: TrainingVideoContentType
    let drillName: String?
    let note: String?
    let videoURL: URL
}
```

这样 `AIAnalysisService` 的签名会更稳定，也更好测。

### 第二阶段建议新增的 Swift 类型

#### VideoAnalysisConversation

建议作为 SwiftData `@Model`：

```swift
@Model
final class VideoAnalysisConversation {
    @Attribute(.unique) var id: String
    var postID: String
    var createdAt: Date
    var updatedAt: Date
    var lastUserMessage: String?
    var lastAssistantMessage: String?
}
```

#### VideoAnalysisMessage

```swift
@Model
final class VideoAnalysisMessage {
    @Attribute(.unique) var id: String
    var conversationID: String
    var roleRawValue: String
    var content: String
    var createdAt: Date
    var referencedAnalysisVersion: String?
}
```

第一阶段如果还不打算做消息持久化，这两类先不建也没问题。

---

## API 请求模型建议

第一阶段建议为 DashScope OpenAI 兼容接口定义一组最小 DTO，只覆盖我们实际会用到的字段。

### 请求 DTO

建议形态：

```swift
struct ChatCompletionsRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let responseFormat: ResponseFormat?
}

struct ChatMessage: Encodable {
    let role: String
    let content: [ChatContent]
}

enum ChatContent: Encodable {
    case text(String)
    case videoURL(URL)
}
```

第一阶段单次分析的 `messages` 建议为两条：

1. `system`
   负责约束角色、语气和输出格式
2. `user`
   同时包含：
   - 一段文本任务说明
   - 一段 `video_url`

如果后续进入多轮对话，再根据需要扩展成：

- 多条 `user`
- 多条 `assistant`
- 追问时不带 `video_url`

### 响应 DTO

建议只取最小必要字段：

```swift
struct ChatCompletionsResponse: Decodable {
    let choices: [Choice]
    let model: String?

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}
```

解析时建议流程如下：

1. 先取 `choices.first?.message.content`
2. 尝试按 JSON 解码到 `AIAnalysisResultPayload`
3. 成功后再转换成业务层 `AIAnalysisResult`
4. 失败则抛出解析错误

这样可以把“接口响应”和“业务模型”分开。

---

## 首次分析的请求体建议

根据 `qwen36.md`，视频输入建议使用 `video_url`。

第一阶段请求体建议接近如下结构：

```json
{
  "model": "qwen3.6-plus",
  "messages": [
    {
      "role": "system",
      "content": [
        {
          "type": "text",
          "text": "你是一名青少年篮球视频分析助手……输出必须是严格 JSON。"
        }
      ]
    },
    {
      "role": "user",
      "content": [
        {
          "type": "video_url",
          "video_url": {
            "url": "https://..."
          }
        },
        {
          "type": "text",
          "text": "请分析这条篮球视频，并输出 headline、summary、focus_points、recommendation。视频类型：训练。训练名称：原地变向。备注：重点看启动。"
        }
      ]
    }
  ]
}
```

### 关于 `response_format`

如果实际联调时 DashScope 对 OpenAI 兼容接口支持 JSON 输出约束稳定，可以考虑补 `response_format`。

但第一阶段即使不依赖它，也可以通过 prompt 强约束先跑通。

建议顺序是：

1. 先用 prompt 约束输出 JSON
2. 如果联调稳定，再看是否补 `response_format`

---

## 视图层写回策略

建议保持现在的交互模式：

1. 用户点击“开始 AI 分析”
2. View 把 `post.analysisStatus` 设为 `.processing`
3. 调用 `AIAnalysisService`
4. 成功后统一写回多个字段
5. 失败后写回错误字段和失败状态

推荐成功写回逻辑：

```swift
post.analysisStatus = .completed
post.latestAnalysisHeadline = result.headline
post.latestAnalysisSummary = result.summary
post.latestAnalysisFocus = result.focusPoints.joined(separator: "\n")
post.latestRecommendation = result.recommendation
post.latestAnalysisErrorMessage = nil
post.analysisModelName = result.modelName
post.analysisUpdatedAt = result.generatedAt
```

推荐失败写回逻辑：

```swift
post.analysisStatus = .failed
post.latestAnalysisErrorMessage = userFacingErrorMessage
post.analysisUpdatedAt = Date()
```

注意点：

- 失败时不建议清空已经存在的成功结果
- `latestAnalysisErrorMessage` 与结果字段分离
- 如果是“首次失败”，详情页就展示错误占位
- 如果是“重跑失败”，详情页可继续展示旧结果，并提示本次失败

---

## Home / Feed / Detail 的责任建议

为了避免 Home 和 Feed 各自复制一套 AI 调用逻辑，建议尽快收敛成共享方法。

### 第一阶段最低成本做法

保留 `HomeView` 和 `VideoFeedView` 里的触发入口，但把真正的分析执行逻辑抽成共享 helper。

例如：

- `TrainingVideoAnalysisCoordinator`
- 或 View 内部都调用同一个 `AIAnalysisService`

### 更推荐的做法

新增一个轻量协调层：

```swift
@MainActor
struct TrainingVideoAnalysisCoordinator {
    let service: AIAnalysisService

    func runAnalysis(for post: TrainingVideoPost, context: ModelContext) async
}
```

这样：

- Home 和 Feed 共用同一套状态写回逻辑
- 详情页将来要加“重新分析”也能直接复用
- 错误映射逻辑不会散落在多个 View 里

---

## 多轮对话的工程建议

如果进入第二阶段，建议单独增加一个聊天服务，而不是把首次分析和追问逻辑完全混在一起。

推荐：

- `AIAnalysisService`
  负责首轮视频分析
- `AIConversationService`
  负责单视频追问

原因：

- 首轮分析依赖 `video_url`
- 追问更依赖“已有结果 + 最近消息”
- 两者请求拼装方式不同
- 输出格式也不同

### AIConversationService 建议签名

```swift
protocol AIConversationServicing {
    func reply(
        to question: String,
        post: TrainingVideoPost,
        messages: [VideoAnalysisMessage]
    ) async throws -> String
}
```

这样第二阶段做 UI 时，View 层只关心：

1. 创建用户消息
2. 调服务拿回复
3. 持久化 assistant 消息

---

## Prompt 模块化建议

为了避免 prompt 散落在 View 或 Service 里，建议单独集中管理。

推荐做法：

- `AIAnalysisPromptFactory`
- `AIConversationPromptFactory`

职责：

- 负责拼接 system prompt
- 负责拼接 user prompt
- 负责把 `TrainingVideoPost` 转成模型可理解的上下文描述

这样后续改 prompt 时，不需要去翻多个业务文件。

---

## 验证建议

第一阶段联调时，建议至少验证以下场景。

### 成功场景

- 训练视频可成功拿到结构化结果
- 比赛视频可成功拿到结构化结果
- `headline / summary / focus / recommendation` 能正确写回

### 失败场景

- 未配置 `DASHSCOPE_API_KEY`
- 视频地址失效
- 接口返回非 JSON
- 网络超时

### 展示场景

- 首页卡片优先显示 `headline`
- 详情页能展示观察重点列表
- 失败时旧结果仍可保留

### 第二阶段场景

- 连续追问 3 到 5 轮仍然保持聚焦
- 会话历史可持久化
- 重进详情页后消息还在

---

## 首阶段实现建议

建议按下面顺序落地。

### 第一步：打通真实 API

范围：

- 增加 AI 配置读取
- 增加 `AIAnalysisService`
- 用真实请求替换 Home / Feed 中的 mock 分析

验收标准：

- 点击“开始 AI 分析”后能真正请求 Qwen
- 成功后能写回 `summary` 和 `recommendation`

### 第二步：补齐结构化结果字段

范围：

- 在 `TrainingVideoPost` 增加 `headline`、`focus`、`errorMessage`、`modelName`、`updatedAt`
- 调整详情页 AI 模块

验收标准：

- 详情页能分层展示标题、总结、重点、建议
- 失败状态有清晰提示

### 第三步：微调列表卡片表达

范围：

- 首页卡片优先显示 `headline`
- 次级显示 `summary`
- 适度展示 AI 来源或更新时间

验收标准：

- 列表里能更快扫出“这条视频讲了什么”

---

## 暂不建议做的事

以下方向都可以做，但不建议在这轮一并上：

### 1. 自动上传后立即分析

虽然这是自然下一步，但现在建议先保留手动触发。

原因：

- 更方便验证 prompt 和输出质量
- 避免每次上传都立即消耗模型成本
- 失败时更容易定位问题

### 2. 历史对比分析

例如“与上周相比”的能力。

这个方向很有价值，但前提是：

- 数据上明确 baseline 视频
- Prompt 中能同时带入多条视频
- UI 上能区分“本条观察”和“跨视频对比”

当前项目虽然有 `baselineVideoPostID`，但这条能力还不适合在本阶段做全。

### 3. 量化打分

例如动作节奏 80 分、起步 74 分之类。

不建议第一阶段上，因为：

- 模型主观评分容易制造虚假精度
- 会拉高用户对“绝对准确”的预期
- 解释成本比价值更高

第一阶段更适合做“观察 + 建议”。

---

## 推荐实施结论

如果按“风险低、可 review、可逐步上线”的标准来选，推荐方案是：

1. 维持现有页面骨架不大改
2. 用 Qwen3.6 OpenAI 兼容接口接入真实视频分析
3. 在 `TrainingVideoPost` 上只增加少量可选字段
4. 让 AI 输出稳定为 `headline + summary + focus_points + recommendation`
5. 首页、动态页、详情页统一围绕这套结构展示

这条路线的优点是：

- 和现有项目结构贴合
- 改动边界清楚
- 先把真能力做出来，再继续细化

---

## Review 时建议重点看什么

你 review 这份设计时，我建议重点看这几个决策点：

1. 第一阶段是否就要加 `headline / focus / error / model / updatedAt` 这 5 个字段
2. `focus_points` 第一阶段是否接受“换行字符串存储”的轻量方案
3. 首页卡片是否要优先显示 `headline`
4. 失败时是否保留旧结果
5. 当前是否继续采用“手动触发分析”，而不是上传后自动分析
6. 模型先固定 `qwen3.6-plus`，还是预留更明显的模型切换能力

如果这些点你认同，下一步我就可以按这份文档去落代码。
