//
//  DailyChallengeView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/8.
//

import SwiftUI

/// 每日挑战:按日期生成固定题面,完成获得奖杯。每天只有一题。
struct DailyChallengeView: View {
    /// 今日奖杯(是否已完成今日挑战)。
    let todayTrophy: Trophy?
    let onPlay: () -> Void
    /// 返回上一级(菜单)。
    var onBack: (() -> Void)? = nil

    private var isCompletedToday: Bool { todayTrophy != nil }

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer()

            Image(systemName: isCompletedToday ? "trophy.fill" : "trophy")
                .font(.system(size: 60))
                .foregroundStyle(isCompletedToday ? .yellow : .secondary)

            Text("每日挑战")
                .font(.title.bold())

            Text(isCompletedToday ? "今日挑战已完成!🏆" : "每天一题数独,完成即可获得奖杯。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let trophy = todayTrophy {
                VStack(spacing: 6) {
                    Text("🎉 获得奖杯")
                        .font(.headline)
                    Text("用时 \(formatTime(trophy.elapsed)) · 错误 \(trophy.errors) 次")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Button(action: onPlay) {
                    Text("开始挑战")
                        .font(.headline)
                        .frame(maxWidth: 200, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        ZStack {
            // 奖杯图标水平居中。
            HStack {
                Spacer()
                Text("🏆")
                    .font(.title)
                Spacer()
            }
            // 返回按钮:左上角。
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Label("返回", systemImage: "chevron.left")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回")
                }
                Spacer()
            }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "%d秒", s)
    }
}

#Preview("Daily") {
    DailyChallengeView(todayTrophy: nil, onPlay: {})
}
