//
//  StatsView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/8.
//

import SwiftUI

/// 统计面板:按难度展示通关数、时长、胜率、无错误率、最短/平均时间、连胜、奖杯。
struct StatsView: View {
    let sessions: [GameSession]
    let trophies: [Trophy]
    /// 返回上一级(菜单)。
    var onBack: (() -> Void)? = nil

    /// 日历当前展示的月份(用于每日挑战日历)。
    @State private var displayedMonth = Calendar.current.startOfMonth(Date())
    /// 日历中选中的日期。
    @State private var selectedDate: Date?

    private var summary: StatsSummary {
        StatsEngine.summary(sessions: sessions, trophies: trophies)
    }

    /// 月份标题,如 "2026年8月"。
    private var calendarMonthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: displayedMonth)
    }

    /// 上/下月切换。
    private func changeMonth(by delta: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = Calendar.current.startOfMonth(newMonth)
        selectedDate = nil
    }

    /// 当月日历网格:按周一开头排列,不足 7 天的周用上/下月日期补位。
    private var calendarWeeks: [[Date]] {
        let cal = Calendar.current
        // 当月天数。
        let range = cal.range(of: .day, in: .month, for: displayedMonth)!
        let daysInMonth = range.count
        // 当月第一天是周几(周一 = 0 ... 周日 = 6)。
        let firstDay = cal.component(.weekday, from: displayedMonth) // 1=周日...7=周六
        let leadingOffset = (firstDay + 5) % 7 // 转成周一=0

        // 构造日期数组,前面补上/上月日期。
        var dates: [Date] = []
        let monthStart = cal.startOfMonth(displayedMonth)
        for offset in (0..<leadingOffset).reversed() {
            if let d = cal.date(byAdding: .day, value: -offset - 1, to: monthStart) {
                dates.append(d)
            }
        }
        for d in 0..<daysInMonth {
            if let date = cal.date(byAdding: .day, value: d, to: monthStart) {
                dates.append(date)
            }
        }
        // 补尾部,凑成整周。
        while dates.count % 7 != 0 {
            if let last = dates.last,
               let next = cal.date(byAdding: .day, value: 1, to: last) {
                dates.append(next)
            }
        }
        return stride(from: 0, to: dates.count, by: 7).map { Array(dates[$0..<min($0 + 7, dates.count)]) }
    }

    /// 某天是否有奖杯记录。
    private func trophy(on date: Date) -> Trophy? {
        let cal = Calendar.current
        return trophies.first { trophy in
            guard let trophyDate = Self.date(fromDay: trophy.day) else { return false }
            return cal.isDate(trophyDate, inSameDayAs: date)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    // 总览卡片:总奖杯。
                    overviewCard
                    // 各难度统计。
                    ForEach(Difficulty.allCases) { difficulty in
                        difficultyCard(summary.byDifficulty[difficulty])
                    }
                    // 每日挑战完成记录。
                    dailyChallengeCard
                }
                .padding(16)
            }
        }
        .background(systemBackground)
    }

    private var systemBackground: Color {
#if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
#else
        return Color(.systemBackground)
#endif
    }

    private var header: some View {
        ZStack {
            // 标题水平居中。
            Text("📊 统计")
                .font(.title2.bold())
            HStack {
                // 返回按钮:左上角。
                if let onBack {
                    Button(action: onBack) {
                        Label("返回", systemImage: "chevron.left")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回")
                }
                Spacer()
                Text("🏆 奖杯 \(summary.totalTrophies)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.thinMaterial)
    }

    /// 总览卡片。
    private var overviewCard: some View {
        HStack {
            statBlock(title: "总通关", value: "\(summary.byDifficulty.values.reduce(0) { $0 + $1.wins })")
            Divider()
            statBlock(title: "总奖杯", value: "\(summary.totalTrophies)")
            Divider()
            statBlock(title: "总对局", value: "\(summary.byDifficulty.values.reduce(0) { $0 + $1.totalGames })")
        }
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 单个难度统计卡片。
    private func difficultyCard(_ stats: DifficultyStats?) -> some View {
        let s = stats ?? DifficultyStats(difficulty: .easy)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(s.difficulty.displayName)
                    .font(.headline)
                Spacer()
                Text("🏆 \(s.trophies)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                statBlock(title: "通关数", value: "\(s.wins)")
                statBlock(title: "胜率", value: "\(Int(s.winRate * 100))%")
                statBlock(title: "无错误率", value: "\(Int(s.perfectRate * 100))%")
                statBlock(title: "最短时间", value: formatTime(s.bestTime))
                statBlock(title: "平均时间", value: formatTime(s.averageTime))
                statBlock(title: "当前连胜", value: "\(s.currentStreak)")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 每日挑战完成记录卡片:日历形式展示,有奖杯的日期高亮,点选查看详情。
    private var dailyChallengeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 月份标题 + 上/下月切换。
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("上个月")

                Spacer()
                Text("🏆 \(calendarMonthTitle)")
                    .font(.headline)
                Text("\(trophies.count) 次完成")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("下个月")
            }

            // 周几表头。
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日历网格:每行 7 天。
            let weeks = calendarWeeks
            VStack(spacing: 2) {
                ForEach(0..<weeks.count, id: \.self) { weekIndex in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let day = weeks[weekIndex][dayIndex]
                            calendarDayCell(day)
                        }
                    }
                }
            }

            // 选中日的详情。
            if let selected = selectedDate, let trophy = trophy(on: selected) {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDay(trophy.day))
                            .font(.subheadline.bold())
                        Text("\(trophy.difficulty.displayName) · 用时 \(formatTime(trophy.elapsed))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if trophy.errors == 0 {
                        Text("✓ 无错误")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(trophy.errors) 处错误")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if trophies.isEmpty {
                Text("暂未完成每日挑战")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 单个日历格:显示日期数字,有奖杯的日期用黄色圆底 + 奖杯标记,可点选。
    private func calendarDayCell(_ day: Date) -> some View {
        let dayNumber = Calendar.current.component(.day, from: day)
        let hasTrophy = trophy(on: day) != nil
        let isSelected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(textColor(isSelected: isSelected))
                // 奖杯标记:小圆点或奖杯图标。
                if hasTrophy {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                } else {
                    Color.clear
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(dayBackground(isSelected: isSelected, hasTrophy: hasTrophy))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(hasTrophy == false && isSelected == false)
        .accessibilityLabel("\(dayNumber)日\(hasTrophy ? "已完成" : "")")
    }

    private func textColor(isSelected: Bool) -> Color {
        isSelected ? .white : .primary
    }

    private func dayBackground(isSelected: Bool, hasTrophy: Bool) -> Color {
        if isSelected { return Color.accentColor }
        return hasTrophy ? Color.yellow.opacity(0.18) : Color.clear
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.5)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ t: TimeInterval?) -> String {
        guard let t, t > 0 else { return "--" }
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "%d秒", s)
    }

    /// 奖杯日期 "2026-08-08" → 更可读的 "8月8日"。
    private func formatDay(_ day: String) -> String {
        let parts = day.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else {
            return day
        }
        return "\(m)月\(d)日"
    }

    /// 奖杯日期字符串 "yyyy-MM-dd" → Date。
    private static func date(fromDay day: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar.current
        return f.date(from: day)
    }
}

extension Calendar {
    /// 该日期所在月的第一天(日期部分为 1 号)。
    func startOfMonth(_ date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

#Preview("Stats") {
    StatsView(sessions: [], trophies: [])
}
