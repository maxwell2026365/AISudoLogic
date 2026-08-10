//
//  SudokuLogicTests.swift
//  AISudoLogicTests
//
//  Created by Maxwell on 2026/8/4.
//

import XCTest
@testable import AISudoLogic

final class SudokuPuzzleTests: XCTestCase {

    /// 一个已知的唯一解题面(来自维基百科示例),用于求解器验证。
    private func wikiPuzzle() -> SudokuPuzzle {
        let given = [
            5, 3, 0,  0, 7, 0,  0, 0, 0,
            6, 0, 0,  1, 9, 5,  0, 0, 0,
            0, 9, 8,  0, 0, 0,  0, 6, 0,
            8, 0, 0,  0, 6, 0,  0, 0, 3,
            4, 0, 0,  8, 0, 3,  0, 0, 1,
            7, 0, 0,  0, 2, 0,  0, 0, 6,
            0, 6, 0,  0, 0, 0,  2, 8, 0,
            0, 0, 0,  4, 1, 9,  0, 0, 5,
            0, 0, 0,  0, 8, 0,  0, 7, 9,
        ]
        return SudokuPuzzle(
            cells: given,
            givens: given.map { $0 != 0 },
            solution: Array(repeating: 0, count: 81),
            difficulty: .medium
        )
    }

    func testIndexMapping() {
        XCTAssertEqual(SudokuPuzzle.index(row: 2, col: 3), 21)
        XCTAssertEqual(SudokuPuzzle.row(of: 21), 2)
        XCTAssertEqual(SudokuPuzzle.col(of: 21), 3)
        XCTAssertEqual(SudokuPuzzle.box(of: 0), 0)
        XCTAssertEqual(SudokuPuzzle.box(of: 40), 4)
        XCTAssertEqual(SudokuPuzzle.box(of: 80), 8)
    }

    func testPeersDoNotIncludeSelf() {
        let peers = SudokuPuzzle.peers(of: 40)
        XCTAssertFalse(peers.contains(40))
        // 中心格:同行 8 + 同列 8 + 同宫 4 = 20
        XCTAssertEqual(Set(peers).count, 20)
    }

    func testSolverFindsSolutionForWikiPuzzle() {
        let original = wikiPuzzle()
        let solutions = SudokuSolver.solveAll(original, limit: 2)
        XCTAssertEqual(solutions.count, 1)
        guard let solution = solutions.first else { return }
        XCTAssertTrue(solution.isValid)
        // 求解器输出应填满所有空位,且与原题给定一致。
        XCTAssertEqual(solution.cells.filter { $0 == 0 }.count, 0)
        for i in 0..<81 where original.givens[i] {
            XCTAssertEqual(solution.cells[i], original.cells[i])
        }
    }

    func testWikiPuzzleHasUniqueSolution() {
        let solutions = SudokuSolver.solveAll(wikiPuzzle(), limit: 2)
        XCTAssertEqual(solutions.count, 1, "已知唯一解题面不应有多解")
    }

    func testIsLegalDetection() {
        var puzzle = SudokuPuzzle(
            cells: [Int](repeating: 0, count: 81),
            givens: Array(repeating: false, count: 81),
            solution: Array(repeating: 0, count: 81),
            difficulty: .easy
        )
        puzzle.cells[0] = 5   // 左上角放 5
        XCTAssertTrue(puzzle.isLegal(6, at: 10))   // 另一行另一列另一宫 → 合法
        XCTAssertFalse(puzzle.isLegal(5, at: 9))   // 同列(第0列) → 冲突
        XCTAssertFalse(puzzle.isLegal(5, at: 1))   // 同行(第0行) → 冲突
        XCTAssertFalse(puzzle.isLegal(5, at: 11))  // 同宫(左上宫) → 冲突
    }

    func testWrongCellsDetection() {
        let givens = Array(repeating: false, count: 81)
        let solution = [Int](repeating: 1, count: 81)
        var puzzle = SudokuPuzzle(cells: [Int](repeating: 0, count: 81), givens: givens, solution: solution, difficulty: .easy)
        puzzle.cells[0] = 2   // 错
        puzzle.cells[1] = 1   // 对
        XCTAssertEqual(puzzle.wrongCells, [0])
    }

    func testToggleNoteAndClearNotes() {
        let givens = Array(repeating: false, count: 81)
        var puzzle = SudokuPuzzle(cells: [Int](repeating: 0, count: 81), givens: givens, solution: [Int](repeating: 0, count: 81), difficulty: .easy)
        XCTAssertTrue(puzzle.toggleNote(3, at: 5))
        XCTAssertEqual(puzzle.notes[5], [3])
        XCTAssertTrue(puzzle.toggleNote(3, at: 5))
        XCTAssertTrue(puzzle.notes[5].isEmpty)
        XCTAssertTrue(puzzle.toggleNote(1, at: 5))
        puzzle.clearNotes(at: 5)
        XCTAssertTrue(puzzle.notes[5].isEmpty)
    }

