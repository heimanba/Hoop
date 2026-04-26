import Foundation

struct AIAnalysisResult: Sendable, Codable {
    let headline: String
    let summary: String
    let focusPoints: [String]
    let recommendation: String
    let modelName: String
    let generatedAt: Date
}

struct AIAnalysisRequestContext: Sendable {
    let postID: String
    let contentType: TrainingVideoContentType
    let drillName: String?
    let note: String?
    let videoURL: URL
}

struct AIAnalysisConversationResult: Sendable, Codable {
    let text: String
    let recommendedQuestions: [String]
    let visibilityNote: String?
    let modelName: String
    let generatedAt: Date
}

actor AIAnalysisService {
    private let configuration: AIAnalysisConfiguration
    private let session: URLSession

    init(
        configuration: AIAnalysisConfiguration? = nil,
        session: URLSession = .shared
    ) throws {
        self.configuration = try configuration ?? AIAnalysisConfiguration.load()
        self.session = session
    }

    func analyzeVideo(for post: TrainingVideoPost) async throws -> AIAnalysisResult {
        let context = try await makeRequestContext(for: post)
        return try await analyzeVideo(with: context)
    }

    func analyzeVideo(with context: AIAnalysisRequestContext) async throws -> AIAnalysisResult {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(makeChatRequest(for: context))

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIAnalysisServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let rawContent = decoded.choices.first?.message.content?.trimmed,
              !rawContent.isEmpty else {
            throw AIAnalysisServiceError.emptyContent
        }

        let payloadData = Data(Self.cleanedJSONString(from: rawContent).utf8)
        let payload = try JSONDecoder().decode(AIAnalysisResultPayload.self, from: payloadData)

        return AIAnalysisResult(
            headline: payload.headline.trimmed,
            summary: payload.summary.trimmed,
            focusPoints: payload.focusPoints.map(\.trimmed).filter { !$0.isEmpty },
            recommendation: payload.recommendation.trimmed,
            modelName: decoded.model?.trimmed.nilIfEmpty ?? configuration.model,
            generatedAt: Date()
        )
    }

    func generateInitialConversation(
        for post: TrainingVideoPost,
        selectedTag: VideoAnalysisTag,
        initialPrompt: String? = nil
    ) async throws -> AIAnalysisConversationResult {
        let context = try await makeRequestContext(for: post)

        let response = try await performConversationRequest(
            messages: [
                ChatMessage(
                    role: "system",
                    content: [
                        .text(Self.conversationSystemPrompt)
                    ]
                ),
                ChatMessage(
                    role: "user",
                    content: [
                        .videoURL(context.videoURL),
                        .text(
                            Self.initialConversationPrompt(
                                for: context,
                                selectedTag: selectedTag,
                                initialPrompt: initialPrompt
                            )
                        )
                    ]
                )
            ]
        )

        return AIAnalysisConversationResult(
            text: response.text,
            recommendedQuestions: response.recommendedQuestions,
            visibilityNote: response.visibilityNote,
            modelName: response.modelName,
            generatedAt: response.generatedAt
        )
    }

    func replyInConversation(
        for post: TrainingVideoPost,
        selectedTag: VideoAnalysisTag,
        history: [VideoAnalysisMessage],
        question: String
    ) async throws -> AIAnalysisConversationResult {
        let context = try await makeRequestContext(for: post)
        var messages: [ChatMessage] = [
            ChatMessage(
                role: "system",
                content: [
                    .text(Self.conversationSystemPrompt)
                ]
            ),
            ChatMessage(
                role: "user",
                content: [
                    .videoURL(context.videoURL),
                    .text(Self.initialConversationPrompt(for: context, selectedTag: selectedTag))
                ]
            )
        ]

        for message in history where message.generationStatus == .completed {
            let role: String
            switch message.sender {
            case .assistant:
                role = "assistant"
            case .system:
                role = "system"
            case .user:
                role = "user"
            }

            messages.append(
                ChatMessage(
                    role: role,
                    content: [
                        .text(message.text)
                    ]
                )
            )
        }

        messages.append(
            ChatMessage(
                role: "user",
                content: [
                    .text(Self.followUpPrompt(for: context, question: question, selectedTag: selectedTag))
                ]
            )
        )

        let response = try await performConversationRequest(messages: messages)
        return AIAnalysisConversationResult(
            text: response.text,
            recommendedQuestions: response.recommendedQuestions,
            visibilityNote: response.visibilityNote,
            modelName: response.modelName,
            generatedAt: response.generatedAt
        )
    }

    private func makeRequestContext(for post: TrainingVideoPost) async throws -> AIAnalysisRequestContext {
        let videoURL = try await resolveVideoURL(for: post)
        return AIAnalysisRequestContext(
            postID: post.id,
            contentType: post.contentType,
            drillName: post.drillName,
            note: post.note,
            videoURL: videoURL
        )
    }

    private func resolveVideoURL(for post: TrainingVideoPost) async throws -> URL {
        if !post.objectKey.isEmpty {
            do {
                let service = try OSSUploadService()
                return try await service.playbackURL(for: post.objectKey, expirationInterval: 60 * 60)
            } catch {
                if let remoteVideoURL = post.remoteVideoURL {
                    return remoteVideoURL
                }
                throw AIAnalysisServiceError.videoUnavailable
            }
        }

        if let remoteVideoURL = post.remoteVideoURL {
            return remoteVideoURL
        }

        throw AIAnalysisServiceError.videoUnavailable
    }

    private func makeChatRequest(for context: AIAnalysisRequestContext) -> ChatCompletionsRequest {
        let userPrompt = Self.userPrompt(for: context)

        return ChatCompletionsRequest(
            model: configuration.model,
            messages: [
                ChatMessage(
                    role: "system",
                    content: [
                        .text(Self.systemPrompt)
                    ]
                ),
                ChatMessage(
                    role: "user",
                    content: [
                        .videoURL(context.videoURL),
                        .text(userPrompt)
                    ]
                )
            ]
        )
    }

    private func performConversationRequest(messages: [ChatMessage]) async throws -> AIAnalysisConversationResult {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionsRequest(
                model: configuration.model,
                messages: messages
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIAnalysisServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let rawContent = decoded.choices.first?.message.content?.trimmed,
              !rawContent.isEmpty else {
            throw AIAnalysisServiceError.emptyContent
        }

        let payloadData = Data(Self.cleanedJSONString(from: rawContent).utf8)
        let payload = try JSONDecoder().decode(AIConversationPayload.self, from: payloadData)

        return AIAnalysisConversationResult(
            text: payload.text.removingBidirectionalControlCharacters.trimmed,
            recommendedQuestions: payload.recommendedQuestions
                .map { $0.removingBidirectionalControlCharacters.trimmed }
                .filter { !$0.isEmpty },
            visibilityNote: payload.visibilityNote?
                .removingBidirectionalControlCharacters
                .trimmed
                .nilIfEmpty,
            modelName: decoded.model?.trimmed.nilIfEmpty ?? configuration.model,
            generatedAt: Date()
        )
    }

    private static func userPrompt(for context: AIAnalysisRequestContext) -> String {
        let strategy = context.contentType.analysisStrategy
        var lines = [
            "请分析这条篮球视频，并输出严格 JSON。",
            "分析角色：\(strategy.roleDescription)",
            "字段要求：headline、summary、focus_points、recommendation。",
            "headline：18 字以内的短标题。",
            "summary：2 到 3 句总结，说明这条视频最值得注意的动作或判断。",
            "summary 要求：\(strategy.summaryGuidance)",
            "focus_points：2 到 3 条重点观察点，每条一句。",
            "recommendation：1 到 2 句可执行建议，指导下次训练或拍摄。",
            "recommendation 要求：\(strategy.recommendationGuidance)",
            "视频类型：\(context.contentType.title)。"
        ]

        lines.append("优先关注：")
        lines.append(contentsOf: strategy.focusAreas.map { "- \($0)" })
        lines.append("避免跑偏：")
        lines.append(contentsOf: strategy.avoidances.map { "- \($0)" })

        if let drillName = context.drillName?.trimmed, !drillName.isEmpty {
            lines.append("训练名称：\(drillName)。")
        }

        if let note = context.note?.trimmed, !note.isEmpty {
            lines.append("用户备注：\(note)。")
        }

        lines.append("如果画面中有看不清、遮挡或无法判断的部分，请在 summary 或 focus_points 中明确说明，不要猜测。")
        lines.append("不要输出 Markdown，不要输出代码块，不要输出 JSON 之外的任何解释。")

        return lines.joined(separator: "\n")
    }

    private static let systemPrompt = """
    你是一名青少年篮球视频分析助手。你只根据视频中实际可观察到的动作、节奏、重心、衔接和场上选择输出结论。看不清的部分要明确说明，不要猜测。输出必须是严格 JSON，不要 Markdown，不要代码块，不要额外解释。
    """

    private static func initialConversationPrompt(
        for context: AIAnalysisRequestContext,
        selectedTag: VideoAnalysisTag,
        initialPrompt: String? = nil
    ) -> String {
        let strategy = context.contentType.analysisStrategy
        var lines = [
            "你正在对一条篮球视频发起首轮分析。",
            "当前视频类型：\(context.contentType.title)。",
            "类型分析策略：\(strategy.roleDescription)",
            "当前分析标签：\(selectedTag.title)。",
            "标签分析要求：\(selectedTag.promptHint(for: context.contentType))",
            "请只围绕这个标签做分析，不要平均展开到所有维度。",
            "优先关注："
        ]

        lines.append(contentsOf: strategy.focusAreas.map { "- \($0)" })
        lines.append("避免跑偏：")
        lines.append(contentsOf: strategy.avoidances.map { "- \($0)" })

        lines.append(contentsOf: [
            "输出严格 JSON，字段为 text、recommended_questions、visibility_note。",
            "text 必须是自然语言三段式：第一段核心判断，第二段原因分析，第三段下一步建议。",
            "recommended_questions 返回 2 到 3 个适合继续追问的问题，每条一句。",
            "recommended_questions 要求：\(strategy.questionGuidance)",
            "visibility_note 用于补充画面看不清、信息不足或无需额外说明，无法补充时可返回空字符串。"
        ])

        if let drillName = context.drillName?.trimmed, !drillName.isEmpty {
            lines.append("训练名称：\(drillName)。")
        }

        if let note = context.note?.trimmed, !note.isEmpty {
            lines.append("用户备注：\(note)。")
        }

        if let initialPrompt = initialPrompt?.trimmed, !initialPrompt.isEmpty {
            lines.append("用户希望你优先处理的请求：\(initialPrompt)")
            lines.append("请在首轮分析中优先回应这条请求，但不要脱离当前分析标签。")
        }

        lines.append("如果看不清，请明确指出信息不足，但仍然给出下一次补拍或训练建议。")
        lines.append("不要输出 Markdown，不要输出代码块，不要输出 JSON 之外的任何解释。")
        return lines.joined(separator: "\n")
    }

    private static func followUpPrompt(
        for context: AIAnalysisRequestContext,
        question: String,
        selectedTag: VideoAnalysisTag
    ) -> String {
        let strategy = context.contentType.analysisStrategy
        return [
            "继续围绕当前分析会话回复用户问题。",
            "当前视频类型：\(context.contentType.title)。",
            "类型分析策略：\(strategy.roleDescription)",
            "当前分析标签：\(selectedTag.title)。",
            "标签分析要求：\(selectedTag.promptHint(for: context.contentType))",
            "用户问题：\(question.trimmed)",
            "请延续之前的判断，不要跳出当前标签视角。",
            "优先关注：\(strategy.focusAreas.joined(separator: "；"))",
            "避免跑偏：\(strategy.avoidances.joined(separator: "；"))",
            "输出严格 JSON，字段为 text、recommended_questions、visibility_note。",
            "text 用自然语言直接回答，可以引用前文结论，但不要重复整份首轮分析。",
            "recommended_questions 返回 2 到 3 个合适的后续追问。",
            "recommended_questions 要求：\(strategy.questionGuidance)",
            "visibility_note 仅在需要补充画面限制或信息不足时填写，否则返回空字符串。",
            "不要输出 Markdown，不要输出代码块，不要输出 JSON 之外的任何解释。"
        ].joined(separator: "\n")
    }

    private static let conversationSystemPrompt = """
    你是一名围绕单条篮球视频持续对话的 AI 教练。你必须只根据视频和已有会话上下文作答，围绕当前分析标签给出聚焦、可执行的反馈。看不清时要明确说明，不要猜测。所有输出必须是严格 JSON，不要 Markdown，不要代码块，不要额外解释。
    """

    private static func cleanedJSONString(from raw: String) -> String {
        var content = raw.trimmed

        if content.hasPrefix("```") {
            content = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmed
        }

        return content
    }
}

enum AIAnalysisServiceError: LocalizedError {
    case videoUnavailable
    case invalidResponse
    case emptyContent
    case unexpectedStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .videoUnavailable:
            "当前视频地址暂不可用于分析，请稍后重试。"
        case .invalidResponse:
            "AI 服务返回了无法识别的响应，请稍后重试。"
        case .emptyContent:
            "AI 服务没有返回有效内容，请重新尝试。"
        case .unexpectedStatusCode(let statusCode):
            "AI 服务请求失败（\(statusCode)），请稍后重试。"
        }
    }
}

private struct AIAnalysisResultPayload: Decodable {
    let headline: String
    let summary: String
    let focusPoints: [String]
    let recommendation: String

    enum CodingKeys: String, CodingKey {
        case headline
        case summary
        case focusPoints = "focus_points"
        case recommendation
    }
}

private struct AIConversationPayload: Decodable {
    let text: String
    let recommendedQuestions: [String]
    let visibilityNote: String?

    enum CodingKeys: String, CodingKey {
        case text
        case recommendedQuestions = "recommended_questions"
        case visibilityNote = "visibility_note"
    }
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
}

private struct ChatMessage: Encodable {
    let role: String
    let content: [ChatContent]
}

private struct ChatContent: Encodable {
    let type: String
    let text: String?
    let videoURL: VideoURLPayload?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case videoURL = "video_url"
    }

    static func text(_ text: String) -> ChatContent {
        ChatContent(type: "text", text: text, videoURL: nil)
    }

    static func videoURL(_ url: URL) -> ChatContent {
        ChatContent(type: "video_url", text: nil, videoURL: VideoURLPayload(url: url.absoluteString))
    }
}

private struct VideoURLPayload: Encodable {
    let url: String
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [Choice]
    let model: String?

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
