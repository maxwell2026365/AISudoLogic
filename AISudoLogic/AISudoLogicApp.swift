//
//  AISudoLogicApp.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct SudoLogicApp: App {
    /// 全局游戏状态机(首个菜单页用默认题面占位,进入新局时替换)。
    @StateObject private var gameViewModel = GameViewModel(
        puzzle: SudokuGenerator.generate(difficulty: .easy)
    )
    /// macOS 窗口置顶管理。
    @StateObject private var pinManager = PinManager()
    /// AI 教练。
    @StateObject private var aiCoach = AICoachViewModel()
    /// 持久化存储(替代 SwiftData,兼容 iOS 15+ / macOS 12+)。
    @StateObject private var store = PersistenceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameViewModel)
                .environmentObject(pinManager)
                .environmentObject(aiCoach)
                .environmentObject(store)
#if os(iOS)
                // iOS 强制深色主题,与 macOS 保持一致。
                .preferredColorScheme(.dark)
#endif
#if os(macOS)
                .onAppear {
                    pinManager.applyLevel()
                    // 锁定窗口尺寸:多次尝试等待窗口就绪,强制 520x800。
                    for delay in [0.3, 0.8, 1.5, 2.5] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            guard let window = NSApp?.windows.first else { return }
                            let fixed = NSSize(width: 520, height: 800)
                            window.contentMinSize = fixed
                            window.contentMaxSize = fixed
                            window.setContentSize(fixed)
                        }
                    }
                }
                .onChange(of: pinManager.isPinned) { _ in
                    pinManager.applyLevel()
                }
#endif
        }
#if os(macOS)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Toggle("置顶窗口", isOn: Binding(
                    get: { pinManager.isPinned },
                    set: { pinManager.isPinned = $0 }
                ))
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
#endif
    }
}
