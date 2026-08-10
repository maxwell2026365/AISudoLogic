//
//  PersistenceStore.swift
//  AISudoLogic
//
//  Created by Maxwell on 2026/8/10.
//

import Foundation
import Combine

/// 文件持久化管理器:替代 SwiftData,支持 iOS 15+ / macOS 12+。
/// 使用 JSON 文件存储 GameSession 和 Trophy,通过 @Published 驱动 UI 更新。
final class PersistenceStore: ObservableObject {
    @Published var sessions: [GameSession] = []
    @Published var trophies: [Trophy] = []

    private let sessionsURL: URL
    private let trophiesURL: URL

    init() {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        self.sessionsURL = dir.appendingPathComponent("game_sessions.json")
        self.trophiesURL = dir.appendingPathComponent("trophies.json")
        load()
    }

    // MARK: - Sessions

    func updateSession(_ session: GameSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        saveSessions()
    }

    /// 已完成的存档(按 startedAt 倒序)。
    var completedSessions: [GameSession] {
        sessions
            .filter { $0.isCompleted }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// 未完成的存档(最近一个)。
    var unfinishedSession: GameSession? {
        sessions
            .filter { !$0.isCompleted }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    /// 全部存档按 startedAt 倒序。
    var sortedSessions: [GameSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Trophies

    func insertTrophy(_ trophy: Trophy) {
        trophies.append(trophy)
        saveTrophies()
    }

    /// 今日奖杯。
    func todayTrophy() -> Trophy? {
        let today = StatsEngine.todayString()
        return trophies.first { $0.day == today }
    }

    // MARK: - IO

    private func load() {
        sessions = decode([GameSession].self, from: sessionsURL) ?? []
        trophies = decode([Trophy].self, from: trophiesURL) ?? []
    }

    private func saveSessions() {
        encode(sessions, to: sessionsURL)
    }

    private func saveTrophies() {
        encode(trophies, to: trophiesURL)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
