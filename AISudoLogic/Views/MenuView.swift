//
//  MenuView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI

/// 主菜单:选择难度开始新局;有未完成局时显示"继续上次游戏"。
struct MenuView: View {
    let hasSavedGame: Bool
    let onContinue: () -> Void
    let onNewGame: (Difficulty) -> Void
    var onShowStats: (() -> Void)? = nil
    var onShowDaily: (() -> Void)? = nil
    var onShowAICoach: (() -> Void)? = nil
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image("MenuIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            Text("AISudoLogic")
                .font(.title.bold())

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                if hasSavedGame {
                    Button(action: onContinue) {
                        Label("继续上次游戏", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: 220, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }

                ForEach(Difficulty.allCases) { difficulty in
                    Button {
                        onNewGame(difficulty)
                    } label: {
                        HStack {
                            Text(difficulty.displayName)
                                .font(.headline)
                            Spacer()
                            Text(difficulty.emptyLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: 220, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }

                if let onShowDaily {
                    Button(action: onShowDaily) {
                        Text("🏆 每日挑战")
                            .frame(maxWidth: 220, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }

                if let onShowStats {
                    Button(action: onShowStats) {
                        Text("📊 统计")
                            .frame(maxWidth: 220, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }

                if let onShowAICoach {
                    Button(action: onShowAICoach) {
                        Text("🤖 AI 教练")
                            .frame(maxWidth: 220, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }

#if os(macOS)
            if let onTogglePin {
                Toggle(isOn: Binding(
                    get: { isPinned },
                    set: { _ in onTogglePin() }
                )) {
                    Label("置顶窗口", systemImage: isPinned ? "pin.fill" : "pin")
                        .frame(maxWidth: 220, minHeight: 44)
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 16)
                .frame(maxWidth: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
            }
#endif

            Spacer(minLength: 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Menu") {
    MenuView(
        hasSavedGame: true,
        onContinue: {},
        onNewGame: { _ in }
    )
}
