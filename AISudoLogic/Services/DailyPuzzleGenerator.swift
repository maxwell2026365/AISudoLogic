//
//  DailyPuzzleGenerator.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/8.
//

import Foundation

/// 每日挑战题面生成器:按日期作为随机种子,每天生成固定且唯一的题面。
enum DailyPuzzleGenerator {

    /// 生成某一天的固定题面(同一天返回相同题面)。
    static func generate(for date: Date) -> SudokuPuzzle {
        // 以日期字符串作为种子,保证确定性。
        let seed = seedString(for: date)
        let rng = SeededGenerator(seed: seed)
        return SudokuGenerator.generate(difficulty: .medium, randomSource: rng)
    }

    private static func seedString(for date: Date) -> UInt64 {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        let s = f.string(from: date)
        // 把字符串转成固定种子。
        var hash: UInt64 = 5381
        for byte in s.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }
}

/// 可复现的伪随机数生成器(基于 SplitMix64),确保同种子同序列。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
