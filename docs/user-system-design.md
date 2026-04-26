# 本地用户系统设计（家庭内测场景）

## 背景与约束

- 无后端登录服务，所有用户数据本地维护
- 目标用户群：家庭成员（管理员 + 若干球员）
- OSS 直连（RAM 子账号最小权限），不使用 STS
- 密钥通过 `Config/Secrets.xcconfig`（不进 Git）在编译期注入

---

## 认证与会话总体流程

```
App 启动
  └── xcconfig 密码解锁（设备级，一台设备一套）  ← AuthViewModel 负责
        └── Profile 选择器（选谁在用这台设备）    ← ProfileManager 负责
              └── 主界面（按角色展示功能）
```

两层职责分离：
- **AuthViewModel**（现有）：只管「设备锁」，验证 xcconfig 密码，维护 `AuthSessionRecord`
- **ProfileManager**（新增，`@Observable`）：只管「谁在使用」，维护 `LocalUserProfile` 的 CRUD 和当前选中

xcconfig 密码作为「设备锁」，解锁后进入本地用户系统；
本地用户系统管理「谁在使用这台设备」，不再需要每个用户单独一套 xcconfig。

> **边界说明**：
> - `AuthenticatedUser` / `AuthSessionRecord` 表示“这台设备已被解锁”
> - `LocalUserProfile` / `ProfileManager` 表示“当前是谁在使用这台设备”
> - 前者是设备级上下文，后者是应用内当前成员上下文，二者并存但职责不同

---

## 用户角色

| 角色 | 值 | 说明 |
|------|----|------|
| 管理员 | `parent` | 管理角色，只负责查看全部成员数据、管理成员、访问设置 |
| 球员 | `player` | 普通成员，只能查看和上传自己的训练数据 |

### 权限矩阵

| 功能 | 管理员 | 球员 |
|------|------|------|
| 查看自己的训练数据 | ❌ | ✅ |
| 上传训练视频 | ❌ | ✅ |
| 查看所有成员数据 | ✅ | ❌ |
| 添加 / 编辑成员 | ✅ | ❌ |
| 删除任意成员数据 | ✅ | ❌ |
| 访问 App 设置 | ✅ | ❌ |
| 进入身份切换页 | ✅ | ✅ |
| 切回管理员 Profile | 直接允许 | 需要再次验证设备密码 |

---

## 数据模型

项目已使用 SwiftData（`AuthSessionRecord`），用户 Profile 沿用同一 `modelContainer`，无需引入额外 JSON 文件。

> **注意**：`HoopApp.swift` 的 `ModelContainer` 需同时注册 `AuthSessionRecord` 和 `LocalUserProfile`：
> ```swift
> ModelContainer(for: AuthSessionRecord.self, LocalUserProfile.self)
> ```

### `UserRole`

```swift
enum UserRole: String, Codable {
    case parent  // 管理员
    case player  // 球员
}

extension UserRole {
    var canManageUsers: Bool    { self == .parent }
    var canViewAllData: Bool    { self == .parent }
    var canAccessSettings: Bool { self == .parent }
    var canUpload: Bool         { self == .player }
    var canViewOwnTraining: Bool { self == .player }
}
```

### 权限控制 ViewModifier（可选）

简化 UI 层的角色判断：

```swift
extension View {
    @ViewBuilder
    func visibleTo(_ role: UserRole, requiring permission: KeyPath<UserRole, Bool>) -> some View {
        if role[keyPath: permission] { self }
    }
}

// 用法
AddMemberButton()
    .visibleTo(currentUser.role, requiring: \.canManageUsers)
```

### `LocalUserProfile`（SwiftData Model）

```swift
@Model final class LocalUserProfile {
    @Attribute(.unique) var id: String   // 稳定 UUID，同时作为 OSS 路径段
    var displayName: String
    var role: UserRole
    var avatarEmoji: String              // emoji 头像，无需图片文件
    var createdAt: Date
}
```

> **当前选中用户**不存在模型上，而是用 `@AppStorage("activeProfileID")` 保存选中的 Profile ID。
> 理由：避免切换用户时需要同时修改两条 SwiftData 记录（旧置 false、新置 true）的非原子操作。

### `ProfileManager`（新增，`@Observable`）

负责 Profile 的 CRUD 和当前选中状态：

