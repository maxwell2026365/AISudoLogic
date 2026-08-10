//
//  ToolbarView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI

/// 工具行:笔记(铅笔)、撤销、重做、擦除、提示。
struct ToolbarView: View {
    let isNoteMode: Bool
    let canUndo: Bool
    let canRedo: Bool
    let canErase: Bool
    let onNoteMode: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onErase: () -> Void
    let onHint: () -> Void
    var onFullAnswer: (() -> Void)? = nil
    var onAIComplete: (() -> Void)? = nil
    var isPinned: Bool = false
    var onPin: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            toolButton(
                title: "笔记",
                systemImage: isNoteMode ? "pencil.circle.fill" : "pencil.circle",
                isActive: isNoteMode,
                action: onNoteMode
            )
            toolButton(title: "撤销", systemImage: "arrow.uturn.backward", isEnabled: canUndo, action: onUndo)
            toolButton(title: "重做", systemImage: "arrow.uturn.forward", isEnabled: canRedo, action: onRedo)
            toolButton(title: "擦除", systemImage: "eraser", isEnabled: canErase, action: onErase)
            toolButton(title: "AI提示", systemImage: "sparkles", action: onHint)
            if let onFullAnswer {
                toolButton(title: "AI全盘", systemImage: "eye", action: onFullAnswer)
            }
            if let onAIComplete {
                toolButton(title: "AI完成", systemImage: "wand.and.stars", action: onAIComplete)
            }
#if os(macOS)
            if let onPin {
                toolButton(
                    title: "置顶",
                    systemImage: isPinned ? "pin.fill" : "pin",
                    isActive: isPinned,
                    action: onPin
                )
            }
#endif
        }
        .padding(.horizontal)
    }

    private func toolButton(
        title: String,
        systemImage: String,
        isActive: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(minWidth: 44, minHeight: 36)
            .foregroundStyle(textColor(isActive: isActive, isEnabled: isEnabled))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func textColor(isActive: Bool, isEnabled: Bool) -> Color {
        if !isEnabled { return .secondary.opacity(0.4) }
        return isActive ? .accentColor : .primary
    }
}

#Preview("Toolbar") {
    ToolbarView(
        isNoteMode: true,
        canUndo: true,
        canRedo: false,
        canErase: true,
        onNoteMode: {},
        onUndo: {},
        onRedo: {},
        onErase: {},
        onHint: {}
    )
}
