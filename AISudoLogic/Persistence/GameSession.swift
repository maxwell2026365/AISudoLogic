//
//  GameSession.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import Foundation

/// Codable 持久化的游戏会话:保存一局数独;未完成可恢复,已完成归档展示。
/// 替代 SwiftData @Model,兼容 iOS 15+ / macOS 12+。
struct GameSession: Codable, Identifiable {
    var id: UUID
    /// 题面(含给定、解、笔记)的 Codable 编码。
    var puzzleData: Data
    /// 已用时间(秒)。
    var elapsed: TimeInterval
    /// 错误次数。
    var errors: Int
    /// 撤销栈编码。
    var moveHistory: Data
    /// 是否已完成(完成即归档保留,供菜单展示)。
    var isCompleted: Bool
    /// 是否胜利(与解一致才算)。
    var isVictory: Bool
    /// 难度。
    var difficultyRaw: String
    /// 已填格数(含给定),用于展示进度。
    var filledCount: Int
    /// 开局时间。
    var startedAt: Date
    /// 完成时间(未完成为 nil)。
    var completedAt: Date?
    /// 是否每日挑战局(完成可获得奖杯)。
    var isDailyChallenge: Bool

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }

    /// 完成进度(0-1):已填格数 / 总格数。
    var progress: Double {
        min(Double(filledCount) / 81.0, 1.0)
    }

    init(
        id: UUID = UUID(),
        puzzleData: Data,
        elapsed: TimeInterval,
        errors: Int,
        moveHistory: Data,
        isCompleted: Bool,
        isVictory: Bool = false,
        difficulty: Difficulty,
        filledCount: Int,
        startedAt: Date,
        completedAt: Date? = nil,
        isDailyChallenge: Bool = false
    ) {
        self.id = id
        self.puzzleData = puzzleData
        self.elapsed = elapsed
        self.errors = errors
        self.moveHistory = moveHistory
        self.isCompleted = isCompleted
        self.isVictory = isVictory
        self.difficultyRaw = difficulty.rawValue
        self.filledCount = filledCount
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.isDailyChallenge = isDailyChallenge
    }
}

/// 每日挑战奖杯记录(Codable,兼容 iOS 15+ / macOS 12+)。
struct Trophy: Codable, Identifiable {
    var id: UUID
    /// 获得奖杯的日期(仅记录日期部分,"yyyy-MM-dd")。
    var day: String
    /// 难度。
    var difficultyRaw: String
    /// 用时(秒)。
    var elapsed: TimeInterval
    /// 错误数。
    var errors: Int

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .medium }
        set { difficultyRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        day: String,
        difficulty: Difficulty,
        elapsed: TimeInterval,
        errors: Int
    ) {
        self.id = id
        self.day = day
        self.difficultyRaw = difficulty.rawValue
        self.elapsed = elapsed
        self.errors = errors
    }
}