```swift
@MainActor
@Observable
final class ProfileManager {
    enum ParentAccessPolicy {
        case open
        case requiresDevicePassword
    }

    enum ProfileState: Equatable {
        case noProfiles                       // 首次使用，需引导创建
        case selecting                        // 有成员但未选
        case ready(LocalUserProfile)          // 已选中，可进入主界面
    }

    private(set) var state: ProfileState = .noProfiles
    private(set) var parentAccessPolicy: ParentAccessPolicy = .open
    @ObservationIgnored
    @AppStorage("activeProfileID") private var activeProfileID: String?

    func resolve(from profiles: [LocalUserProfile]) { ... }
    func select(_ profile: LocalUserProfile) { ... }
    func beginProfileSelection(from currentProfile: LocalUserProfile?) { ... }
    func requiresDevicePassword(toSelect profile: LocalUserProfile) -> Bool { ... }
    func createProfile(..., in context: ModelContext) { ... }
    func deleteProfile(..., in context: ModelContext) { ... }
}
```

补充约束：

- `ProfileManager` 本身**不持有** SwiftData 查询；由上层视图通过 `@Query` 取得 `[LocalUserProfile]` 后调用 `resolve(from:)`
- `resolve(from:)` 必须是**幂等**的：每次 `profiles` 或 `activeProfileID` 变化时都可安全重算 `state`
- 若 `activeProfileID` 为空，或对应 Profile 已被删除，则回退到：
  - 有 profile 时：`.selecting`
  - 无 profile 时：`.noProfiles`
- `select(_:)` 只写入 `activeProfileID`，随后由下一次 `resolve(from:)` 推导出 `.ready(profile)`
- 从球员视角进入身份切换页时，`parentAccessPolicy` 应切为 `.requiresDevicePassword`
- 在身份选择页点选管理员 Profile 时，若策略为 `.requiresDevicePassword`，必须先通过一次设备密码验证，再允许进入管理员视角

推荐职责分层：

- `ProfileGateView`：持有 `@Query`，监听 `profiles` 变化，并调用 `profileManager.resolve(from:)`
- `ProfileManager`：只负责“根据 profiles + activeProfileID 推导状态”和 CRUD
- 业务页面：只读取 `ProfileManager.state` 中的当前 profile，不直接查询全量 profile

### 与现有模型的关系

| 模型 | 职责 |
|------|------|
| `AuthSessionRecord`（现有） | 设备级会话，记录 xcconfig 账号是否解锁 |
| `LocalUserProfile`（新增） | 家庭成员静态信息（姓名、角色、头像） |
| `ProfileManager`（新增） | Profile CRUD + 当前选中状态，通过 `@Environment` 注入视图树 |
| `AuthenticatedUser`（现有，不改） | 设备锁解锁后的上下文，保持原样 |

### 设备级用户 vs 当前 Profile

为避免后续实现混淆，文档中统一采用下面的术语：

- **设备级用户**：`AuthenticatedUser`，表示 xcconfig 账号验证通过
- **当前 Profile**：`LocalUserProfile`，表示当前正在使用 App 的家庭成员

实现原则：

- `AuthRootView` 仍由 `AuthViewModel.state` 决定是否已“解锁设备”
- `ProfileGateView` 再决定是否已“选中当前成员”
- 进入业务页面后，与成员相关的数据读写都应基于 `LocalUserProfile`
- 只有仍然需要“设备锁操作”的地方，例如退出设备登录，才继续依赖 `AuthViewModel`

---

## OSS 目录隔离

### 当前结构

```
training-videos/          ← OSS_UPLOAD_DIR，所有人共用
  └── {userID}/
      └── {year}/{month}/
          └── {uuid}.mp4
```

> 现有 `OSSUploadService.objectKey(for:userID:)` 已按 `userID/year/month` 分层。

### 改后结构

```
training-videos/
  ├── {uuid-小明}/         ← LocalUserProfile.id（UUID）
  │   └── 2025/04/19/
  │       └── 550e8400-e29b-41d4-a716-446655440000.mp4
  ├── {uuid-小红}/
  │   └── 2025/04/19/
  └── {uuid-管理员}/       ← 仅保留 Profile 标识，不作为新上传目标
```

- `userId` 为创建 Profile 时生成的 UUID（如 `a1b2c3d4-...`），保持稳定
- 上传路径固定为：`training-videos/{playerID}/{yyyy}/{MM}/{dd}/{uuid}.mp4`
- **`OSSUploadService` 接口基本不变**，只需确保调用方在球员上传时传入 `LocalUserProfile.id`
- `TrainingUploadViewModel` 从 `ProfileManager` 获取当前球员 ID；管理员视角不展示上传入口

> **角色边界补充**：
> - 后续新增上传视频时，只会写入球员 Profile 对应的 OSS 目录
> - 管理员 Profile 主要用于成员管理和查看全局数据，不再作为新的训练上传主体

### “按天”定义

为避免实现歧义，文档中统一采用以下定义：

- **trainingDate**：用户当前设备时区下的自然日（年/月/日）
- OSS 路径中的 `{yyyy}/{MM}/{dd}` 由 `trainingDate` 计算得出
- 当前方案按“上传发生的当天”分组，而不是按视频拍摄元数据中的拍摄日期分组

