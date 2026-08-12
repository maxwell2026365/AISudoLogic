//
//  GameView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI

/// 游戏主界面:顶栏 + 棋盘 + 工具行 + 数字键盘。
/// 通过环境变量注入 ViewModel 与退出回调,跨平台共享同一布局主体。
struct GameView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @EnvironmentObject private var pinManager: PinManager
    let onExit: () -> Void
    var onShowAICoach: (() -> Void)? = nil
    var onRestart: (() -> Void)? = nil
    var isDailyMode: Bool = false
    @FocusState private var boardFocused: Bool
    /// 完成弹层是否显示;点空白处可关闭以查看已解棋盘。
    @State private var showCompletion = false

    var body: some View {
        GeometryReader { geo in
            // AI 提示区是否占据布局(有内容或占位时)。
            let hintVisible = viewModel.hintReason != nil || viewModel.showHintPlaceholder
            // 数字键盘铺满窗口后的实际宽度(窗口宽 - 两侧 12 padding)。
            let contentWidth = geo.size.width - 24
            // 顶栏 + 底部区块(工具栏 + 数字键盘)的固定高度预算。
            let chromeHeight = AppLayout.chromeHeight
            // AI 提示区展开时预留的高度(固定值,布局稳定)。
            let hintReserve: CGFloat = hintVisible ? AppLayout.hintHeight : 0
            // 剩余可给棋盘的高度,精确包含棋盘卡片自身的纵向 padding(上 8 + 下 8)。
            let availableHeight = max(geo.size.height - chromeHeight - hintReserve - AppLayout.boardPadding, 260)
            // 棋盘边长:同时受宽度与高度约束,填入全部可用空间且保持正方形。
            let boardSide = min(contentWidth, availableHeight)

            VStack(spacing: 0) {
                topBar
                // AI 提示区:有提示内容或占位时显示(组件始终保留)。
                if hintVisible {
                    hintArea
                        .frame(width: boardSide)
                }
                // 棋盘:撑满宽度,保持正方形。
                BoardView(
                    puzzle: viewModel.puzzle,
                    selectedIndex: viewModel.selectedIndex,
                    highlightedValue: viewModel.selectedIndex.map { viewModel.puzzle.cells[$0] }.flatMap { $0 == 0 ? nil : $0 },
                    hintIndex: viewModel.hintIndex,
                    wrongCells: viewModel.puzzle.wrongCells,
                    onSelect: { index in
                        viewModel.select(index)
                        boardFocused = true
                    }
                )
                .frame(width: boardSide, height: boardSide)
                .padding(.top, 4)
                ToolbarView(
                    isNoteMode: viewModel.isNoteMode,
                    canUndo: viewModel.canUndo,
                    canRedo: viewModel.canRedo,
                    canErase: viewModel.canErase,
                    onNoteMode: { viewModel.isNoteMode.toggle() },
                    onUndo: viewModel.undo,
                    onRedo: viewModel.redo,
                    onErase: viewModel.erase,
                    onHint: viewModel.requestHint,
                    onFullAnswer: viewModel.toggleFullAnswer,
                    onAIComplete: viewModel.completeWithAI,
                    isPinned: pinManager.isPinned,
                    onPin: { pinManager.toggle() }
                )
                .padding(.vertical, 4)
                NumberPadView(
                    selectedValue: viewModel.selectedIndex.flatMap { viewModel.puzzle.cells[$0] }.flatMap { $0 == 0 ? nil : $0 },
                    onNumber: viewModel.inputNumber
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .overlay {
            if viewModel.isPaused {
                PauseOverlay(resume: viewModel.resumeTimer, exit: onExit)
            }
            if showCompletion {
                CompletionOverlay(
                    elapsed: viewModel.elapsed,
                    difficulty: viewModel.puzzle.difficulty,
                    errors: viewModel.errors,
                    onRestart: restart,
                    onExit: onExit,
                    onDismiss: { withAnimation { showCompletion = false } }
                )
            }
            if viewModel.showFullAnswer {
                FullAnswerOverlay(
                    puzzle: viewModel.puzzle,
                    onClose: viewModel.toggleFullAnswer
                )
            }
        }
        .task {
            viewModel.startTimer()
            // 进入游戏立即调用 AI 提示,横幅与棋盘同时渲染,文字流式打印。
            viewModel.requestHint()
        }
        .onAppear {
            boardFocused = true
        }
        .onChange(of: viewModel.isPaused) { paused in
            if paused { viewModel.pauseTimer() } else { viewModel.resumeTimer() }
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed { showCompletion = true }
        }
        // 键盘输入:仅 iOS 17+ / macOS 14+ 支持声明式键盘处理。
        // 低版本平台降级为纯触摸/鼠标操作。
        .modifier(KeyboardHandlingModifier(viewModel: viewModel))
        .focused($boardFocused)
    }

    /// AI 提示区:棋盘上方,有提示内容或占位时显示。文字清空后保留占位。
    private var hintArea: some View {
        HintReasonBanner(
            reason: viewModel.hintReason ?? "💡 点击「AI 提示」获取当前盘面的下一步突破点建议",
            technique: viewModel.hintTechnique
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var topBar: some View {
        HStack {
            Button {
                onExit()
            } label: {
                Label("返回", systemImage: "chevron.left")
                    .font(.body)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.puzzle.difficulty.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formatTime(viewModel.elapsed))
                .font(.system(.body, design: .monospaced))

            Button {
                withAnimation { viewModel.isPaused = true }
            } label: {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("暂停")

            if let onShowAICoach {
                Button(action: onShowAICoach) {
                    Image(systemName: "sparkles")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("AI 教练")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
#if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
#endif
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private func restart() {
        showCompletion = false
        onRestart?()
        // 新局:后台生成,避免高难度卡 UI。
        let difficulty = viewModel.puzzle.difficulty
        Task {
            let newPuzzle = await Task.detached(priority: .userInitiated) {
                SudokuGenerator.generate(difficulty: difficulty)
            }.value
            withAnimation {
                viewModel.replaceWith(newPuzzle)
            }
            viewModel.startTimer()
        }
    }
}

/// 暂停覆盖层。
struct PauseOverlay: View {
    let resume: () -> Void
    let exit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("已暂停")
                    .font(.title2.bold())
                Button(action: resume) {
                    Label("继续", systemImage: "play.fill")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                Button(action: exit) {
                    Text("返回菜单")
                }
                .buttonStyle(.bordered)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// 完成覆盖层:点击弹层外部区域可关闭,以便查看已解出的棋盘。
struct CompletionOverlay: View {
    let elapsed: TimeInterval
    let difficulty: Difficulty
    let errors: Int
    let onRestart: () -> Void
    let onExit: () -> Void
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // 透明背景:点击即关闭弹层,露出完整棋盘。
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss?() }
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 56))
                Text("完成!")
                    .font(.title.bold())
                VStack(spacing: 8) {
                    statRow(label: "用时", value: formatTime(elapsed))
                    statRow(label: "难度", value: difficulty.displayName)
                    statRow(label: "错误", value: "\(errors) 次")
                }
                .padding(.vertical, 8)
                HStack(spacing: 12) {
                    Button(action: onRestart) {
                        Text("再来一局").frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: onExit) {
                        Text("返回菜单").frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                }
                Button(action: { onDismiss?() }) {
                    Text("查看棋盘")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            // 点击卡片空白处(按钮之外的区域)同样关闭弹层。
            .contentShape(Rectangle())
            .onTapGesture { onDismiss?() }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .frame(width: 180)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

/// AI 提示横幅:overlay 在棋盘顶部,贴合棋盘宽度,展示突破点分析(技巧标签 + AI 解释)。
/// 无需手动关闭——提示格被填值或选中其他格时自动消失。内容超限时可滚动。
struct HintReasonBanner: View {
    let reason: String
    let technique: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("AI 突破点")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if let technique {
                    Text(technique)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
            }
            .frame(height: AppLayout.hintTitleHeight)
            // 解释文本:渲染 markdown,在固定高度卡片内滚动,保证提示区高度稳定。
            ScrollView(showsIndicators: true) {
                MarkdownBubble(markdown: reason)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(10)
        .frame(height: AppLayout.hintHeight)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

/// 全盘答案覆盖层:展示成最大正方形,"AI 全盘答案"作为居中标题。
struct FullAnswerOverlay: View {
    let puzzle: SudokuPuzzle
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // 全盘答案:不透明背景,完全遮住棋盘。
#if os(macOS)
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
#else
            Color(.systemBackground).ignoresSafeArea()
#endif
            // 最大正方形答案区。
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                // 扣除 8 个 1pt 间距,格子精确撑满 side。
                let cell = (side - 8) / 9
                let fontSize = cell * 0.55

                VStack(spacing: 0) {
                    // 标题水平居中,关闭按钮在右上角。
                    ZStack {
                        Text("AI 全盘答案")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        HStack {
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("关闭")
                        }
                    }
                    .frame(height: 30)
                    .padding(.bottom, 8)

                    // 答案网格:精确 side 宽,水平居中。
                    VStack(spacing: 1) {
                        ForEach(0..<9, id: \.self) { row in
                            HStack(spacing: 1) {
                                ForEach(0..<9, id: \.self) { col in
                                    let index = row * 9 + col
                                    Text("\(puzzle.solution[index])")
                                        .font(.system(size: fontSize, weight: puzzle.givens[index] ? .bold : .regular, design: .rounded))
                                        .foregroundStyle(puzzle.givens[index] ? Color.primary : Color.accentColor)
                                        .frame(width: cell, height: cell)
                                        .background(boxTint(index))
                                }
                            }
                        }
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .frame(maxWidth: side, maxHeight: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    /// 按 3×3 宫给格子轻微底色,模拟棋盘分宫。
    private func boxTint(_ index: Int) -> Color {
        let box = SudokuPuzzle.box(of: index)
        return box % 2 == 0 ? Color.primary.opacity(0.04) : Color.primary.opacity(0.08)
    }
}

/// 键盘操作修饰符:仅 iOS 17+ / macOS 14+ 启用声明式键盘处理。
/// 低版本平台降级为纯触摸/鼠标操作。
struct KeyboardHandlingModifier: ViewModifier {
    @ObservedObject var viewModel: GameViewModel

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .focusable()
                .focusEffectDisabled()
                .onKeyPress(.return) { viewModel.resumeTimer(); return .handled }
                .onKeyPress(.upArrow) { viewModel.moveSelection(dRow: -1, dCol: 0); return .handled }
                .onKeyPress(.downArrow) { viewModel.moveSelection(dRow: 1, dCol: 0); return .handled }
                .onKeyPress(.leftArrow) { viewModel.moveSelection(dRow: 0, dCol: -1); return .handled }
                .onKeyPress(.rightArrow) { viewModel.moveSelection(dRow: 0, dCol: 1); return .handled }
                .onKeyPress(.delete) { viewModel.erase(); return .handled }
                .onKeyPress(.escape) { withAnimation { viewModel.isPaused = true }; return .handled }
                .onKeyPress(characters: .alphanumerics, phases: .down) { press in
                    if let value = Int(press.characters), (1...9).contains(value) {
                        viewModel.inputNumber(value)
                        return .handled
                    }
                    return .ignored
                }
        } else {
            content
        }
    }
}