    func testGivensCannotBeModified() {
        let given = wikiPuzzle()
        var puzzle = given
        let givenIndex = given.cells.firstIndex { $0 != 0 }!
        puzzle.set(9, at: givenIndex)
        XCTAssertEqual(puzzle.cells[givenIndex], given.cells[givenIndex])
    }
}

final class SudokuGeneratorTests: XCTestCase {

    func testGeneratedPuzzleHasUniqueSolution() {
        for difficulty in Difficulty.allCases {
            let puzzle = SudokuGenerator.generate(difficulty: difficulty)
            let solutions = SudokuSolver.solveAll(puzzle, limit: 2)
            XCTAssertEqual(solutions.count, 1, "\(difficulty) 题面应唯一解")
        }
    }

    func testGeneratedPuzzleEmptyCountMeetsTarget() {
        for difficulty in Difficulty.allCases {
            let puzzle = SudokuGenerator.generate(difficulty: difficulty)
            let emptyCount = puzzle.cells.filter { $0 == 0 }.count
            // 目标值是尽量逼近的上限,受唯一解约束可能略少,允许浮动 2。
            XCTAssertGreaterThanOrEqual(emptyCount, difficulty.targetEmptyCells - 2,
                                        "\(difficulty) 空格数不应低于目标")
            XCTAssertLessThanOrEqual(difficulty.targetEmptyCells - emptyCount, 2,
                                     "\(difficulty) 空格数应尽量接近目标")
        }
    }

    func testGeneratedGivensMatchNonEmptyCells() {
        let puzzle = SudokuGenerator.generate(difficulty: .medium)
        for i in 0..<81 {
            XCTAssertEqual(puzzle.givens[i], puzzle.cells[i] != 0,
                           "给定标记应与非空格一致")
        }
    }

    func testGeneratedPuzzleIsValid() {
        let puzzle = SudokuGenerator.generate(difficulty: .expert)
        XCTAssertTrue(puzzle.isValid)
    }
}

final class GameViewModelTests: XCTestCase {

    /// 用 wiki 题面构造一个带解的 ViewModel(给定格可选中填数)。
    private func makeViewModel() -> GameViewModel {
        let puzzle = SudokuGenerator.generate(difficulty: .easy)
        return GameViewModel(puzzle: puzzle)
    }

    /// 找第一个空位。
    private func firstEmptyIndex(of puzzle: SudokuPuzzle) -> Int {
        puzzle.cells.firstIndex { $0 == 0 }!
    }

    func testPlaceValueAndErrorDetection() {
        let vm = makeViewModel()
        let idx = firstEmptyIndex(of: vm.puzzle)
        let correct = vm.puzzle.solution[idx]

        vm.select(idx)
        vm.placeValue(correct)
        XCTAssertEqual(vm.puzzle.cells[idx], correct)
        XCTAssertEqual(vm.errors, 0)

        // 在另一空位放错误数字。
        let idx2 = vm.puzzle.cells.firstIndex { $0 == 0 }!
        let wrong = (vm.puzzle.solution[idx2] % 9) + 1
        vm.select(idx2)
        vm.placeValue(wrong)
        XCTAssertEqual(vm.puzzle.cells[idx2], wrong)
        XCTAssertEqual(vm.errors, 1)
        XCTAssertTrue(vm.puzzle.wrongCells.contains(idx2))
    }

    func testGivenCellCannotBeModified() {
        let vm = makeViewModel()
        let givenIndex = vm.puzzle.givens.firstIndex { $0 }!
        let original = vm.puzzle.cells[givenIndex]

        vm.select(givenIndex)
        vm.placeValue((original % 9) + 1)
        XCTAssertEqual(vm.puzzle.cells[givenIndex], original)
    }

    func testUndoRedo() {
        let vm = makeViewModel()
        let idx = firstEmptyIndex(of: vm.puzzle)
        let value = vm.puzzle.solution[idx]

        vm.select(idx)
        vm.placeValue(value)
        XCTAssertTrue(vm.canUndo)
        XCTAssertFalse(vm.canRedo)

        vm.undo()
        XCTAssertEqual(vm.puzzle.cells[idx], 0)
        XCTAssertTrue(vm.canRedo)
        XCTAssertFalse(vm.canUndo)

        vm.redo()
        XCTAssertEqual(vm.puzzle.cells[idx], value)
        XCTAssertTrue(vm.canUndo)
        XCTAssertFalse(vm.canRedo)
    }

