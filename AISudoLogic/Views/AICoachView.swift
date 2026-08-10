//
//  AICoachView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/7.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// AI 教练面板:对话框 + 建议功能按钮。
struct AICoachView: View {
    @EnvironmentObject private var coach: AICoachViewModel
    /// 当前盘面(来自游戏页)或 nil(来自菜单)。
    let puzzle: SudokuPuzzle?
    /// 完成历史(用于个性化推荐)。
    let history: [GameSession]
    /// 返回上一级。
    var onBack: (() -> Void)? = nil
    @State private var inputText = ""
    @State private var showAPIKeySheet = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    // 用 VStack 而非 LazyVStack:消息数有限,完整渲染保证 scrollTo 总能定位
                    // 到任意消息(LazyVStack 惰性渲染会让屏幕外的目标无法被 scrollTo 找到)。
                    VStack(spacing: 10) {
                        ForEach(coach.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if coach.isThinking {
                            HStack {
                                ProgressView()
                                Text("思考中…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                        }
                        if let err = coach.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(12)
                }
                // 新消息加入(用户提问 / AI 回复开始插入占位)时自动滚到底部。
                .onChange(of: coach.messages.count) { _ in
                    scrollToBottom(proxy)
                }
                // 思考结束(完整回复生成完毕)时滚到底部,确保看到完整内容。
                .onChange(of: coach.isThinking) { thinking in
                    if !thinking { scrollToBottom(proxy) }
                }
                // 流式回复期间持续滚到底部,让内容始终跟随大模型输出。
                // 用节流避免每个字符增量都触发 scrollTo(高频布局计算会卡死主线程)。
                .onChange(of: coach.messages.last?.content) { _ in
                    guard coach.isThinking else { return }
                    scheduleAutoScroll(proxy)
                }
            }

            suggestionBar
            inputBar
        }
    }

    /// 流式自动滚动的节流任务:每 300ms 最多滚动一次,避免主线程被 scrollTo 打满。
    @State private var autoScrollTask: Task<Void, Never>?

    private func scheduleAutoScroll(_ proxy: ScrollViewProxy) {
        guard autoScrollTask == nil else { return }
        autoScrollTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            scrollToBottom(proxy)
            autoScrollTask = nil
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = coach.messages.last else { return }
        // 无动画即时滚动:避免带动画的 scrollTo 在 iOS 上持续打断用户手势。
        // VStack 完整渲染,scrollTo 一定能定位到目标。
        proxy.scrollTo(last.id, anchor: .bottom)
    }

    private var header: some View {
        HStack {
            // 返回按钮:放在左上角。
            if let onBack {
                Button(action: onBack) {
                    Label("返回", systemImage: "chevron.left")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
            }
            Text("🤖 数独 AI 教练")
                .font(.headline)
            Spacer()
            Button {
                showAPIKeySheet = true
            } label: {
                Image(systemName: "key.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("配置 API Key")
        }
        .padding(14)
        .background(.thinMaterial)
        .sheet(isPresented: $showAPIKeySheet) {
            APIKeySheet()
        }
    }

    /// 建议功能快捷按钮。
    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if puzzle != nil {
                    suggestionButton("💡 下一步思路") {
                        Task { await coach.nextStepHint(puzzle: puzzle!) }
                    }
                    suggestionButton("📊 难度评估") {
                        Task { await coach.evaluateDifficulty(puzzle: puzzle!) }
                    }
                    suggestionButton("🎯 针对性练习") {
                        Task { await coach.targetedPractice(puzzle: puzzle, skill: "X-Wing") }
                    }
                }
                suggestionButton("🧭 推荐新局") {
                    Task { await coach.recommendNext(history: history, puzzle: puzzle) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func suggestionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .disabled(coach.isThinking)
    }

    /// 底部输入栏:固定 3 行高度,内容超 3 行时内部滚动。
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $inputText)
                .font(.subheadline)
                .modifier(ScrollContentBackgroundModifier())
                .padding(6)
                .frame(height: 76)  // 固定 3 行,超长内部滚动
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("和 AI 聊聊数独…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                    }
                }
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || coach.isThinking)
            // 隐藏按钮:⌘↩ 发送(Enter 在 TextEditor 中保持换行)。
            .background {
                Button("发送") { send() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .hidden()
            }
        }
        .padding(12)
        .background(.thinMaterial)
#if os(macOS)
        .overlay(alignment: .bottom) {
            // 快捷键提示(仅 macOS):置灰展示,提示用户 ⌘↩ 发送、⏎ 换行。
            Text("⌘↩ 发送   ⏎ 换行")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.top, 2)
                .padding(.bottom, 1)
        }
#endif
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await coach.ask(puzzle: puzzle, question: text) }
    }
}

