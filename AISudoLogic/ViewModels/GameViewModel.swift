//
//  GameViewModel.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import Foundation
import Combine

/// 一局数独的撤销步骤:记录单个格子的值或笔记变化。
struct MoveStep: Codable, Equatable {
    var index: Int
    var oldValue: Int
    var newValue: Int
    var oldNotes: Set<Int>
    var newNotes: Set<Int>
}

/// 数独游戏状态机,由 App 作为 environmentObject 注入。
final class GameViewModel: ObservableObject {

    // MARK: - 盘面

    @Published private(set) var puzzle: SudokuPuzzle
    /// 已用错误次数(用于提示与统计)。
    @Published private(set) var errors = 0
    /// 是否已完成。
    @Published private(set) var isCompleted = false

    // MARK: - 交互状态

    /// 当前选中的格子(0-80)。
    @Published var selectedIndex: Int?
    /// 笔记模式(铅笔)。
    @Published var isNoteMode = false
    /// 提示高亮的目标格。
    @Published var hintIndex: Int?
    /// AI 提示的理由文本(展示在方格旁)。
    @Published var hintReason: String?
    /// AI 提示用到的技巧标签(如"唯一候选")。
    @Published var hintTechnique: String?
    /// 是否显示 AI 提示占位(组件保留,提示用户可用 AI)。
    @Published var showHintPlaceholder = false
    /// 是否展示全盘答案(全盘提示)。
    @Published var showFullAnswer = false
    /// 是否暂停。
    @Published var isPaused = false

    // MARK: - 计时

    /// 从开局到现在的已用时间(秒)。
    @Published private(set) var elapsed: TimeInterval = 0
    private var timer: Timer?
    private var lastTick: Date?

    // MARK: - 撤销

    private var undoStack: [MoveStep] = []
    private var redoStack: [MoveStep] = []

    // MARK: - 初始化

    init(puzzle: SudokuPuzzle) {
        self.puzzle = puzzle
    }

    deinit {
        timer?.invalidate()
    }

    /// 方向键移动选格。
    func moveSelection(dRow: Int, dCol: Int) {
        guard let idx = selectedIndex else {
            selectedIndex = 40  // 默认中心
            return
        }
        let r = SudokuPuzzle.row(of: idx) + dRow
        let c = SudokuPuzzle.col(of: idx) + dCol
        guard (0..<9).contains(r), (0..<9).contains(c) else { return }
        select(SudokuPuzzle.index(row: r, col: c))
    }

    // MARK: - 选中与输入

    func select(_ index: Int) {
        guard index >= 0, index < 81 else { return }
        selectedIndex = index
        // 选中新格时清除提示。
        if hintIndex != nil, hintIndex != index {
            dismissHint()
        }
    }

    /// 输入一个数字:笔记模式 → 切换笔记;否则填值。
    func inputNumber(_ value: Int) {
        guard !isPaused, !isCompleted, (1...9).contains(value) else { return }
        if isNoteMode {
            toggleNote(value)
        } else {
            placeValue(value)
        }
    }

    /// 填入/覆盖数字。
    func placeValue(_ value: Int) {
        guard let idx = selectedIndex, !puzzle.givens[idx] else { return }
        let oldValue = puzzle.cells[idx]
        let oldNotes = puzzle.notes[idx]
        guard oldValue != value else { return }

        let step = MoveStep(
            index: idx, oldValue: oldValue, newValue: value,
            oldNotes: oldNotes, newNotes: []
        )
        record(step)

        puzzle.set(value, at: idx)
        puzzle.clearNotes(at: idx)

        // 填的正是提示格 → 提示已完成使命,自动消失,无需手动关闭。
        if hintIndex == idx {
            dismissHint()
        }

        if value != puzzle.solution[idx] {
            errors += 1
        } else {
            // 自动清理同行/列/宫中该数字的笔记。
            autoCleanNotes(for: value, excluding: idx)
        }

        checkCompletion()
    }

    /// 擦除当前格的值。
    func erase() {
        guard let idx = selectedIndex, !puzzle.givens[idx],
              puzzle.cells[idx] != 0 else { return }
        let oldValue = puzzle.cells[idx]
        let step = MoveStep(
            index: idx, oldValue: oldValue, newValue: 0,
            oldNotes: puzzle.notes[idx], newNotes: puzzle.notes[idx]
        )
        record(step)
        puzzle.set(0, at: idx)
    }

