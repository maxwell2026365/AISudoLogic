//
//  LayoutConstants.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/12.
//

import SwiftUI

/// 全局窗口与游戏布局尺寸常量。
/// 窗口为黄金比例(宽高比 ≈ 0.618):高度 = 728,宽度 = 450(450/728 ≈ 0.618)。
/// 宽高取整到像素,让窗口边框无毛边。棋盘、提示区、工具栏、数字键盘共同
/// 恰好填满窗口,无多余留白。
enum AppLayout {
    static let windowWidth: CGFloat = 450
    static let windowHeight: CGFloat = 728

    /// 顶部栏高度。
    static let topBarHeight: CGFloat = 44
    /// 工具栏 + 数字键盘的固定高度预算(含纵向 padding)。
    static let bottomChromeHeight: CGFloat = 96
    /// 顶栏 + 底部区块的固定高度预算。
    static let chromeHeight: CGFloat = topBarHeight + bottomChromeHeight
    /// 顶栏 + 底部区块 + 棋盘卡片的纵向 padding 预算。
    static let boardPadding: CGFloat = 20
    /// AI 提示区固定高度(内容超限时内部滚动,布局稳定)。
    static let hintHeight: CGFloat = 148
    /// AI 提示区标题行 + 卡片边框高度。
    static let hintTitleHeight: CGFloat = 30
}
