//
//  SudokuGenerator.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import Foundation

/// 数独题面生成器:随机完整解 + 按难度挖洞,保证唯一解。
/// 纯计算、无状态,标记 nonisolated 以允许在后台线程(高难度生成)执行。
nonisolated enum SudokuGenerator {

    /// 生成一局指定难度的题目。
    static func generate(difficulty: Difficulty, randomSource: RandomNumberGenerator? = nil) -> SudokuPuzzle {
        var rng = randomSource ?? SystemRandomNumberGenerator()

        // 生成多个候选,取空格最多的(挖洞受唯一解约束,候选多提高达标率)。
        let attempts: Int = {
            switch difficulty {
            case .easy, .medium: return 1
            case .hard: return 2
            case .expert: return 3
            }
        }()

        var best: SudokuPuzzle?
        var bestEmpty = -1
        for _ in 0..<attempts {
            let candidate = generateSingle(difficulty: difficulty, using: &rng)
            let empty = candidate.cells.filter { $0 == 0 }.count
            if empty > bestEmpty {
                bestEmpty = empty
                best = candidate
            }
            // 命中目标空格数即短路,不再生成多余候选(多数情况一次即达标)。
            if empty >= difficulty.targetEmptyCells {
                break
            }
        }
        return best!
    }

    /// 从单个随机完整解挖洞,得到尽量接近目标空格数的唯一解题面。
    private static func generateSingle<R: RandomNumberGenerator>(
        difficulty: Difficulty, using rng: inout R
    ) -> SudokuPuzzle {
        let solution = generateRandomSolution(using: &rng)

        // 挖洞:优先挖"候选数少"的格(低候选格被拒绝率低),每挖一格验证唯一解,
        // 直到达到目标空格数;整轮挖不动则停止。
        var cells = solution
        let target = difficulty.targetEmptyCells
        var removed = 0

        while removed < target {
            // 候选数升序排序;同候选数随机破平。
            let candidates = (0..<81)
                .filter { cells[$0] != 0 }
                .sorted { a, b in
                    let ca = candidateCount(cells, at: a)
                    let cb = candidateCount(cells, at: b)
                    if ca != cb { return ca < cb }
                    return Int.random(in: 0..<2, using: &rng) == 0
                }
            var progressed = false

            for index in candidates where removed < target {
                let backup = cells[index]
                cells[index] = 0

                let probe = SudokuPuzzle(
                    cells: cells, givens: Array(repeating: false, count: 81),
                    solution: solution, difficulty: difficulty
                )
                // limit: 2 —— 若第二个解也被找到则放弃该洞。
                if SudokuSolver.solveAll(probe, limit: 2).count != 1 {
                    cells[index] = backup
                } else {
                    removed += 1
                    progressed = true
                }
            }
            if !progressed { break }
        }

        var puzzle = SudokuPuzzle(
            cells: cells, givens: Array(repeating: false, count: 81),
            solution: solution, difficulty: difficulty
        )
        for i in 0..<81 where cells[i] != 0 {
            puzzle.givens[i] = true
        }
        return puzzle
    }

    /// 当前局面下某格的候选数(未挖格)。
    private static func candidateCount(_ cells: [Int], at index: Int) -> Int {
        var count = 0
        for v in 1...9 where SudokuSolver.isPlacementValid(cells, v, at: index) {
            count += 1
        }
        return count
    }

    /// 随机回溯填满一整个棋盘,得到随机解。
    private static func generateRandomSolution<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var board = [Int](repeating: 0, count: 81)
        // 位掩码增量维护,加速候选判断。
        var rows = [Int](repeating: 0, count: 9)
        var cols = [Int](repeating: 0, count: 9)
        var boxes = [Int](repeating: 0, count: 9)
        let ok = fillRandom(&board, rows: &rows, cols: &cols, boxes: &boxes, using: &rng)
        precondition(ok, "无法生成随机完整解")
        return board
    }

    private static func fillRandom<R: RandomNumberGenerator>(
        _ board: inout [Int],
        rows: inout [Int], cols: inout [Int], boxes: inout [Int],
        using rng: inout R
    ) -> Bool {
        // MRV:选候选最少的空位(随机破平),避免回溯过深。
        var bestIndex = -1
        var bestCount = 10
        for i in 0..<81 where board[i] == 0 {
            let count = SudokuSolver.candidatesMask(rows: rows, cols: cols, boxes: boxes, index: i).nonzeroBitCount
            if count < bestCount {
                bestCount = count
                bestIndex = i
                if count == 1 { break }
            }
        }
        guard bestIndex >= 0 else { return true }  // 填满

        var values = Array(1...9)
        values.shuffle(using: &rng)
        for v in values {
            let bit = 1 << (v - 1)
            let used = rows[bestIndex / 9] | cols[bestIndex % 9]
                | boxes[SudokuPuzzle.box(of: bestIndex)]
            guard (used & bit) == 0 else { continue }

            board[bestIndex] = v
            rows[bestIndex / 9] |= bit
            cols[bestIndex % 9] |= bit
            boxes[SudokuPuzzle.box(of: bestIndex)] |= bit

            if fillRandom(&board, rows: &rows, cols: &cols, boxes: &boxes, using: &rng) {
                return true
            }

            board[bestIndex] = 0
            rows[bestIndex / 9] &= ~bit
            cols[bestIndex % 9] &= ~bit
            boxes[SudokuPuzzle.box(of: bestIndex)] &= ~bit
        }
        return false
    }
}