    /// 笔记模式下切换候选。
    private func toggleNote(_ value: Int) {
        guard let idx = selectedIndex, !puzzle.givens[idx],
              puzzle.cells[idx] == 0 else { return }
        let oldNotes = puzzle.notes[idx]
        var newNotes = oldNotes
        if newNotes.contains(value) {
            newNotes.remove(value)
        } else {
            newNotes.insert(value)
        }
        guard newNotes != oldNotes else { return }
        record(MoveStep(
            index: idx, oldValue: 0, newValue: 0,
            oldNotes: oldNotes, newNotes: newNotes
        ))
        puzzle.notes[idx] = newNotes
    }

    // MARK: - 撤销/重做

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// 当前选中格是否有可擦除的玩家填入值。
    var canErase: Bool {
        guard let idx = selectedIndex, !puzzle.givens[idx] else { return false }
        return puzzle.cells[idx] != 0
    }

    func undo() {
        guard let step = undoStack.popLast() else { return }
        apply(step, reversed: true)
        redoStack.append(step)
    }

    func redo() {
        guard let step = redoStack.popLast() else { return }
        apply(step, reversed: false)
        undoStack.append(step)
    }

    /// 撤销/重做会改变错误计数与完成状态,简单方式:重新扫描盘面。
    private func apply(_ step: MoveStep, reversed: Bool) {
        if reversed {
            puzzle.cells[step.index] = step.oldValue
            puzzle.notes[step.index] = step.oldNotes
        } else {
            puzzle.cells[step.index] = step.newValue
            puzzle.notes[step.index] = step.newNotes
        }
        rescanErrorsAndCompletion()
    }

    /// 撤销后重建错误计数与完成状态(基于 solution 扫描)。
    private func rescanErrorsAndCompletion() {
        errors = 0
        for i in 0..<81 where !puzzle.givens[i] && puzzle.cells[i] != 0 && puzzle.cells[i] != puzzle.solution[i] {
            errors += 1
        }
        isCompleted = puzzle.isSolved
        if isCompleted { stopTimer() }
    }

    // MARK: - 提示

