//
//  NumberPadView.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/4.
//

import SwiftUI

/// 底部数字键盘:1-9 + 可选擦除按钮,高亮当前数字。
struct NumberPadView: View {
    let selectedValue: Int?
    let onNumber: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 9)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { value in
                Button {
                    onNumber(value)
                } label: {
                    Text("\(value)")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(buttonBackground(isActive: value == selectedValue))
                        .foregroundStyle(value == selectedValue ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("输入数字\(value)")
            }
        }
    }

    private func buttonBackground(isActive: Bool) -> Color {
#if os(iOS)
        return isActive ? Color.accentColor.opacity(0.25) : Color(.secondarySystemBackground)
#else
        return isActive ? Color.accentColor.opacity(0.25) : Color(nsColor: .controlBackgroundColor)
#endif
    }
}

#Preview("NumberPad") {
    NumberPadView(selectedValue: 5, onNumber: { _ in })
        .padding()
        .frame(width: 360)
}
