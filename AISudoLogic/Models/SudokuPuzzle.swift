//
//  SudokuPuzzle.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import Foundation

/// 数独一局的纯值类型数据,可 Codable 序列化用于持久化。
/// 纯值、无状态,标记 nonisolated 以允许在后台线程(求解/生成)使用。
nonisolated struct SudokuPuzzle: Codable, Equatable, Sendable {
    /// 81 个格子,按行优先排列,0 = 空。
    var cells: [Int]
    /// 每个格子是否为题目给定(给定格不可修改)。
    var givens: [Bool]
    /// 唯一完整解,供提示与最终校验。
    var solution: [Int]
    /// 每格笔记(铅笔候选),索引 0...8 对应数字 1...9。
    var notes: [Set<Int>]
    var difficulty: Difficulty

    init(cells: [Int], givens: [Bool], solution: [Int], difficulty: Difficulty) {
        precondition(cells.count == 81 && givens.count == 81 && solution.count == 81,
                     "Sudoku must have exactly 81 cells")
        self.cells = cells
        self.givens = givens
        self.solution = solution
        self.notes = Array(repeating: Set<Int>(), count: 81)
        self.difficulty = difficulty
    }

    // MARK: - 索引

    static func row(of index: Int) -> Int { index / 9 }
    static func col(of index: Int) -> Int { index % 9 }
    static func box(of index: Int) -> Int {
        (index / 9 / 3) * 3 + (index % 9 / 3)
    }
    static func index(row: Int, col: Int) -> Int { row * 9 + col }

    /// 与某格同行/同列/同宫的格子索引(不含自身)。
    static func peers(of index: Int) -> [Int] {
        var result = Set<Int>()
        let r = row(of: index), c = col(of: index), b = box(of: index)
        for i in 0..<81 {
            guard i != index else { continue }
            if row(of: i) == r || col(of: i) == c || box(of: i) == b {
                result.insert(i)
            }
        }
        return Array(result)
    }

    // MARK: - 合法性

    /// 某格当前可填的候选数字(基于行列宫已填数字)。
    func candidates(at index: Int) -> Set<Int> {
        var result = Set(1...9)
        for p in Self.peers(of: index) where cells[p] != 0 {
            result.remove(cells[p])
        }
        return result
    }

    /// 给定格(下标 index)填入 value 是否合法(相对当前棋盘其余格子)。
    func isLegal(_ value: Int, at index: Int) -> Bool {
        for p in Self.peers(of: index) where cells[p] == value {
            return false
        }
        return true
    }

    /// 整个棋盘当前状态是否满足数独规则(允许未填满)。
    var isValid: Bool {
        func rowValid(_ r: Int) -> Bool {
            var seen = Set<Int>()
            for c in 0..<9 {
                let v = cells[r * 9 + c]
                if v != 0, seen.contains(v) { return false }
                if v != 0 { seen.insert(v) }
            }
            return true
        }
        func colValid(_ c: Int) -> Bool {
            var seen = Set<Int>()
            for r in 0..<9 {
                let v = cells[r * 9 + c]
                if v != 0, seen.contains(v) { return false }
                if v != 0 { seen.insert(v) }
            }
            return true
        }
        func boxValid(_ b: Int) -> Bool {
            var seen = Set<Int>()
            let startR = (b / 3) * 3, startC = (b % 3) * 3
            for dr in 0..<3 {
                for dc in 0..<3 {
                    let v = cells[(startR + dr) * 9 + startC + dc]
                    if v != 0, seen.contains(v) { return false }
                    if v != 0 { seen.insert(v) }
                }
            }
            return true
        }
        return (0..<9).allSatisfy { rowValid($0) && colValid($0) && boxValid($0) }
    }

    /// 是否已完全填对(与解一致)。
    var isSolved: Bool { cells == solution }

    /// 当前错误格子集合(玩家填入且不等于解的格子)。
    var wrongCells: Set<Int> {
        var result = Set<Int>()
        for i in 0..<81 where !givens[i] && cells[i] != 0 && cells[i] != solution[i] {
            result.insert(i)
        }
        return result
    }

    // MARK: - 修改

    /// 填入/清空一个格子的值。给定格不允许修改。
    mutating func set(_ value: Int, at index: Int) {
        guard !givens[index], index >= 0, index < 81 else { return }
        cells[index] = value
    }

    /// 追加/移除某个笔记。返回是否真的发生了变化。
    @discardableResult
    mutating func toggleNote(_ value: Int, at index: Int) -> Bool {
        guard !givens[index] else { return false }
        if notes[index].contains(value) {
            notes[index].remove(value)
        } else {
            notes[index].insert(value)
        }
        return true
    }

    /// 清空某格的笔记。
    mutating func clearNotes(at index: Int) {
        guard !givens[index] else { return }
        notes[index].removeAll()
    }
}
