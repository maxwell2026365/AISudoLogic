//
//  SudokuSolver.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import Foundation

/// 回溯 + 位掩码(MRV)数独求解器。
/// 行/列/宫各用 9 位掩码表示已占用数字,候选判断为 O(1) 位运算。
/// 纯计算、无状态,标记 nonisolated 以允许在后台线程(如题面生成)执行。
nonisolated enum SudokuSolver {

    /// 尝试求出完整解。`limit = 2` 时返回最多两个解,用于验证唯一性。
    /// - Returns: 完整解列表(最多 `limit` 个)。
    static func solveAll(_ puzzle: SudokuPuzzle, limit: Int = 1) -> [SudokuPuzzle] {
        var rows = [Int](repeating: 0, count: 9)
        var cols = [Int](repeating: 0, count: 9)
        var boxes = [Int](repeating: 0, count: 9)
        for i in 0..<81 where puzzle.cells[i] != 0 {
            setBit(&rows, &cols, &boxes, value: puzzle.cells[i], at: i)
        }
        var boards: [[Int]] = []
        var board = puzzle.cells
        solveBacktracking(&board, rows: &rows, cols: &cols, boxes: &boxes,
                          in: &boards, limit: limit)
        return boards.map { solvedBoard in
            var solved = puzzle
            solved.cells = solvedBoard
            solved.notes = (0..<81).map { _ in Set<Int>() }
            return solved
        }
    }

    /// 某格的候选数字掩码(1 位 = 该数字可用)。供求解与生成共用。
    static func candidatesMask(
        rows: [Int], cols: [Int], boxes: [Int], index: Int
    ) -> Int {
        let used = rows[SudokuPuzzle.row(of: index)]
            | cols[SudokuPuzzle.col(of: index)]
            | boxes[SudokuPuzzle.box(of: index)]
        return 0x1FF & ~used  // 低 9 位
    }

    private static func solveBacktracking(
        _ board: inout [Int],
        rows: inout [Int], cols: inout [Int], boxes: inout [Int],
        in results: inout [[Int]],
        limit: Int
    ) {
        guard results.count < limit else { return }

        // MRV:选候选最少的空位。
        guard let target = minimalCandidatesCell(board, rows: rows, cols: cols, boxes: boxes) else {
            results.append(board)
            return
        }

        let (index, mask) = target
        var candidates = mask
        while candidates != 0 {
            // 取最低位为当前候选
            let bit = candidates & -candidates
            candidates &= candidates - 1
            let value = bitNumber(bit)

            board[index] = value
            setBit(&rows, &cols, &boxes, value: value, at: index)
            solveBacktracking(&board, rows: &rows, cols: &cols, boxes: &boxes,
                              in: &results, limit: limit)
            if results.count >= limit {
                clearBit(&rows, &cols, &boxes, value: value, at: index)
                board[index] = 0
                return
            }
            clearBit(&rows, &cols, &boxes, value: value, at: index)
            board[index] = 0
        }
    }

    /// 返回候选最少的空位及其候选掩码;无空位返回 nil。候选数为 0 时立即返回(死路剪枝)。
    private static func minimalCandidatesCell(
        _ board: [Int],
        rows: [Int], cols: [Int], boxes: [Int]
    ) -> (index: Int, mask: Int)? {
        var best: (index: Int, mask: Int)?
        var bestCount = 10
        for i in 0..<81 where board[i] == 0 {
            let mask = candidatesMask(rows: rows, cols: cols, boxes: boxes, index: i)
            let count = mask.nonzeroBitCount
            guard count > 0 else { return (i, 0) }  // 死路
            if count < bestCount {
                bestCount = count
                best = (i, mask)
                if count == 1 { break }  // 已是最优
            }
        }
        return best
    }

    private static func setBit(
        _ rows: inout [Int], _ cols: inout [Int], _ boxes: inout [Int],
        value: Int, at index: Int
    ) {
        let bit = 1 << (value - 1)
        rows[SudokuPuzzle.row(of: index)] |= bit
        cols[SudokuPuzzle.col(of: index)] |= bit
        boxes[SudokuPuzzle.box(of: index)] |= bit
    }

    private static func clearBit(
        _ rows: inout [Int], _ cols: inout [Int], _ boxes: inout [Int],
        value: Int, at index: Int
    ) {
        let bit = 1 << (value - 1)
        rows[SudokuPuzzle.row(of: index)] &= ~bit
        cols[SudokuPuzzle.col(of: index)] &= ~bit
        boxes[SudokuPuzzle.box(of: index)] &= ~bit
    }

    /// 把最低位索引(1-based)转为数字 1...9。
    private static func bitNumber(_ bit: Int) -> Int {
        // bit 是 1<<(value-1) 的形式;用 64 位尾随零数定位
        (bit.trailingZeroBitCount) + 1
    }

    /// 便捷版:检查在棋盘 `index` 处放置 `value` 是否不违反行列宫。
    /// 低频调用(生成器预检、提示),每次重建掩码,不计较性能。
    static func isPlacementValid(_ board: [Int], _ value: Int, at index: Int) -> Bool {
        let r = SudokuPuzzle.row(of: index), c = SudokuPuzzle.col(of: index)
        let br = (r / 3) * 3, bc = (c / 3) * 3
        for i in 0..<9 {
            if board[r * 9 + i] == value { return false }
            if board[i * 9 + c] == value { return false }
            if board[(br + i / 3) * 9 + bc + i % 3] == value { return false }
        }
        return true
    }
}
