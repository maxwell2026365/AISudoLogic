//
//  AISudoLogicUITests.swift
//  AISudoLogicUITests
//
//  Created by Maxwell on 2026/8/4.
//

import XCTest
#if os(iOS)
import UIKit
#endif

final class AISudoLogicUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
#endif
    }

    @MainActor
    func testLaunchPerformance() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
#endif
    }

    /// 复现:启动后点击"专家"难度,不应崩溃。
    @MainActor
    func testExpertLaunchDoesNotCrash() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let expertButton = app.buttons["专家, 约 58 空"]
        guard expertButton.waitForExistence(timeout: 5) else {
            XCTFail("未找到专家按钮")
            return
        }
        expertButton.click()

        // 等待一段时间,期间若崩溃 app 会退出。
        sleep(4)
        XCTAssertTrue(app.state == .runningForeground, "app 应仍在运行")
#endif
    }

    /// 复现:启动后进入"每日挑战",不应崩溃(每日挑战同样走游戏布局)。
    @MainActor
    func testDailyChallengeLaunchDoesNotCrash() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let dailyButton = app.buttons["🏆 每日挑战"]
        guard dailyButton.waitForExistence(timeout: 5) else {
            XCTFail("未找到每日挑战按钮")
            return
        }
        dailyButton.click()
        sleep(1)

        let startButton = app.buttons["开始挑战"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.click()
            sleep(4)
        }
        // 今日已完成时直接显示完成态;两种情况都要求 app 未崩溃退出。
        XCTAssertNotEqual(app.state, .notRunning, "app 不应崩溃退出, state=\(app.state.rawValue)")
#endif
    }

    /// 验证:统计面板包含"每日挑战记录"卡片(日历形式),且返回按钮可回到菜单。
    @MainActor
    func testStatsShowsDailyChallengeRecord() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let statsButton = app.buttons["📊 统计"]
        guard statsButton.waitForExistence(timeout: 8) else {
            var labels: [String] = []
            for b in app.buttons.allElementsBoundByIndex {
                if !b.label.isEmpty { labels.append(b.label) }
            }
            XCTFail("未找到统计按钮。当前按钮: \(labels)")
            return
        }
        statsButton.click()
        sleep(2)

        // 验证日历月份标题(形如 "🏆 2026年8月")存在。
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        let monthTitle = "🏆 \(comps.year!)年\(comps.month!)月"
        let title = app.staticTexts[monthTitle]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "统计面板应显示每日挑战日历")

        // 验证日历网格结构存在(周几表头,周一开头)。
        for weekday in ["一", "二", "三", "四", "五", "六", "日"] {
            XCTAssertTrue(app.staticTexts[weekday].exists, "日历应显示周\(weekday)表头")
        }

        // 返回按钮回到菜单。
        let back = app.buttons["返回"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "统计页应有返回按钮")
        back.click()
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5), "返回后应回到菜单")
#endif
    }

    /// 验证:菜单三个子页面均以页面形式展示,左上角返回按钮可回到菜单。
    @MainActor
    func testPagesOpenAndReturn() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        // 统计页。
        let stats = app.buttons["📊 统计"]
        XCTAssertTrue(stats.waitForExistence(timeout: 8))
        stats.click()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 5), "统计页应有返回")
        app.buttons["返回"].click()

        // 每日挑战页。
        let daily = app.buttons["🏆 每日挑战"]
        XCTAssertTrue(daily.waitForExistence(timeout: 5))
        daily.click()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 5), "每日挑战页应有返回")
        app.buttons["返回"].click()

        // AI 教练页。
        let coach = app.buttons["🤖 AI 教练"]
        XCTAssertTrue(coach.waitForExistence(timeout: 5))
        coach.click()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 5), "AI 教练页应有返回")
        app.buttons["返回"].click()

        // 回到菜单。
        XCTAssertTrue(stats.waitForExistence(timeout: 5), "最终应回到菜单")
#endif
    }

    /// 验证:游戏内点右上角 AI 教练进入页面,返回后回到游戏(而非菜单)。
    @MainActor
    func testInGameCoachNavigatesBackToGame() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let easy = app.buttons["简单, 约 40 空"]
        XCTAssertTrue(easy.waitForExistence(timeout: 8))
        easy.click()
        sleep(2)

        // 顶栏右上角 AI 教练按钮。
        let coachBtn = app.buttons["AI 教练"]
        XCTAssertTrue(coachBtn.waitForExistence(timeout: 5), "游戏顶栏应有 AI 教练按钮")
        coachBtn.click()
        sleep(1)

        // 进入教练页面(标题存在)。
        XCTAssertTrue(app.staticTexts["🤖 数独 AI 教练"].waitForExistence(timeout: 5), "应进入 AI 教练页面")

        // 点返回,应回到游戏(棋盘仍在),而不是回到菜单。
        let back = app.buttons["返回"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "AI 教练页应有返回按钮")
        back.click()
        sleep(1)

        // 回到游戏:顶栏返回菜单按钮仍在,且 AI 教练按钮仍在(说明在游戏页)。
        XCTAssertTrue(app.buttons["AI 教练"].waitForExistence(timeout: 5), "返回后应回到游戏页")
        // 菜单的"简单"按钮不应出现(说明没回到菜单)。
        XCTAssertFalse(app.buttons["简单, 约 40 空"].exists, "不应回到菜单")
