//
//  GitHubManager.swift
//  izaNotch
//
//  Created by Antigravity on 30/08/2026.
//

import Foundation
import SwiftUI
import Defaults

public struct GitHubContributionDay: Identifiable, Sendable, Hashable {
    public var id: String { date }
    public let date: String
    public let count: Int
    public let level: Int // 0..4
    public let weekday: Int?
    public let colorHex: String?

    public init(date: String, count: Int, level: Int, weekday: Int? = nil, colorHex: String? = nil) {
        self.date = date
        self.count = count
        self.level = level
        self.weekday = weekday
        self.colorHex = colorHex
    }
}

// MARK: - GraphQL Decodable Models
private struct GitHubGraphQLResponse: Decodable {
    let data: GitHubData?
    let errors: [GitHubError]?

    struct GitHubError: Decodable {
        let message: String
    }

    struct GitHubData: Decodable {
        let user: GitHubUser?
    }

    struct GitHubUser: Decodable {
        let contributionsCollection: GitHubContributionsCollection
    }

    struct GitHubContributionsCollection: Decodable {
        let contributionCalendar: GitHubContributionCalendar
    }

    struct GitHubContributionCalendar: Decodable {
        let totalContributions: Int
        let weeks: [GitHubWeek]
    }

    struct GitHubWeek: Decodable {
        let firstDay: String
        let contributionDays: [GitHubDay]
    }

    struct GitHubDay: Decodable {
        let date: String
        let weekday: Int
        let contributionCount: Int
        let contributionLevel: String
        let color: String

        var levelInt: Int {
            switch contributionLevel {
            case "FIRST_QUARTILE": return 1
            case "SECOND_QUARTILE": return 2
            case "THIRD_QUARTILE": return 3
            case "FOURTH_QUARTILE": return 4
            default: return 0
            }
        }
    }
}

// MARK: - Proxy Decodable Models
private struct GitHubProxyResponse: Decodable {
    let total: [String: Int]?
    let contributions: [GitHubProxyDay]

    struct GitHubProxyDay: Decodable {
        let date: String
        let count: Int
        let level: Int
    }
}

// MARK: - GitHubManager Singleton
@MainActor
public final class GitHubManager: ObservableObject {
    public static let shared = GitHubManager()

    @Published public var contributionDays: [GitHubContributionDay] = []
    @Published public var totalContributions: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var lastUpdated: Date? = nil
    @Published public var errorMessage: String? = nil

    private var refreshTimer: Timer?

    private init() {
        self.contributionDays = Self.defaultPlaceholderDays()
        startTimer()
        Task {
            await refresh()
        }
    }

    private func startTimer() {
        // Auto-refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    public func refresh() async {
        let username = Defaults[.githubUsername].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            if self.contributionDays.isEmpty {
                self.contributionDays = Self.defaultPlaceholderDays()
            }
            return
        }

        let pat = Defaults[.githubPAT].trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        errorMessage = nil

        do {
            let days: [GitHubContributionDay]
            if !pat.isEmpty {
                days = try await fetchViaGraphQL(username: username, token: pat)
            } else {
                days = try await fetchViaProxy(username: username)
            }

            if !days.isEmpty {
                self.contributionDays = days
                self.totalContributions = days.reduce(0) { $0 + $1.count }
                self.lastUpdated = Date()
            }
        } catch {
            self.errorMessage = error.localizedDescription
            if self.contributionDays.isEmpty {
                self.contributionDays = Self.defaultPlaceholderDays()
            }
        }

        isLoading = false
    }

    // MARK: - GraphQL API (With PAT)
    private func fetchViaGraphQL(username: String, token: String) async throws -> [GitHubContributionDay] {
        guard let url = URL(string: "https://api.github.com/graphql") else {
            throw URLError(.badURL)
        }

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let fromDate = calendar.date(byAdding: .day, value: -48, to: now) ?? now

        let isoFormatter = ISO8601DateFormatter()
        let fromStr = isoFormatter.string(from: fromDate)
        let toStr = isoFormatter.string(from: now)

        let query = """
        query GetContributions($username: String!, $from: DateTime!, $to: DateTime!) {
          user(login: $username) {
            contributionsCollection(from: $from, to: $to) {
              contributionCalendar {
                totalContributions
                weeks {
                  firstDay
                  contributionDays {
                    date
                    weekday
                    contributionCount
                    contributionLevel
                    color
                  }
                }
              }
            }
          }
        }
        """

        let payload: [String: Any] = [
            "query": query,
            "variables": [
                "username": username,
                "from": fromStr,
                "to": toStr
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("boringNotch-macOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "GitHubGraphQL", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(code)"])
        }

        let decoded = try JSONDecoder().decode(GitHubGraphQLResponse.self, from: data)
        if let err = decoded.errors?.first {
            throw NSError(domain: "GitHubGraphQL", code: 400, userInfo: [NSLocalizedDescriptionKey: err.message])
        }

        guard let weeks = decoded.data?.user?.contributionsCollection.contributionCalendar.weeks else {
            return []
        }

        let allDays = weeks.flatMap { $0.contributionDays }.map {
            GitHubContributionDay(
                date: $0.date,
                count: $0.contributionCount,
                level: $0.levelInt,
                weekday: $0.weekday,
                colorHex: $0.color
            )
        }

        // Return the latest 49 days (7x7)
        if allDays.count >= 49 {
            return Array(allDays.suffix(49))
        } else {
            let paddingCount = 49 - allDays.count
            let pad = (0..<paddingCount).map { i in
                GitHubContributionDay(date: "pad-\(i)", count: 0, level: 0)
            }
            return pad + allDays
        }
    }

    // MARK: - Public Proxy API (Without Token)
    private func fetchViaProxy(username: String) async throws -> [GitHubContributionDay] {
        guard let url = URL(string: "https://github-contributions-api.jogruber.de/v4/\(username)?y=last") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("boringNotch-macOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "GitHubProxy", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(code)"])
        }

        let decoded = try JSONDecoder().decode(GitHubProxyResponse.self, from: data)
        let days = decoded.contributions.map {
            GitHubContributionDay(date: $0.date, count: $0.count, level: $0.level)
        }

        if days.count >= 49 {
            return Array(days.suffix(49))
        } else {
            let paddingCount = 49 - days.count
            let pad = (0..<paddingCount).map { i in
                GitHubContributionDay(date: "pad-\(i)", count: 0, level: 0)
            }
            return pad + days
        }
    }

    public static func defaultPlaceholderDays() -> [GitHubContributionDay] {
        let levels: [Int] = [
            0, 0, 1, 2, 3, 4, 4,
            0, 1, 0, 2, 4, 3, 4,
            0, 0, 2, 3, 2, 4, 3,
            1, 0, 1, 3, 4, 3, 4,
            0, 1, 0, 2, 3, 4, 4,
            0, 0, 2, 1, 4, 2, 3,
            1, 0, 1, 4, 3, 4, 4
        ]
        return levels.enumerated().map { index, level in
            GitHubContributionDay(date: "sample-\(index)", count: level > 0 ? level * 2 : 0, level: level)
        }
    }
}
