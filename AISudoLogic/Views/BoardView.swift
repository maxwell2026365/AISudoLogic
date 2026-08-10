//
//  BoardView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI

/// 9×9 数独棋盘:3×3 宫粗边框、给定/玩家/错误着色、选中与高亮联动。
/// 纯展示组件,所有状态由外部(ViewModel)驱动,便于独立测试与预览。
struct BoardView: View {
    let puzzle: SudokuPuzzle
    let selectedIndex: Int?
    let highlightedValue: Int?
    let hintIndex: Int?
    let wrongCells: Set<Int>
    let onSelect: (Int) -> Void

    private var selectedRow: Int? { selectedIndex.map { SudokuPuzzle.row(of: $0) } }
    private var selectedCol: Int? { selectedIndex.map { SudokuPuzzle.col(of: $0) } }
    private var selectedBox: Int? { selectedIndex.map { SudokuPuzzle.box(of: $0) } }

    var body: some View {
        boardContent
            .aspectRatio(1, contentMode: .fit)
            .padding(8)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    /// 棋盘本体:9×9 正方形网格 + 网格线 + 行列号,直接撑满容器。
    private var boardContent: some View {
        GeometryReader { geo in
            let labelWidth: CGFloat = 14
            let spacing: CGFloat = 4
            // 扣除左侧行号 + 顶部列号 + 间距后的棋盘边长。
            let side = min(geo.size.width - labelWidth - spacing, geo.size.height - labelWidth - spacing)
            let cellSize = side / 9

            HStack(spacing: 4) {
                // 左侧:行号(1-9),顶部空出列号行高度,与棋盘网格垂直对齐。
                VStack(spacing: 0) {
                    // 占位:与顶部列号行等高,让行号对准网格。
                    Color.clear
                        .frame(width: labelWidth, height: labelWidth)
                    ForEach(0..<9, id: \.self) { row in
                        Text("\(row + 1)")
                            .font(.system(size: cellSize * 0.3, weight: .regular, design: .rounded))
                            .foregroundStyle(labelColor)
                            .frame(width: labelWidth, height: cellSize)
                    }
                }
                .frame(height: side + labelWidth)

                // 棋盘主体
                VStack(spacing: 0) {
                    // 顶部:列号(1-9)
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            Text("\(col + 1)")
                                .font(.system(size: cellSize * 0.3, weight: .regular, design: .rounded))
                                .foregroundStyle(labelColor)
                                .frame(width: cellSize, height: labelWidth)
                        }
                    }
                    .frame(width: side)

                    // 网格
                    ZStack {
                        VStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { row in
                                HStack(spacing: 0) {
                                    ForEach(0..<9, id: \.self) { col in
                                        cellView(for: row * 9 + col)
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                        gridLines(size: side)
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @Environment(\.colorScheme) private var scheme
    /// 行列号颜色:深浅色模式下都清晰可见。
    private var labelColor: Color {
        scheme == .dark
            ? Color.white.opacity(0.7)
            : Color.primary.opacity(0.6)
    }
    private var cardBackground: Color {
        scheme == .dark
            ? Color(red: 0.13, green: 0.14, blue: 0.17)
            : Color(red: 0.93, green: 0.925, blue: 0.90)
    }

    private func cellView(for index: Int) -> some View {
        let value = puzzle.cells[index]
        let isGiven = puzzle.givens[index]
        let notes = puzzle.notes[index]
        let box = SudokuPuzzle.box(of: index)

        return CellView(
            value: value,
            isGiven: isGiven,
            isSelected: index == selectedIndex,
            isInPeers: isPeer(of: index),
            isSameValue: value != 0 && value == highlightedValue,
            isHint: index == hintIndex,
            isWrong: wrongCells.contains(index),
            notes: notes,
            boxIndex: box
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect(index) }
        .accessibilityLabel(accessibilityLabel(for: index))
        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
    }

    /// 是否与选中格同行/同列/同宫。
    private func isPeer(of index: Int) -> Bool {
        guard let sel = selectedIndex else { return false }
        if index == sel { return false }
        return SudokuPuzzle.row(of: index) == selectedRow
            || SudokuPuzzle.col(of: index) == selectedCol
            || SudokuPuzzle.box(of: index) == selectedBox
    }

    private func gridLines(size: CGFloat) -> some View {
        let thin: CGFloat = 1
        let thick: CGFloat = 2.5
        return ZStack {
            // 宫边界粗线
            ForEach([3, 6], id: \.self) { line in
                // 垂直线
                Rectangle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: thick, height: size)
                    .position(x: size * CGFloat(line) / 9, y: size / 2)
                // 水平线
                Rectangle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: size, height: thick)
                    .position(x: size / 2, y: size * CGFloat(line) / 9)
            }
            // 宫内细线(1,2,4,5,7,8)
            ForEach([1, 2, 4, 5, 7, 8], id: \.self) { line in
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: thin, height: size)
                    .position(x: size * CGFloat(line) / 9, y: size / 2)
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: size, height: thin)
                    .position(x: size / 2, y: size * CGFloat(line) / 9)
            }
        }
        .allowsHitTesting(false)
    }

    private func accessibilityLabel(for index: Int) -> String {
        let r = SudokuPuzzle.row(of: index) + 1
        let c = SudokuPuzzle.col(of: index) + 1
        let value = puzzle.cells[index]
        let valueDesc = value == 0 ? "空" : "数字\(value)"
        return "第\(r)行第\(c)列,\(valueDesc)"
    }
}

/// 单个数独格子,背景色按 3×3 宫分组,方便用户区分不同九宫格。
struct CellView: View {
    let value: Int
    let isGiven: Bool
    let isSelected: Bool
    let isInPeers: Bool
    let isSameValue: Bool
    let isHint: Bool
    let isWrong: Bool
    let notes: Set<Int>
    let boxIndex: Int
    /// 首次布局是否已完成(门控:初次不播放值动画,避免开局闪烁)。
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    /// 每个 3×3 宫独立一个柔和色,相邻宫不同色,视觉安静有辨识度。
    private var baseBackground: Color {
        BoxPalette.colors(boxIndex: boxIndex, scheme: colorScheme)
    }

    var body: some View {
        ZStack {
            baseBackground
            overlayColor
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: 22, weight: isGiven ? .bold : .regular, design: .rounded))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.5)
                    .id(value)
                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
            } else if !notes.isEmpty {
                NotesGrid(notes: notes)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(appeared ? .easeInOut(duration: 0.5) : nil, value: isSelected)
        .animation(appeared ? .easeInOut(duration: 0.5) : nil, value: isInPeers)
        .animation(appeared ? .easeInOut(duration: 0.5) : nil, value: isSameValue)
        .animation(appeared ? .easeInOut(duration: 0.5) : nil, value: isHint)
        .animation(appeared ? .easeInOut(duration: 0.5) : nil, value: isWrong)
        .animation(appeared ? .easeInOut(duration: 0.5) : nil, value: value)
        .onAppear {
            appeared = true
        }
    }

    private var overlayColor: Color {
        if isHint {
            // 提示格:醒目的暖金色,最高优先级。
            return Color(red: 1.0, green: 0.78, blue: 0.25).opacity(0.55)
        }
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if isInPeers {
            return Color.accentColor.opacity(0.12)
        }
        if isSameValue {
            return Color.accentColor.opacity(0.08)
        }
        return .clear
    }

    private var textColor: Color {
        if isWrong { return .red }
        return isGiven ? Color.primary : Color.accentColor
    }
}

/// 3×3 宫的柔和配色:9 个宫各一个低饱和马卡龙色,
/// 深浅色两套,保证对比度适中、视觉安静舒服。
enum BoxPalette {
    /// 浅色模式的 9 宫底色(低饱和、高明度)。
    static let light: [Color] = [
        Color(red: 0.96, green: 0.92, blue: 0.84),  // 暖米
        Color(red: 0.90, green: 0.94, blue: 0.92),  // 淡薄荷
        Color(red: 0.93, green: 0.91, blue: 0.96),  // 淡紫
        Color(red: 0.95, green: 0.89, blue: 0.90),  // 淡粉
        Color(red: 0.89, green: 0.93, blue: 0.96),  // 淡蓝
        Color(red: 0.96, green: 0.94, blue: 0.88),  // 淡杏
        Color(red: 0.92, green: 0.96, blue: 0.90),  // 淡青
        Color(red: 0.96, green: 0.90, blue: 0.93),  // 淡玫瑰
        Color(red: 0.91, green: 0.92, blue: 0.95),  // 淡灰蓝
    ]