例如：

- 2025-04-19 晚上拍摄并上传：归入 `2025/04/19`
- 2025-04-19 拍摄、2025-04-20 补传：归入 `2025/04/20`

> 这样做的原因是实现更稳定，不依赖视频文件是否带有可靠的拍摄时间元数据。

> **重要**：切换 Profile 后，上传链路必须立即切到新的 `LocalUserProfile.id`。
> 现有 `TrainingView` 在 `init` 中创建 `@State TrainingUploadViewModel(userID:)`，如果仅把页面改成读取环境，
> 但不重建 view model 或同步其 `userID`，后续上传仍可能写入上一个成员的 OSS 目录。

推荐做法二选一：

1. `TrainingUploadViewModel` 改为不在初始化时固化 `userID`，上传时显式传入 `currentProfile.id`
2. 保持 view model 结构，但让 `TrainingView` 以 `currentProfile.id` 作为稳定 identity，在切换成员时重建页面状态

优先推荐方案 1，更不容易出现状态残留。

### 上传记录元数据

仅靠 OSS 目录结构，不足以支撑管理员“按天查看所有成员数据”的需求。
因此建议在本地额外维护一份上传记录元数据，作为列表展示与聚合查询的数据源。

建议新增 `UploadedTrainingVideoRecord`（SwiftData Model）：

```swift
@Model final class UploadedTrainingVideoRecord {
    @Attribute(.unique) var id: String
    var playerID: String
    var objectKey: String
    var fileName: String
    var trainingDate: Date      // 归一化到本地自然日
    var uploadedAt: Date
    var fileSize: Int64
}
```

推荐约束：

- `trainingDate` 仅用于“按天分组/筛选”，写入时应归一化到当天 00:00
- `uploadedAt` 用于同一天内的排序、时间展示和调试
- `objectKey` 仍然是 OSS 中的真实对象路径，作为下载/预览定位依据
- 上传成功后，先拿到 OSS 返回结果，再写入本地 `UploadedTrainingVideoRecord`

推荐读取方式：

- 球员视角：查询 `playerID == currentProfile.id && trainingDate == selectedDay`
- 管理员视角：查询 `trainingDate == selectedDay`，再按 `playerID` 分组展示

这样“按天分组”是业务层能力，而不仅仅是目录层能力。

---

## 界面流程

```
AuthRootView（现有，不改 AuthState 枚举）
  ├── .loading
  ├── .configurationError  → ConfigurationErrorView（现有）
  ├── .signedOut           → SignInView（现有，解锁设备）
  └── .signedIn
        └── ProfileGateView（新增，读取 ProfileManager.state）
              ├── .noProfiles  → OnboardingCreateProfileView（首次使用，引导创建）
              ├── .selecting   → ProfileSelectorView（选谁在用）
              └── .ready       → AppShellView（现有）
```

> **关键决策**：`AuthViewModel` 的 `AuthState` 保持原样（`.loading / .signedOut / .signedIn / .configurationError`），
> Profile 相关逻辑完全由 `ProfileGateView` + `ProfileManager` 承担，零耦合。

### ProfileGateView（新增）

`AuthRootView` 的 `.signedIn` 分支切到此视图，由它根据 `ProfileManager.state` 决定子视图。
`ProfileManager` 通过 `@Environment` 注入，子视图（如 `TrainingView`）可直接读取当前用户。

实现要点：

- `ProfileGateView` 持有 `@Query(sort: \LocalUserProfile.createdAt)` 的 profile 列表
- 在 `.task` 和 `profiles` 变化时调用 `profileManager.resolve(from: profiles)`
- 若应用支持从设置页切换 profile，则切换动作完成后也要触发一次 `resolve(from:)`
- 如需处理迁移，可在 `ProfileGateView` 首次出现时先执行一次“确保默认管理员 profile 存在”的迁移逻辑，再进入正常 resolve

### ProfileSelectorView（示意）

```
╔═══════════════════════════╗
║   选择你的身份              ║
╠═══════════════════════════╣
║  👨 爸爸（管理员）  ⚙️      ║  ← 管理员角色右上角有管理入口
║  🏀 小明（球员）            ║
║  🏀 小红（球员）            ║
║  ＋ 添加成员（仅管理员可见） ║
╚═══════════════════════════╝
```

SwiftUI 实现要点：
- 使用 `List` + `ForEach(profiles) { profile in ... }` 以 `profile.id` 为稳定 identity
- 每行用 `Button` 实现（不用 `onTapGesture`），确保 VoiceOver 可访问
- emoji 头像添加 `.accessibilityLabel("\(profile.displayName)的头像")`
- 删除成员用 `.swipeActions` + `confirmationDialog`，避免误操作
- 若当前是球员并尝试切到管理员 Profile，弹出密码验证 sheet；验证通过后再执行 `select(_:)`
- 当前是管理员时，可直接在身份选择页切到任意 Profile，无需二次验证