    /// AI 提示:本地算法找"用户最容易理解的突破口"(裸单/排除法),
    /// 高亮该格 + 在页面顶部展示突破点分析(技巧类型 + AI 解释)。
    func requestHint() {
        guard !isCompleted else { return }
        guard let breakpoint = findBreakpoint() else { return }
        hintIndex = breakpoint.index
        selectedIndex = breakpoint.index
        hintTechnique = breakpoint.technique
        hintReason = "AI 分析中…"
        showHintPlaceholder = false
        hintDismissTask?.cancel()

        let context = hintContext(for: breakpoint)
        Task { [weak self] in
            guard let self else { return }
            do {
                let system = """
                你是数独大师,擅长用通俗语言解释数独技巧。根据盘面上下文,用 2-4 句中文向用户解释:
                1. 推荐填哪个格、什么数字。
                2. 用的是什么技巧(如"唯一候选"、"排除法"),并说明推理过程。
                语言要鼓励、易懂,像教练一样。不要给出多余建议。
                """
                // 流式:逐字填充 hintReason,提升等待体验。AI 提示无需思考模式,加速响应。
                let reply = try await AIService.shared.streamChat(
                    system: system,
                    user: context,
                    thinkingType: "disabled"
                ) { [weak self] delta in
                    Task { @MainActor in
                        guard let self, self.hintReason != nil else { return }
                        // 首段替换占位符,后续追加。
                        if self.hintReason == "AI 分析中…" {
                            self.hintReason = delta
                        } else {
                            self.hintReason = (self.hintReason ?? "") + delta
                        }
                    }
                }
                guard !Task.isCancelled else { return }
                // 兜底:流式结束后以完整文本为准(若流式未回填则直接赋值)。
                if self.hintReason == "AI 分析中…" || self.hintReason?.isEmpty == true {
                    self.hintReason = reply
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.hintReason = breakpoint.fallbackText
            }
        }
    }

    /// AI 完成:用唯一解填满所有空格,并调用大模型生成完成总结。
    func completeWithAI() {
        guard !isCompleted else { return }

        // 用本地唯一解填满所有空格(确定性、正确)。
        for i in 0..<81 where puzzle.cells[i] == 0 && !puzzle.givens[i] {
            let value = puzzle.solution[i]
            let step = MoveStep(
                index: i, oldValue: 0, newValue: value,
                oldNotes: puzzle.notes[i], newNotes: []
            )
            record(step)
            puzzle.cells[i] = value
            puzzle.notes[i].removeAll()
        }

        checkCompletion()
        hintIndex = nil
        hintReason = "AI 完成中…"
        hintTechnique = "AI 提示"
        showHintPlaceholder = false
        hintDismissTask?.cancel()

        // 调用 AI 生成完成总结。
        let context = "整盘已按唯一解填完,请用 2-3 句中文简短总结这局数独的完成情况(难度、步数或技巧)。"
        Task { [weak self] in
            guard let self else { return }
            do {
                let system = "你是数独专家,回答简短、鼓励。"
                let reply = try await AIService.shared.streamChat(
                    system: system,
                    user: context,
                    thinkingType: "disabled"
                ) { [weak self] delta in
                    Task { @MainActor in
                        guard let self, self.hintReason != nil else { return }
                        if self.hintReason == "AI 完成中…" {
                            self.hintReason = delta
                        } else {
                            self.hintReason = (self.hintReason ?? "") + delta
                        }
                    }
                }
                guard !Task.isCancelled else { return }
                if self.hintReason == "AI 完成中…" || self.hintReason?.isEmpty == true {
                    self.hintReason = reply
                }
            } catch {
                self.hintReason = "🎉 已自动完成本局数独!(AI 总结生成失败)"
            }
        }
    }

    /// 本地找突破口:优先裸单(唯一候选),否则找某单元(行/列/宫)唯一缺的数字。
    /// 返回格子 + 技巧描述 + 备用文案(AI 失败时兜底)。
    private func findBreakpoint() -> Breakpoint? {
        // 1. 裸单:某格只剩一个候选。
        for i in 0..<81 where puzzle.cells[i] == 0 {
            let cands = puzzle.candidates(at: i)
            if cands.count == 1 {
                let value = cands.first!
                let r = SudokuPuzzle.row(of: i), c = SudokuPuzzle.col(of: i), b = SudokuPuzzle.box(of: i)
                return Breakpoint(
                    index: i,
                    value: value,
                    technique: "唯一候选(Naked Single)",
                    detail: "第\(r+1)行第\(c+1)列(第\(b+1)宫)排除同行、同列、同宫的其余数字后,只剩 \(value) 可填。",
                    fallbackText: "提示:第\(r+1)行第\(c+1)列应填 \(value)(唯一候选)。"
                )
            }
        }
        // 2. 排除法:找某行/列/宫唯一缺的数字。
        for i in 0..<81 where puzzle.cells[i] == 0 {
            let cands = puzzle.candidates(at: i)
            let r = SudokuPuzzle.row(of: i), c = SudokuPuzzle.col(of: i)
            // 行内唯一位置
            let inRow = (0..<9).contains { col in
                let idx = SudokuPuzzle.index(row: r, col: col)
                return puzzle.cells[idx] == 0 && puzzle.candidates(at: idx).isSuperset(of: [puzzle.solution[i]])
            }
            if !inRow, let value = cands.first(where: { $0 == puzzle.solution[i] }) {
                return Breakpoint(
                    index: i,
                    value: value,
                    technique: "排除法(Hidden Single)",
                    detail: "数字 \(value) 在第\(r+1)行其余空格都无法出现,只能填在此处。",
                    fallbackText: "提示:第\(r+1)行第\(c+1)列应填 \(value)(排除法)。"
                )
            }
        }
        // 3. 兜底:第一个可解空格的解。
        for i in 0..<81 where puzzle.cells[i] == 0 {
            let value = puzzle.solution[i]
            let r = SudokuPuzzle.row(of: i), c = SudokuPuzzle.col(of: i)
            return Breakpoint(
                index: i, value: value, technique: "分析", detail: "",
                fallbackText: "提示:第\(r+1)行第\(c+1)列可填 \(value)。"
            )
        }
        return nil
    }

    /// 突破口:格子 + 技巧 + 说明。
    private struct Breakpoint {
        let index: Int
        let value: Int
        let technique: String
        let detail: String
        let fallbackText: String
    }

    /// 构造突破口上下文:该格行/列/宫 + 技巧信息。
    private func hintContext(for bp: Breakpoint) -> String {
        let r = SudokuPuzzle.row(of: bp.index)
        let c = SudokuPuzzle.col(of: bp.index)
        let b = SudokuPuzzle.box(of: bp.index)

        func rowDigits(_ row: Int) -> String {
            (0..<9).compactMap { puzzle.cells[row * 9 + $0] }.map(String.init).joined(separator: " ")
        }
        func colDigits(_ col: Int) -> String {
            (0..<9).compactMap { puzzle.cells[$0 * 9 + col] }.map(String.init).joined(separator: " ")
        }
        func boxDigits(_ box: Int) -> String {
            let startR = (box / 3) * 3, startC = (box % 3) * 3
            var digits: [Int] = []
            for dr in 0..<3 {
                for dc in 0..<3 {
                    let v = puzzle.cells[(startR + dr) * 9 + startC + dc]
                    if v != 0 { digits.append(v) }
                }
            }
            return digits.map(String.init).joined(separator: " ")
        }

        return """
        目标格:第\(r+1)行第\(c+1)列(第\(b+1)宫),应填数字 \(bp.value)。
        该行已填:\(rowDigits(r))
        该列已填:\(colDigits(c))
        该宫已填:\(boxDigits(b))
        本地检测到的技巧:\(bp.technique)
        请用通俗语言解释这个技巧如何帮助确定该格填 \(bp.value)。
        """
    }

    /// 清除提示高亮与理由,保留 AI 提示组件占位(提示用户可用 AI)。
    func dismissHint() {
        hintIndex = nil
        hintReason = nil
        hintTechnique = nil
        showHintPlaceholder = true
        hintDismissTask?.cancel()
    }

    private var hintDismissTask: Task<Void, Never>?

    /// 切换全盘答案展示。
    func toggleFullAnswer() {
        showFullAnswer.toggle()
        if showFullAnswer {
            stopTimer()
        } else {
            startTimer()
        }
    }

    // MARK: - 笔记清理

    /// 填入 value 后,清除其同行/列/宫格子里该数字的笔记。
    private func autoCleanNotes(for value: Int, excluding index: Int) {
        for p in SudokuPuzzle.peers(of: index) where puzzle.notes[p].contains(value) {
            puzzle.notes[p].remove(value)
        }
    }

    // MARK: - 完成检测

    private func checkCompletion() {
        if puzzle.isSolved {
            isCompleted = true
            stopTimer()
        }
    }

    // MARK: - 记录移动

    private func record(_ step: MoveStep) {
        undoStack.append(step)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    // MARK: - 计时

    func startTimer() {
        guard timer == nil else { return }
        lastTick = Date()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pauseTimer() {
        isPaused = true
        stopTimer()
    }

    func resumeTimer() {
        guard !isCompleted else { return }
        isPaused = false
        startTimer()
    }

    private func tick() {
        guard let last = lastTick else { return }
        let now = Date()
        elapsed += now.timeIntervalSince(last)
        lastTick = now
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        lastTick = nil
    }

    // MARK: - 重开一局

    /// 后台线程生成题面,完成后切回主线程替换。避免高难度生成卡 UI。
    func startNewGameAsync(difficulty: Difficulty) async {
        let puzzle = await Task.detached(priority: .userInitiated) {
            SudokuGenerator.generate(difficulty: difficulty)
        }.value
        replaceWith(puzzle)
    }

    /// 用新题面整体重置状态机(供"再来一局")。
    func replaceWith(_ newPuzzle: SudokuPuzzle) {
        stopTimer()
        puzzle = newPuzzle
        errors = 0
        isCompleted = false
        isPaused = false
        isNoteMode = false
        selectedIndex = nil
        hintIndex = nil
        elapsed = 0
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - 序列化(供持久化)

    func encodePuzzle() -> Data? {
        try? JSONEncoder().encode(puzzle)
    }

    func encodeMoveHistory() -> Data? {
        try? JSONEncoder().encode(undoStack)
    }

    static func decodePuzzle(_ data: Data) -> SudokuPuzzle? {
        try? JSONDecoder().decode(SudokuPuzzle.self, from: data)
    }

    static func decodeMoveHistory(_ data: Data) -> [MoveStep] {
        (try? JSONDecoder().decode([MoveStep].self, from: data)) ?? []
    }

    /// 从存档完整加载一局(替换盘面 + 恢复运行态)。
    func load(puzzle: SudokuPuzzle, elapsed: TimeInterval, errors: Int, moveHistory: [MoveStep]) {
        stopTimer()
        self.puzzle = puzzle
        self.elapsed = elapsed
        self.errors = errors
        self.undoStack = moveHistory
        redoStack.removeAll()
        selectedIndex = nil
        isNoteMode = false
        isPaused = false
        hintIndex = nil
        isCompleted = puzzle.isSolved
    }

    /// 导出当前状态为一个 GameSession 值对象(供持久化)。
    func exportSession(isDailyChallenge: Bool, sessionID: UUID = UUID()) -> GameSession {
        GameSession(
            id: sessionID,
            puzzleData: encodePuzzle() ?? Data(),
            elapsed: elapsed,
            errors: errors,
            moveHistory: encodeMoveHistory() ?? Data(),
            isCompleted: isCompleted,
            isVictory: isCompleted && puzzle.isSolved,
            difficulty: puzzle.difficulty,
            filledCount: puzzle.cells.filter { $0 != 0 }.count,
            startedAt: Date(),
            completedAt: isCompleted ? Date() : nil,
            isDailyChallenge: isDailyChallenge
        )
    }
}