/// 单个聊天气泡,带昵称标识与一键复制。
struct MessageBubble: View {
    let message: ChatMessage
    @State private var copied = false

    /// 昵称:AI 显示 Deepseek,用户显示 User。
    private var nickname: String {
        message.role == "user" ? "User" : "Deepseek"
    }

    var body: some View {
        let isUser = message.role == "user"
        HStack(alignment: .bottom) {
            // AI 头像(左侧)
            if !isUser {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.25, blue: 0.85), Color(red: 0.16, green: 0.45, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay {
                        Text("AI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 20)
            }
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // 昵称标签
                Text(nickname)
                    .font(.caption2.bold())
                    .foregroundStyle(isUser ? Color.accentColor : Color.secondary)
                bubbleContent
                // 复制按钮
                Button {
                    copyToPasteboard(message.content)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.7)
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let isUser = message.role == "user"
        if isUser {
            Text(message.content)
                .font(.subheadline)
                .textSelection(.enabled)
                .padding(12)
                .background(
                    Color.accentColor.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .frame(maxWidth: 400, alignment: .trailing)
        } else {
            MarkdownBubble(markdown: message.content)
                .padding(12)
                .background(
                    Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .frame(maxWidth: 400, alignment: .leading)
        }
    }

    /// 跨平台复制到剪贴板。
    private func copyToPasteboard(_ text: String) {
#if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
#else
        UIPasteboard.general.string = text
#endif
    }
}

/// 用 SwiftUI 渲染 AI 返回的 markdown,支持标题、列表、加粗、代码块等。
struct MarkdownBubble: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    /// 把 markdown 按行解析成块(标题/列表项/代码/段落/表格)。
    /// internal 便于单元测试验证解析结果。
    var blocks: [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var codeBuffer: [String] = []
        var inCode = false
        var i = 0
        let lines = markdown.components(separatedBy: "\n")

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("```") {
                if inCode {
                    result.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                }
                inCode.toggle()
                i += 1
            } else if inCode {
                codeBuffer.append(line)
                i += 1
            } else if line.isEmpty {
                i += 1
            } else if isTableSeparator(line) {
                // 表格分隔行,属于上一行开始的表格;跳到下一行。
                i += 1
            } else if isTableRow(line),
                      i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                // 表格:收集所有连续的表头/分隔/数据行。
                var tableLines = [line]
                i += 1
                while i < lines.count, isTableSeparator(lines[i]) || isTableRow(lines[i]) {
                    if !isTableSeparator(lines[i]) {
                        tableLines.append(lines[i])
                    }
                    i += 1
                }
                result.append(table(tableLines))
            } else if line.hasPrefix("### ") {
                result.append(.heading(3, String(line.dropFirst(4))))
                i += 1
            } else if line.hasPrefix("## ") {
                result.append(.heading(2, String(line.dropFirst(3))))
                i += 1
            } else if line.hasPrefix("# ") {
                result.append(.heading(1, String(line.dropFirst(2))))
                i += 1
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(.bullet(String(line.dropFirst(2))))
                i += 1
            } else if let orderContent = orderedListPrefix(line) {
                result.append(.numbered(orderContent))
                i += 1
            } else {
                result.append(.paragraph(line))
                i += 1
            }
        }
        if inCode, !codeBuffer.isEmpty {
            result.append(.code(codeBuffer.joined(separator: "\n")))
        }
        return result
    }

    /// 是否是 markdown 表格行(以 | 开头或含多个 |)。
    private func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.count > 1
    }

    /// 是否是表格分隔行,如 "|---|---|" 或 "|:--:|--|"。
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else { return false }
        let body = trimmed.dropFirst().dropLast()
        // 分隔行只能由 -, :, 空格, | 组成。
        let allowed: Set<Character> = ["-", ":", " ", "|"]
        guard !body.isEmpty else { return false }
        return body.allSatisfy { allowed.contains($0) }
            && body.contains("-")
            && !body.contains(where: { $0.isLetter || $0.isNumber })
    }

    /// 把表格行解析成单元格数组(去首尾 |,按 | 切分)。
    private func tableCells(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let dropped = trimmed.dropFirst().dropLast()
        return dropped.split(separator: "|").map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
    }

    /// 构造表格块。
    private func table(_ lines: [String]) -> MarkdownBlock {
        // 首行为表头,其余为数据行。
        let header = tableCells(lines.first ?? "")
        let rows = lines.dropFirst().map { tableCells($0) }
        return .table(header: header, rows: rows)
    }

