//
//  PinManager.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/5.
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

/// macOS 窗口置顶管理:切换 NSWindow.level 为浮动层,并持久化偏好。
/// iOS 上无窗口概念,此类型仅用于 macOS。
final class PinManager: ObservableObject {
    @Published var isPinned: Bool {
        didSet {
            applyLevel()
            UserDefaults.standard.set(isPinned, forKey: Self.defaultsKey)
        }
    }

    private static let defaultsKey = "window.pinned"

    init() {
        self.isPinned = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    /// 切换置顶状态。
    func toggle() {
        isPinned.toggle()
    }

    /// 对当前 NSWindow 应用置顶层级。
    func applyLevel() {
#if os(macOS)
        guard let window = NSApp?.windows.first else { return }
        window.level = isPinned ? .floating : .normal
#endif
    }
}