### OnboardingCreateProfileView

- 表单用 `@FocusState` 管理键盘焦点（与现有 `SignInView` 风格一致）
- emoji 选择器建议用 `.sheet` 弹出

---

## 需要改动的文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `App/HoopApp.swift` | 修改 | `ModelContainer` 注册 `LocalUserProfile`；创建并注入 `ProfileManager` |
| `Auth/Views/AuthRootView.swift` | 修改 | `.signedIn` 分支改为渲染 `ProfileGateView` |
| `Shell/Views/AppShellView.swift` | 修改 | 保留设备级 `AuthViewModel`，成员相关 UI 改从 `@Environment(ProfileManager.self)` 读取当前 Profile |
| `Home/Views/HomeView.swift` | 修改 | 管理员首页改为家庭成员总览，不展示个人训练打卡 |
| `Training/Views/TrainingView.swift` | 修改 | 球员显示训练与上传入口；管理员显示全员训练总览，不展示上传入口 |
| `Training/ViewModels/TrainingUploadViewModel.swift` | 修改 | 不再长期固化旧 userID；上传时显式使用当前球员 Profile ID，并在上传成功后写入本地上传记录 |
| `Users/Models/UserRole.swift` | 新增 | 角色枚举与权限扩展 |
| `Users/Models/LocalUserProfile.swift` | 新增 | SwiftData 用户 Profile 模型 |
| `Training/Models/UploadedTrainingVideoRecord.swift` | 新增 | 本地上传记录元数据，支撑按天分组与管理员汇总查询 |
| `Users/ViewModels/ProfileManager.swift` | 新增 | Profile CRUD + 选中状态管理 |
| `Users/Views/ProfileGateView.swift` | 新增 | 根据 ProfileManager.state 路由子视图 |
| `Users/Views/ProfileSelectorView.swift` | 新增 | Profile 选择界面；球员切回管理员时负责二次验证 |
| `Users/Views/UserManagementView.swift` | 新增 | 管理员管理成员界面 |
| `Users/Views/OnboardingCreateProfileView.swift` | 新增 | 首次使用引导 |
| `Hoop.xcodeproj/project.pbxproj` | 修改 | 新增 Users 目录下文件后同步工程引用 |
| 相关 Preview 文件 | 修改 | `modelContainer` 和 `environment` 注入需同步更新，避免预览/编译失败 |

> 以下文件**不需要改动**：
> - `Auth/Models/AuthenticatedUser.swift` — 保持原样，不新增 `role` 字段
> - `Auth/ViewModels/AuthViewModel.swift` — 保持原样，不扩展状态枚举
> - `Core/Services/OSSUploadService.swift` — 接口不变，调用方传入不同 userID 即可

---

## 实现顺序建议

1. `UserRole` + `LocalUserProfile` 数据模型（无副作用，可独立完成）
2. `HoopApp.swift` 更新 `ModelContainer` 注册 + 创建 `ProfileManager` 并注入 `@Environment`
3. `ProfileManager` 实现 CRUD 和 `@AppStorage` 选中逻辑
4. `ProfileGateView` + `ProfileSelectorView` + `OnboardingCreateProfileView` UI
5. `AuthRootView` 的 `.signedIn` 分支改为渲染 `ProfileGateView`
6. `UploadedTrainingVideoRecord` 数据模型 + 上传成功后的本地写入
7. `AppShellView` + `HomeView` + `TrainingView` 按角色分流界面内容
8. `ProfileSelectorView` 增加“球员切回管理员”的设备密码二次验证
9. `UserManagementView`（管理员管理成员）

---

## 数据迁移

当前版本**不考虑历史数据兼容**，按全新本地用户系统设计即可。

因此这里不额外定义旧 OSS 路径迁移、旧目录兼容读取或历史上传记录补写逻辑。

---

## 成员删除策略

- 删除本地 Profile 时，**不删除** OSS 上已有数据（避免误操作导致数据丢失）
- OSS 数据保留，管理员可通过 OSS 控制台手动清理
- UI 上用 `confirmationDialog` 二次确认，提示"本地资料将被移除，已上传的训练视频不会被删除"

---

## 安全说明

- OSS RAM 子账号建议只开放 **单 bucket + 指定路径前缀 + PutObject** 权限
- `Secrets.xcconfig` 已在 `.gitignore` 中，密钥不进 Git
- 当前角色权限主要是**本地 UI / 本地状态约束**，不是服务端级强鉴权
- 家庭内测场景下，此方案安全边界已足够；若将来面向公网发布，应改为 STS 或服务端换凭证