    /// 匹配 "1. "、"2. " 等有序列表前缀,返回列表项内容。
    private func orderedListPrefix(_ line: String) -> String? {
        var idx = line.startIndex
        var digits = ""
        while idx < line.endIndex, line[idx].isNumber {
            digits.append(line[idx])
            idx = line.index(after: idx)
        }
        guard !digits.isEmpty, idx < line.endIndex,
              line[idx] == ".", line.index(after: idx) < line.endIndex else {
            return nil
        }
        let contentStart = line.index(idx, offsetBy: 2)
        return String(line[contentStart...])
    }
}

/// 单个 markdown 块。
enum MarkdownBlock {
    case heading(Int, String)
    case bullet(String)
    case numbered(String)
    case code(String)
    case paragraph(String)
    case table(header: [String], rows: [[String]])

    @ViewBuilder var view: some View {
        switch self {
        case .heading(let level, let text):
            // LocalizedStringKey 解析内联 markdown(加粗/斜体/行内代码)。
            Text(LocalizedStringKey(text))
                .font(.system(size: headingSize(level), weight: .bold))
                .padding(.top, level <= 2 ? 6 : 0)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.subheadline)
                Text(LocalizedStringKey(text))
                    .font(.subheadline)
            }
        case .numbered(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("·")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(text))
                    .font(.subheadline)
            }
        case .code(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        case .paragraph(let text):
            Text(LocalizedStringKey(text))
                .font(.subheadline)
        case .table(let header, let rows):
            MarkdownTableView(header: header, rows: rows)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 20
        case 2: return 17
        default: return 15
        }
    }
}

/// markdown 表格渲染:表头 + 数据行,列等宽铺满容器。
private struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]

    /// 实际列数 = 表头与数据行中最大的单元格数。
    private var columnCount: Int {
        max(header.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                ForEach(0..<columnCount, id: \.self) { col in
                    tableCell(header, col)
                        .font(.caption.bold())
                        .background(Color.black.opacity(0.1))
                        .overlay(alignment: .trailing) { verticalDivider }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            // 数据行
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(0..<columnCount, id: \.self) { col in
                        tableCell(row, col)
                            .background(index % 2 == 0 ? Color.black.opacity(0.03) : .clear)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .font(.caption)
    }

    /// 单元格内容(越界取空串)。
    private func tableCell(_ cells: [String], _ col: Int) -> some View {
        let text = col < cells.count ? cells[col] : ""
        return Text(LocalizedStringKey(text))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: 0.5)
    }
}

/// TextEditor 背景隐藏修饰符:iOS 16+ / macOS 13+ 使用原生 API,旧版本无操作。
private struct ScrollContentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

#Preview("Markdown") {
    MarkdownBubble(markdown: """
    # 标题
    ## 副标题
    这是**加粗**和*斜体*文字。
    - 项目一
    - 项目二
    1. 第一步
    2. 第二步
    ```swift
    let x = 1
    ```
    | 技巧 | 说明 | 示例 |
    |------|------|------|
    | 裸单 | 只剩一个候选 | 3 |
    | 排除法 | 单元唯一位置 | 7 |
    | X-Wing | 行列候选消去 | 9 |
    """)
    .padding()
}

#Preview("Coach") {
    AICoachView(puzzle: nil, history: [])
        .environmentObject(AICoachViewModel())
        .frame(width: 380, height: 520)
}

/// API Key 配置弹窗。
struct APIKeySheet: View {
    @EnvironmentObject private var coach: AICoachViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var model = ""
    @State private var thinkingEnabled = false

    var body: some View {
        VStack(spacing: 16) {
            Text("配置 AI 服务")
                .font(.headline)
            Text("Key 与模型仅保存在本机。模型可填任意 DeepSeek 模型名。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SecureField("DeepSeek API Key", text: $key)
                .textFieldStyle(.roundedBorder)
            TextField("模型(默认 deepseek-v4-flash)", text: $model)
                .textFieldStyle(.roundedBorder)
            Toggle(isOn: $thinkingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("模型思考模式")
                    Text("关闭后响应更快,但推理质量可能降低")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Button("保存") {
                    coach.setAPIKey(key.trimmingCharacters(in: .whitespaces))
                    coach.setModel(model.trimmingCharacters(in: .whitespaces))
                    coach.setThinkingEnabled(thinkingEnabled)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear {
            key = AIService.shared.apiKey ?? ""
            model = AIService.shared.model
            thinkingEnabled = AIService.shared.thinkingEnabled
        }
    }
}