    /// 深色模式的 9 宫底色(低饱和、低明度,保持柔和)。
    static let dark: [Color] = [
        Color(red: 0.24, green: 0.21, blue: 0.18),  // 暖棕
        Color(red: 0.18, green: 0.24, blue: 0.22),  // 深薄荷
        Color(red: 0.22, green: 0.20, blue: 0.27),  // 深紫
        Color(red: 0.25, green: 0.20, blue: 0.21),  // 深粉
        Color(red: 0.18, green: 0.22, blue: 0.27),  // 深蓝
        Color(red: 0.26, green: 0.24, blue: 0.20),  // 深杏
        Color(red: 0.19, green: 0.26, blue: 0.22),  // 深青
        Color(red: 0.26, green: 0.20, blue: 0.24),  // 深玫瑰
        Color(red: 0.20, green: 0.21, blue: 0.25),  // 深灰蓝
    ]

    static func colors(boxIndex: Int, scheme: ColorScheme) -> Color {
        let palette = scheme == .dark ? dark : light
        return palette[boxIndex % 9]
    }
}

/// 笔记小网格:9 格显示 1-9,存在候选的亮起。
struct NotesGrid: View {
    let notes: Set<Int>

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let value = row * 3 + col + 1
                        Text(notes.contains(value) ? "\(value)" : " ")
                            .font(.system(size: 8, weight: .light))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(2)
    }
}

#Preview("Board") {
    BoardView(
        puzzle: {
            let givens = (0..<81).map { $0 % 2 == 0 }
            var cells = [Int](repeating: 0, count: 81)
            cells[0] = 5; cells[2] = 7; cells[4] = 3
            cells[10] = 1; cells[12] = 9
            var p = SudokuPuzzle(cells: cells, givens: givens, solution: [Int](repeating: 1, count: 81), difficulty: .easy)
            p.notes[1] = [2, 4]; p.notes[3] = [1, 6, 9]; p.notes[5] = [3, 5]
            return p
        }(),
        selectedIndex: 10,
        highlightedValue: 5,
        hintIndex: nil,
        wrongCells: [2],
        onSelect: { _ in }
    )
    .padding(20)
    .frame(width: 360, height: 360)
}

#Preview("Empty") {
    BoardView(
        puzzle: SudokuPuzzle(cells: [Int](repeating: 0, count: 81), givens: Array(repeating: false, count: 81), solution: [Int](repeating: 1, count: 81), difficulty: .easy),
        selectedIndex: nil,
        highlightedValue: nil,
        hintIndex: nil,
        wrongCells: [],
        onSelect: { _ in }
    )
    .padding(20)
    .frame(width: 360, height: 360)
}
