//
//  ContentView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 应用根视图:在菜单与游戏之间路由,并管理存档(保存/恢复/继续/删除)。
struct ContentView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @EnvironmentObject private var pinManager: PinManager
    @EnvironmentObject private var aiCoach: AICoachViewModel
    @EnvironmentObject private var store: PersistenceStore
    @State private var isInGame = false
    /// 当前展示的子页面(统计 / AI 教练 / 每日挑战),nil 表示菜单。改为页面切换而非弹窗。
    @State private var activePage: Page?
    /// 游戏中是否展示 AI 教练页面(覆盖在游戏上,返回时回到游戏而非菜单)。
    @State private var showInGameCoachPage = false
    @State private var isDailyMode = false
    /// 当前这一局对应的会话;新开一局时置空,以便创建新的历史记录。
    @State private var activeSession: GameSession?

    /// 菜单下的子页面。
    enum Page: Hashable {
        case stats
        case aiCoach
        case dailyChallenge
    }

    /// 当前是否有可继续的未完成存档。
    private var hasSavedGame: Bool {
        store.unfinishedSession != nil
    }

    /// 已完成的存档(供 AI 教练参考历史)。
    private var completedSessions: [GameSession] {
        store.completedSessions
    }

    /// 今日奖杯(每日挑战是否完成)。
    private var todayTrophy: Trophy? {
        store.todayTrophy()
    }

    var body: some View {
        Group {
            if isInGame {
                if showInGameCoachPage {
                    // 游戏中的 AI 教练:页面覆盖在游戏之上,左上角返回回到游戏。
                    AICoachView(
                        puzzle: viewModel.puzzle,
                        history: completedSessions,
                        onBack: { showInGameCoachPage = false }
                    )
                    .transition(.opacity)
                } else {
                    GameView(
                        onExit: exitToMenu,
                        onShowAICoach: { showInGameCoachPage = true },
                        onRestart: {
                            // 重开一局:清空对当前会话的引用,确保新局另存一条记录。
                            activeSession = nil
                            isDailyMode = false
                        },
                        isDailyMode: isDailyMode
                    )
                    .transition(.opacity)
                }
            } else if let page = activePage {
                // 菜单下的子页面:统计 / AI 教练 / 每日挑战。
                switch page {
                case .stats:
                    StatsView(
                        sessions: store.sortedSessions,
                        trophies: store.trophies,
                        onBack: { activePage = nil }
                    )
                    .transition(.opacity)
                case .aiCoach:
                    AICoachView(
                        puzzle: nil,
                        history: completedSessions,
                        onBack: { activePage = nil }
                    )
                    .transition(.opacity)
                case .dailyChallenge:
                    DailyChallengeView(
                        todayTrophy: todayTrophy,
                        onPlay: startDailyChallenge,
                        onBack: { activePage = nil }
                    )
                    .transition(.opacity)
                }
            } else {
                MenuView(
                    hasSavedGame: hasSavedGame,
                    onContinue: continueGame,
                    onNewGame: startNewGame,
                    onShowStats: { showPage(.stats) },
                    onShowDaily: { showPage(.dailyChallenge) },
                    onShowAICoach: { showPage(.aiCoach) },
                    isPinned: pinManager.isPinned,
                    onTogglePin: { pinManager.toggle() }
                )
                .transition(.opacity)
            }
        }
#if os(macOS)
        // 限制内容尺寸,防止窗口被内容撑大/拉宽。
        .frame(maxWidth: 520, maxHeight: 800)
#endif
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                // 完成即归档,供菜单展示;每日挑战完成发放奖杯。
                saveCurrentGame()
                if isDailyMode {
                    awardDailyTrophy()
                }
            }
        }
#if os(macOS)
        .onAppear {
            // 锁定窗口尺寸:进入游戏/菜单切换时窗口大小不变。
            lockWindowSize()
        }
        .onChange(of: isInGame) { _ in
            lockWindowSize()
        }
#endif
    }

#if os(macOS)
    /// 强制窗口为固定尺寸,防止内容撑大。
    private func lockWindowSize() {
        let fixed = NSSize(width: 520, height: 800)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = NSApp?.windows.first else { return }
            window.contentMinSize = fixed
            window.contentMaxSize = fixed
            window.setContentSize(fixed)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let window = NSApp?.windows.first else { return }
            window.setContentSize(fixed)
        }
    }
#endif

    /// 打开菜单下的子页面。
    private func showPage(_ page: Page) {
        guard !isInGame else { return }
        activePage = page
    }

    private func startNewGame(_ difficulty: Difficulty) {
        isDailyMode = false
        activeSession = nil
        Task {
            await viewModel.startNewGameAsync(difficulty: difficulty)
            saveCurrentGame()
            withAnimation { isInGame = true }
        }
    }

    /// 每日挑战:按日期固定种子生成题面。
    private func startDailyChallenge() {
        guard todayTrophy == nil else { return }
        activePage = nil
        isDailyMode = true
        activeSession = nil
        Task {
            let puzzle = DailyPuzzleGenerator.generate(for: Date())
            viewModel.replaceWith(puzzle)
            saveCurrentGame()
            withAnimation { isInGame = true }
        }
    }

    /// 发放每日挑战奖杯。
    private func awardDailyTrophy() {
        guard isDailyMode, todayTrophy == nil else { return }
        let trophy = Trophy(
            day: StatsEngine.todayString(),
            difficulty: viewModel.puzzle.difficulty,
            elapsed: viewModel.elapsed,
            errors: viewModel.errors
        )
        store.insertTrophy(trophy)
    }

    private func continueGame() {
        guard let session = store.unfinishedSession,
              let puzzle = GameViewModel.decodePuzzle(session.puzzleData) else {
            return
        }
        activeSession = session
        viewModel.load(
            puzzle: puzzle,
            elapsed: session.elapsed,
            errors: session.errors,
            moveHistory: GameViewModel.decodeMoveHistory(session.moveHistory)
        )
        withAnimation { isInGame = true }
    }

    private func exitToMenu() {
        saveCurrentGame()
        withAnimation { isInGame = false }
    }

    private func saveCurrentGame() {
        let session = viewModel.exportSession(
            isDailyChallenge: isDailyMode,
            sessionID: activeSession?.id ?? UUID()
        )
        store.updateSession(session)
        activeSession = session
    }
}

#Preview {
    ContentView()
        .environmentObject(GameViewModel(puzzle: SudokuGenerator.generate(difficulty: .easy)))
        .environmentObject(PersistenceStore())
}
