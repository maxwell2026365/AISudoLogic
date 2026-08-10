//
//  StatsEngine.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/8.
//

import Foundation

/// 单一难度的统计指标。
struct DifficultyStats {
    let difficulty: Difficulty
    /// 通关数。
    var wins: Int = 0
    /// 总对局数(含未通关的已开始局)。
    var totalGames: Int = 0
    /// 通关总时长(秒)。
    var totalTime: TimeInterval = 0
    /// 最短通关时间(秒)。
    var bestTime: TimeInterval?
    /// 无错误通关数。
    var perfectWins: Int = 0
    /// 当前连胜数。
    var currentStreak: Int = 0
    /// 奖杯数。
    var trophies: Int = 0

    /// 胜率(0-1)。
    var winRate: Double {
        totalGames == 0 ? 0 : Double(wins) / Double(totalGames)
    }

    /// 无错误胜率(0-1)。
    var perfectRate: Double {
        wins == 0 ? 0 : Double(perfectWins) / Double(wins)
    }

    /// 平均通关时间(秒)。
    var averageTime: TimeInterval {
        wins == 0 ? 0 : totalTime / Double(wins)
    }
}

/// 按难度聚合统计。
struct StatsSummary {
    var byDifficulty: [Difficulty: DifficultyStats]
    /// 总奖杯数。
    var totalTrophies: Int {
        byDifficulty.values.reduce(0) { $0 + $1.trophies }
    }

    init(sessions: [GameSession], trophies: [Trophy]) {
        var dict: [Difficulty: DifficultyStats] = [:]
        for d in Difficulty.allCases {
            dict[d] = DifficultyStats(difficulty: d)
        }

        // 按完成时间倒序,用于连胜统计。
        let completed = sessions
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        // 各难度当前连胜:按完成时间倒序,最近一次失败之后的连续胜利数。
        var streak: [Difficulty: Int] = [:]
        var seenFail: Set<Difficulty> = []
        for s in completed {
            if seenFail.contains(s.difficulty) { continue }
            if s.isVictory {
                streak[s.difficulty, default: 0] += 1
            } else {
                seenFail.insert(s.difficulty)
            }
        }
        for (d, n) in streak {
            dict[d]?.currentStreak = n
        }

        for s in sessions {
            guard var st = dict[s.difficulty] else { continue }
            st.totalGames += 1
            if s.isCompleted && s.isVictory {
                st.wins += 1
                st.totalTime += s.elapsed
                if s.errors == 0 { st.perfectWins += 1 }
                if let best = st.bestTime {
                    st.bestTime = min(best, s.elapsed)
                } else {
                    st.bestTime = s.elapsed
                }
            }
            dict[s.difficulty] = st
        }

        for t in trophies {
            dict[t.difficulty]?.trophies += 1
        }

        self.byDifficulty = dict
    }
}

/// 统计引擎:从历史局与奖杯计算指标。
enum StatsEngine {
    static func summary(sessions: [GameSession], trophies: [Trophy]) -> StatsSummary {
        StatsSummary(sessions: sessions, trophies: trophies)
    }

    /// 今日日期字符串(如 "2026-08-08"),用于每日挑战。
    static func todayString(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
