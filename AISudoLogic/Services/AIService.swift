//
//  AIService.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/7.
//

import Foundation

/// DeepSeek 对话消息。
struct ChatMessage: Identifiable, Encodable {
    let id: UUID
    let role: String
    var content: String

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    /// API 请求只编码 role/content,id 仅用于 UI 标识。
    private enum CodingKeys: String, CodingKey {
        case role, content
    }
}

/// DeepSeek API 请求体。
struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let thinking: Thinking?

    struct Thinking: Encodable {
        let type: String
        let reasoning_effort: String

        init(type: String, reasoningEffort: String = "low") {
            self.type = type
            self.reasoning_effort = reasoningEffort
        }
    }

    init(model: String, messages: [ChatMessage], stream: Bool, thinking: Thinking? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.thinking = thinking
    }
}

/// DeepSeek API 响应。
struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

/// DeepSeek API 流式响应块。
struct ChatStreamChunk: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
        }
        let delta: Delta?
    }
    let choices: [Choice]
}

/// DeepSeek API 服务:封装对话补全请求(支持流式 SSE)。
/// API key 从 UserDefaults 读取,避免硬编码。
final class AIService {

    static let shared = AIService()
    static let apiKeyDefaultsKey = "deepseek.apiKey"
    static let modelDefaultsKey = "deepseek.model"
    static let thinkingDefaultsKey = "deepseek.thinkingEnabled"

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let defaultModel = "deepseek-v4-flash"

    private init() {}

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.apiKeyDefaultsKey) }
    }

    /// 用户选择的模型(可配置)。
    var model: String {
        get { UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: Self.modelDefaultsKey) }
    }

    /// 是否启用思考模式(默认关闭,响应更快;可在 AI 教练配置中开启)。
    var thinkingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.thinkingDefaultsKey) == nil {
                return false  // 默认关闭
            }
            return UserDefaults.standard.bool(forKey: Self.thinkingDefaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.thinkingDefaultsKey) }
    }

    // MARK: - 日志

    /// 打印 AI 交互日志(带时间戳,含 URL、入参、出参、耗时)。上线前可关闭。
    private func log(_ message: String) {
        let ts = DateFormatter.logFormatter.string(from: Date())
        print("[AIService][\(ts)] \(message)")
    }

    private func logRequest(_ request: URLRequest, system: String, user: String) {
        log("请求 URL: \(request.url?.absoluteString ?? "nil")")
        log("HTTP 方法: \(request.httpMethod ?? "nil")")
        // 完整打印请求体(含 model / messages / stream / thinking 等所有入参)。
        if let body = request.httpBody, let json = String(data: body, encoding: .utf8) {
            log("请求体(完整): \(json)")
        } else {
            log("请求体: (无)")
        }
        // 单独列出关键入参便于快速定位。
        log("模型: \(model)")
        if let body = request.httpBody,
           let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            log("stream: \(obj["stream"] ?? "nil")")
            log("thinking: \(obj["thinking"] ?? "nil")")
        }
        log("system 提示词: \(system)")
        log("user 输入: \(user)")
    }

    /// 发送对话请求,返回模型回复文本。
    /// - Parameter thinkingType: "enabled" / "disabled"。默认 "disabled"(AI 提示等即时响应无需思考模式)。
    func chat(system: String, user: String, thinkingType: String = "disabled", timeout: TimeInterval = 120) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw AIError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user),
            ],
            stream: false,
            thinking: ChatRequest.Thinking(type: thinkingType)
        )
        request.httpBody = try JSONEncoder().encode(body)

        logRequest(request, system: system, user: user)
        let start = Date()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(start)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                log("响应: HTTP \(code),耗时 \(String(format: "%.2f", elapsed))s → 请求失败")
                throw AIError.httpError(statusCode: code)
            }
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let text = decoded.choices.first?.message.content else {
                log("响应: HTTP 200,耗时 \(String(format: "%.2f", elapsed))s → 空内容")
                throw AIError.emptyResponse
            }
            log("响应: HTTP 200,耗时 \(String(format: "%.2f", elapsed))s,内容长度 \(text.count)")
            log("出参(完整): \(text)")
            return text
        } catch {
            log("请求异常: \(error.localizedDescription)")
            throw error
        }
    }

    /// 流式对话:以 SSE 方式增量返回内容。
    /// - Parameters:
    ///   - onDelta: 每个内容增量回调(主线程外调用,调用方自行切主线程)。
    ///   - timeout: 请求超时。
    /// - Returns: 完整回复文本。
    func streamChat(
        system: String,
        user: String,
        thinkingType: String? = nil,
        timeout: TimeInterval = 120,
        onDelta: @escaping (String) -> Void
    ) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw AIError.missingAPIKey
        }

        // 未显式指定时,按用户的思考开关决定(AI 教练对话)。
        let resolvedThinking = thinkingType ?? (thinkingEnabled ? "enabled" : "disabled")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user),
            ],
            stream: true,
            thinking: ChatRequest.Thinking(type: resolvedThinking)
        )
        request.httpBody = try JSONEncoder().encode(body)

        logRequest(request, system: system, user: user)
        let start = Date()

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                log("流式响应: HTTP \(code),耗时 \(String(format: "%.2f", Date().timeIntervalSince(start)))s → 请求失败")
                throw AIError.httpError(statusCode: code)
            }

            var full = ""
            var chunkCount = 0
            for try await line in bytes.lines {
                // SSE 行形如 "data: {...}" 或 "data: [DONE]"
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" {
                    log("流式: 收到 [DONE] 结束标记")
                    break
                }

                if let data = payload.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(ChatStreamChunk.self, from: data),
                   let delta = chunk.choices.first?.delta?.content {
                    full += delta
                    chunkCount += 1
                    onDelta(delta)
                }
            }
            let elapsed = Date().timeIntervalSince(start)
            log("流式响应: HTTP 200,耗时 \(String(format: "%.2f", elapsed))s,\(chunkCount) 个增量块,总长度 \(full.count)")
            log("出参(完整): \(full)")
            return full
        } catch {
            log("流式请求异常: \(error.localizedDescription)")
            throw error
        }
    }
}

enum AIError: LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "尚未配置 API Key,请先在设置中填写"
        case .httpError(let code):
            return "请求失败(HTTP \(code))"
        case .emptyResponse:
            return "模型未返回内容"
        }
    }
}

extension DateFormatter {
    /// AIService 日志时间戳格式。
    static let logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}