    func testNoteModeToggles() {
        let vm = makeViewModel()
        let idx = firstEmptyIndex(of: vm.puzzle)

        vm.select(idx)
        vm.isNoteMode = true
        vm.inputNumber(3)
        vm.inputNumber(7)
        XCTAssertEqual(vm.puzzle.notes[idx], [3, 7])

        // 再次输入 3 → 移除。
        vm.inputNumber(3)
        XCTAssertEqual(vm.puzzle.notes[idx], [7])
    }

    func testErase() {
        let vm = makeViewModel()
        let idx = firstEmptyIndex(of: vm.puzzle)
        let value = vm.puzzle.solution[idx]

        vm.select(idx)
        vm.placeValue(value)
        XCTAssertEqual(vm.puzzle.cells[idx], value)

        vm.erase()
        XCTAssertEqual(vm.puzzle.cells[idx], 0)
        XCTAssertTrue(vm.canUndo)
    }

    func testHintTargetsCorrectEmptyCell() {
        let vm = makeViewModel()
        let emptyIndexes = (0..<81).filter { vm.puzzle.cells[$0] == 0 }
        vm.select(emptyIndexes[0])
        vm.requestHint()
        XCTAssertNotNil(vm.hintIndex)
        let hint = vm.hintIndex!
        XCTAssertEqual(vm.puzzle.cells[hint], 0)
        // 提示指向的格,应存在可填的正确数字。
        XCTAssertTrue(SudokuSolver.isPlacementValid(vm.puzzle.cells, vm.puzzle.solution[hint], at: hint))
    }

    func testCompletionDetection() {
        let vm = makeViewModel()
        // 把棋盘逐步填到完成。
        var idx = 0
        while !vm.isCompleted && idx < 200 {
            if let empty = vm.puzzle.cells.firstIndex(where: { $0 == 0 }) {
                vm.select(empty)
                vm.placeValue(vm.puzzle.solution[empty])
            }
            idx += 1
        }
        XCTAssertTrue(vm.isCompleted)
        XCTAssertEqual(vm.puzzle.wrongCells.count, 0)
    }
}

/// MarkdownBubble 解析器测试:验证标题/列表/表格等 markdown 块被正确识别。
final class MarkdownParserTests: XCTestCase {

    private func parse(_ md: String) -> [MarkdownBlock] {
        MarkdownBubble(markdown: md).blocks
    }

    private func blockKind(_ b: MarkdownBlock) -> String {
        switch b {
        case .heading: return "heading"
        case .bullet: return "bullet"
        case .numbered: return "numbered"
        case .code: return "code"
        case .paragraph: return "paragraph"
        case .table: return "table"
        }
    }

    func testHeadingParsing() {
        let blocks = parse("# 标题\n## 副标题\n### 三级")
        XCTAssertEqual(blocks.map { blockKind($0) }, ["heading", "heading", "heading"])
        if case .heading(let level, let text) = blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "标题")
        } else { XCTFail("应为标题") }
    }

    func testListParsing() {
        let blocks = parse("- 项目一\n- 项目二\n1. 第一步\n2. 第二步")
        XCTAssertEqual(blocks.map { blockKind($0) }, ["bullet", "bullet", "numbered", "numbered"])
    }

    func testTableParsing() {
        let md = """
        | 技巧 | 说明 |
        |------|------|
        | 裸单 | 只剩一个候选 |
        | 排除法 | 单元唯一位置 |
        """
        let blocks = parse(md)
        XCTAssertEqual(blocks.map { blockKind($0) }, ["table"])
        if case .table(let header, let rows) = blocks[0] {
            XCTAssertEqual(header, ["技巧", "说明"])
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0], ["裸单", "只剩一个候选"])
        } else { XCTFail("应为表格") }
    }

    func testParagraphAndBold() {
        let blocks = parse("这是**加粗**和普通文字。")
        XCTAssertEqual(blocks.map { blockKind($0) }, ["paragraph"])
    }

    func testCodeBlock() {
        let blocks = parse("```swift\nlet x = 1\n```")
        XCTAssertEqual(blocks.map { blockKind($0) }, ["code"])
    }

    func testMixedMarkdown() {
        let md = """
        # 数独技巧

        **基础技巧**包括:

        1. 唯一候选
        2. 排除法

        - 第一项
        - 第二项

        | 技巧 | 说明 |
        |------|------|
        | 裸单 | 只剩一个候选 |
        """
        let kinds = parse(md).map { blockKind($0) }
        XCTAssertTrue(kinds.contains("heading"))
        XCTAssertTrue(kinds.contains("numbered"))
        XCTAssertTrue(kinds.contains("bullet"))
        XCTAssertTrue(kinds.contains("table"))
        XCTAssertTrue(kinds.contains("paragraph"))
    }
}
