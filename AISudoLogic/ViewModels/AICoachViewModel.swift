//
//  AICoachViewModel.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/7.
//

import Foundation
import Combine

/// AI 教练:基于 DeepSeek 的数独智能助手。
/// 提供解题思路教练、难度评估、个性化推荐、针对性练习、自然语言对话。
@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isThinking = false
    @Published var errorMessage: String?

    private let service = AIService.shared

    init() {
        // 欢迎语。
        messages.append(ChatMessage(role: "assistant", content: "你好!我是你的数独 AI 教练,可以帮你分析盘面、给出解题思路、评估难度、推荐新局。想试试吗?"))
    }

    // MARK: - 盘面上下文

    /// 把当前数独盘面编码成 AI 可读的字符串(81 位,0=空格)。
    func boardString(from puzzle: SudokuPuzzle) -> String {
        puzzle.cells.map { String($0) }.joined()
    }

    /// 分行展示盘面(每行 9 个数字),便于 AI 理解行列结构。
    private func boardRows(from puzzle: SudokuPuzzle) -> String {
        (0..<9).map { row in
            let cells = (0..<9).map { "\(puzzle.cells[row * 9 + $0])" }.joined(separator: " ")
            return "第\(row + 1)行: \(cells)"
        }.joined(separator: "\n")
    }

    /// 根据当前盘面生成 user 提问(含盘面上下文:现状、进度、错误)。
    private func buildUserQuery(puzzle: SudokuPuzzle, question: String) -> String {
        let filled = puzzle.cells.filter { $0 != 0 }.count
        let errors = puzzle.wrongCells.count
        let progress = Int(Double(filled) / 81.0 * 100)
        return """
        当前数独盘面现状:
        \(boardRows(from: puzzle))

        盘面信息:
        - 难度:\(puzzle.difficulty.displayName)
        - 已填 \(filled)/81 格(进度约 \(progress)%),其中 \(errors) 处与答案不符
        - 81 位数字编码(按行优先,0 表示空格):\(boardString(from: puzzle))

        问题:\(question)
        """
    }

    /// 用户在对话框中看到的展示文本:标题 + 格式化盘面(用户可读的方格内容)。
    private func buildDisplayText(title: String, puzzle: SudokuPuzzle) -> String {
        """
        \(title)

        📋 当前盘面(0=空格):
        \(boardRows(from: puzzle))
        """
    }

    // MARK: - 系统提示词

    /// 数独专家系统提示词。
    private var systemPrompt: String {
        """
        你是数独领域的资深教练和 AI 助手,精通数独规则、解题技巧(裸单/唯一候选/排除法/隐性唯一/数对/区块/X-Wing/Swordfish 等)。

        你的职责:
        1. 分析用户提供的数独盘面,给出当前最优的下一步和详细推理过程。
        2. 评估盘面的整体难度(新手/进阶/专家),并说明依据。
        3. 根据玩家的历史表现推荐合适的难度与练习方向。
        4. 针对用户卡住的技巧,提供专门的练习思路。
        5. 用自然语言解答任何数独相关问题。

        回答要求:
        - 用中文回答,语气耐心、鼓励、专业。
        - 推理过程要具体:明确指出行列宫位置、可排除的数字、为何确定。
        - 盘面索引说明:第r行第c列(1-9 计数)。
        - 不直接给出整盘答案,除非用户明确要求。
        """
    }

    // MARK: - 公开方法

    /// 通用对话:用户提问。displayText 用于 UI 气泡,userContent 是发给 API 的完整内容。
    func ask(puzzle: SudokuPuzzle?, question: String, displayText: String? = nil) async {
        let userContent: String
        let userDisplay: String
        if let puzzle {
            userContent = buildUserQuery(puzzle: puzzle, question: question)
            userDisplay = buildDisplayText(title: displayText ?? "分析盘面", puzzle: puzzle)
        } else {
            userContent = question
            userDisplay = displayText ?? question
        }
        await send(system: systemPrompt, user: userContent, displayText: userDisplay)
    }

    /// 下一步思路教练(基于当前盘面)。
    func nextStepHint(puzzle: SudokuPuzzle) async {
        await ask(puzzle: puzzle, question: "请分析当前盘面,给我一个最合理的下一步建议,并详细解释推理过程。", displayText: "💡 下一步思路")
    }

    /// 智能难度评估。
    func evaluateDifficulty(puzzle: SudokuPuzzle) async {
        await ask(puzzle: puzzle, question: "请评估这局数独的人类难度(新手/进阶/专家),并说明依据——用到了哪些解题技巧,哪里是卡点。", displayText: "📊 难度评估")
    }

    /// 个性化推荐(基于完成历史)。
    func recommendNext(history: [GameSession], puzzle: SudokuPuzzle? = nil) async {
        let summary: String
        if history.isEmpty {
            summary = "还没有完成记录"
        } else {
            summary = history.prefix(10).map {
                "\($0.difficulty.displayName) 用时\(Int($0.elapsed))秒 错误\($0.errors)次"
            }.joined(separator: "; ")
        }
        let question = "我的完成记录:\(summary)。请根据我的表现推荐接下来适合的难度,并说明理由。"
        await ask(puzzle: puzzle, question: question, displayText: "🧭 推荐新局")
    }

    /// 针对性练习:针对卡住的技巧。
    func targetedPractice(puzzle: SudokuPuzzle?, skill: String) async {
        let question = "我想针对'\(skill)'这个技巧做针对性练习。请解释这个技巧的原理,并建议我如何在当前盘面中应用它(如有盘面)。"
        await ask(puzzle: puzzle, question: question, displayText: "🎯 针对性练习")
    }

    // MARK: - 内部

    private func send(system: String, user: String, displayText: String? = nil) async {
        messages.append(ChatMessage(role: "user", content: displayText ?? user))
        isThinking = true
        errorMessage = nil

        // 先插入一个空的 assistant 消息,流式过程中逐步填充。
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: "assistant", content: ""))

        do {
            let reply = try await service.streamChat(system: system, user: user) { [weak self] delta in
                // 合并流式 delta:累积到缓冲区,节流地更新 UI,避免每个字符
                // 都触发 @Published 更新导致主线程被高频重渲染打满(卡死)。
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.pendingDelta += delta
                    self.throttleUIUpdateIfNeeded()
                }
            }
            // 兜底:若流式未回填(如空),直接用最终文本。
            if let idx = messages.firstIndex(where: { $0.id == assistantID }), messages[idx].content.isEmpty {
                messages[idx].content = reply
            }
        } catch {
            // 移除空的 assistant 占位,展示错误。
            messages.removeAll { $0.id == assistantID }
            errorMessage = error.localizedDescription
        }
        // 流式结束:刷新一次 pending 缓冲,确保最后内容展示。
        flushPendingDelta()
        isThinking = false
    }

    /// 待合并的流式增量文本(仅用于节流刷新)。
    private var pendingDelta = ""
    /// 节流刷新的定时任务。
    private var uiThrottleTask: Task<Void, Never>?

    /// 合并 delta 到 messages:每 80ms 最多更新一次 UI,显著降低主线程渲染频率。
    private func throttleUIUpdateIfNeeded() {
        guard !pendingDelta.isEmpty else { return }
        guard uiThrottleTask == nil else { return }
        let buffer = pendingDelta
        pendingDelta = ""
        guard let idx = messages.lastIndex(where: { $0.role == "assistant" }) else { return }
        messages[idx].content += buffer

        uiThrottleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            uiThrottleTask = nil
            guard !pendingDelta.isEmpty else { return }
            throttleUIUpdateIfNeeded()
        }
    }

    /// 流式结束后刷新残留缓冲。
    private func flushPendingDelta() {
        guard !pendingDelta.isEmpty else { return }
        let buffer = pendingDelta
        pendingDelta = ""
        guard let idx = messages.lastIndex(where: { $0.role == "assistant" }) else { return }
        messages[idx].content += buffer
        uiThrottleTask?.cancel()
        uiThrottleTask = nil
    }

    /// 配置 API key。
    func setAPIKey(_ key: String) {
        service.apiKey = key
    }

    /// 配置模型名(空则用默认)。
    func setModel(_ model: String) {
        if !model.isEmpty {
            service.model = model
        }
    }

    /// 配置是否启用思考模式。
    func setThinkingEnabled(_ enabled: Bool) {
        service.thinkingEnabled = enabled
    }

    /// 当前思考模式开关状态。
    var isThinkingEnabled: Bool {
        service.thinkingEnabled
    }
}
