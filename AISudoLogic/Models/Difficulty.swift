//
//  Difficulty.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import Foundation

/// 难度等级纯枚举。
nonisolated enum Difficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy
    case medium
    case hard
    case expert

    var id: String { rawValue }

    /// 目标空格数(保证唯一解的前提下尽量逼近,实测可达上限)。.
    var targetEmptyCells: Int {
        switch self {
        case .easy: return 40
        case .medium: return 50
        case .hard: return 56
        case .expert: return 58
        }
    }

    var displayName: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        case .expert: return "专家"
        }
    }

    var emptyLabel: String {
        "约 \(targetEmptyCells) 空"
    }
}