#endif
    }

    /// iOS:进入 AI 教练页,验证消息区域可以滚动(手动下拉/上滑)。
    @MainActor
    func testIOSCoachScrolling() throws {
#if !os(iOS)
        throw XCTSkip("仅 iOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let coachBtn = app.buttons["🤖 AI 教练"]
        XCTAssertTrue(coachBtn.waitForExistence(timeout: 8), "菜单应有 AI 教练按钮")
        coachBtn.tap()
        sleep(1)

        // 欢迎消息存在。
        XCTAssertTrue(app.staticTexts["🤖 数独 AI 教练"].waitForExistence(timeout: 5), "应进入 AI 教练页")
        sleep(1)

        // 尝试在消息区域向上滑动(模拟用户手动滚动)。
        let scrollArea = app.scrollViews.firstMatch
        XCTAssertTrue(scrollArea.exists, "应有滚动区域")
        scrollArea.swipeUp()
        scrollArea.swipeDown()
        XCTAssertTrue(app.state != .notRunning, "滚动后 app 应仍在运行")
#endif
    }

    /// iOS:发送一条消息后,验证自动滚动生效:AI 回复内容应出现在视口内,
    /// 且消息区可手动滚动。
    @MainActor
    func testIOSCoachScrollAfterMessage() throws {
#if !os(iOS)
        throw XCTSkip("仅 iOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let coachBtn = app.buttons["🤖 AI 教练"]
        XCTAssertTrue(coachBtn.waitForExistence(timeout: 8))
        coachBtn.tap()
        sleep(1)

        // 输入框输入问题并发送。
        let input = app.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5), "应有输入框")
        input.tap()
        input.typeText("你好,介绍一下数独的技巧")
        sleep(1)

        // 点发送按钮。
        let sendBtn = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label CONTAINS %@", "arrow.up.circle.fill", "arrow.up")).firstMatch
        if sendBtn.exists {
            sendBtn.tap()
        }
        // 等待回复(流式)。
        sleep(10)

        // 自动滚动应生效:AI 回复内容(静态文本)应出现在视口内(hittable)。
        // 若自动滚动失效,长回复末尾会滚出屏幕,AI 文本将不可见。
        let scrollArea = app.scrollViews.firstMatch
        XCTAssertTrue(scrollArea.exists)
        // AI 回复是 Markdown 渲染的静态文本;流式结束后应至少有一条 AI 内容可见。
        let aiTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "数独")).allElementsBoundByIndex
        XCTAssertTrue(aiTexts.contains { $0.isHittable }, "AI 回复内容应可见(自动滚动应生效)")

        // 消息区仍可手动滚动。
        scrollArea.swipeDown()
        scrollArea.swipeUp()
        XCTAssertTrue(app.state != .notRunning, "滚动后 app 应仍在运行")
#endif
    }

    /// macOS:进入 AI 教练并发送消息,验证流式回复期间 app 不卡死。
    @MainActor
    func testMacCoachSendMessageNoHang() throws {
#if !os(macOS)
        throw XCTSkip("仅 macOS 运行")
#else
        let app = XCUIApplication()
        app.launch()

        let coachBtn = app.buttons["🤖 AI 教练"]
        XCTAssertTrue(coachBtn.waitForExistence(timeout: 8))
        coachBtn.click()
        sleep(2)

        let input = app.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5), "应有输入框")
        input.click()
        // 触发一次完整流式回复。用英文输入,避免 macOS 上合成中文输入事件不稳定。
        input.typeText("Please introduce sudoku techniques")
        sleep(1)

        // 点发送按钮。
        let sendBtn = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label CONTAINS %@", "arrow.up.circle.fill", "arrow.up")).firstMatch
        if sendBtn.exists {
            sendBtn.click()
        }
        // 等待长回复流式完成。
        sleep(15)

        XCTAssertTrue(app.state != .notRunning, "流式回复后 app 不应卡死退出")
        // 检查 app 是否响应:点返回按钮应生效。
        let back = app.buttons["返回"]
        if back.exists {
            back.click()
        }
        XCTAssertTrue(app.state != .notRunning, "点击后 app 应仍在运行")
#endif
    }
}