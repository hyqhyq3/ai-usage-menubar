//
//  APIService.swift
//  menubar-min
//
//  Created on 2025-02-02.
//

import Foundation

/// API 服务类，负责与 GLM Coding Plan API 交互
class APIService {
    private var currentAccount: AccountConfig?

    // MARK: - API 类型

    private enum APIType {
        case zai
        case bigmodel
    }

    // MARK: - 初始化

    init() {
        loadCurrentAccount()
    }

    // MARK: - 账号管理

    func loadCurrentAccount() {
        currentAccount = UserDefaults.standard.getCurrentAccount()
    }

    func updateAccount(_ account: AccountConfig) {
        UserDefaults.standard.updateAccount(account)
        if account.id == currentAccount?.id {
            currentAccount = account
        }
    }

    func switchAccount(_ accountId: String) {
        UserDefaults.standard.setCurrentAccount(accountId)
        loadCurrentAccount()
    }

    func getCurrentAccountName() -> String? {
        return currentAccount?.name
    }

    func getCurrentAccountId() -> String? {
        return currentAccount?.id
    }

    func hasConfig() -> Bool {
        currentAccount?.isValid ?? false
    }

    // MARK: - 兼容旧版配置方法

    func loadConfig() {
        // 迁移旧配置并加载当前账号
        UserDefaults.standard.migrateLegacyConfig()
        loadCurrentAccount()
    }

    func updateConfig(baseURL: String, authToken: String) {
        // 为旧版兼容保留，实际上更新当前账号的 Token
        // baseURL 变更不支持，需要通过账号管理界面修改服务商
        if var account = currentAccount {
            account.authToken = authToken
            UserDefaults.standard.updateAccount(account)
            currentAccount = account
        }
    }

    // MARK: - API 请求

    /// 刷新所有用量数据
    func refreshUsageData() async throws -> UsageData {
        guard let account = currentAccount, account.isValid else {
            throw APIError.invalidURL
        }

        // 检测 API 类型
        let apiType: APIType = account.baseURL.contains("bigmodel") ? .bigmodel : .zai

        switch apiType {
        case .bigmodel:
            return try await fetchBigModelUsageData(account: account)
        case .zai:
            return try await fetchZaiUsageData(account: account)
        }
    }

    // MARK: - BigModel API

    private func fetchBigModelUsageData(account: AccountConfig) async throws -> UsageData {
        // 并发请求配额和模型使用情况
        async let quotaLimit = fetchBigModelQuotaLimit(account: account)
        async let modelUsage = fetchBigModelModelUsage(account: account)

        let (quotaData, _) = try await (quotaLimit, modelUsage)

        // 从 quota 数据中提取信息
        var tokenLimit = 0
        var tokenUsed = 0
        var mcpLimit = 0
        var mcpUsed = 0
        var tokenResetTime: Date?
        var mcpResetTime: Date?

        for limit in quotaData.limits {
            if limit.type == "TOKENS_LIMIT" {
                tokenLimit = limit.usage
                tokenUsed = limit.currentValue
                // nextResetTime 是毫秒级时间戳
                if let resetTimestamp = limit.nextResetTime {
                    tokenResetTime = Date(timeIntervalSince1970: TimeInterval(resetTimestamp) / 1000)
                }
            } else if limit.type == "TIME_LIMIT" {
                mcpLimit = limit.usage
                mcpUsed = limit.currentValue
                if let resetTimestamp = limit.nextResetTime {
                    mcpResetTime = Date(timeIntervalSince1970: TimeInterval(resetTimestamp) / 1000)
                }
            }
        }

        // 创建模型使用情况列表
        var modelUsageItems: [ModelUsageItem] = []

        // 从 usageDetails 中提取模型使用情况
        if let tokensLimit = quotaData.limits.first(where: { $0.type == "TOKENS_LIMIT" }),
           let details = tokensLimit.usageDetails, !details.isEmpty {
            for detail in details.prefix(3) {
                modelUsageItems.append(ModelUsageItem(
                    id: UUID().uuidString,
                    modelName: detail.modelCode,
                    usageCount: detail.usage,
                    totalTokens: detail.usage * 1000, // 估算
                    cachedTokens: 0,
                    readCacheTokens: 0
                ))
            }
        }

        // 如果没有详细数据，添加一个总计项
        if modelUsageItems.isEmpty {
            modelUsageItems.append(ModelUsageItem(
                id: UUID().uuidString,
                modelName: "总用量",
                usageCount: 1,
                totalTokens: tokenUsed,
                cachedTokens: 0,
                readCacheTokens: 0
            ))
        }

        return UsageData(
            tokenLimit: tokenLimit,
            tokenUsed: tokenUsed,
            mcpLimit: mcpLimit,
            mcpUsed: mcpUsed,
            modelUsage: modelUsageItems,
            toolUsage: [],
            lastUpdateTime: Date(),
            tokenResetTime: tokenResetTime,
            mcpResetTime: mcpResetTime
        )
    }

    private func fetchBigModelQuotaLimit(account: AccountConfig) async throws -> BigModelQuotaData {
        guard let url = URL(string: account.baseURL + "/monitor/usage/quota/limit") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(account.authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(BigModelResponse<BigModelQuotaData>.self, from: data)
            if !result.success {
                throw APIError.serverError(statusCode: result.code)
            }
            return result.data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func fetchBigModelModelUsage(account: AccountConfig) async throws -> BigModelModelUsageData {
        // 计算时间窗口（过去 24 小时）
        let now = Date()
        let startDate = now.addingTimeInterval(-24 * 60 * 60)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let startTime = dateFormatter.string(from: startDate)
        let endTime = dateFormatter.string(from: now)

        var components = URLComponents(string: account.baseURL + "/monitor/usage/model-usage")
        components?.queryItems = [
            URLQueryItem(name: "startTime", value: startTime),
            URLQueryItem(name: "endTime", value: endTime)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(account.authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(BigModelResponse<BigModelModelUsageData>.self, from: data)
            if !result.success {
                throw APIError.serverError(statusCode: result.code)
            }
            return result.data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Zai API

    private func fetchZaiUsageData(account: AccountConfig) async throws -> UsageData {
        // 计算时间窗口（过去 24 小时）
        let now = Date()
        let startDate = now.addingTimeInterval(-24 * 60 * 60)
        let endDate = now

        let dateFormatter = ISO8601DateFormatter()
        let startTime = dateFormatter.string(from: startDate)
        let endTime = dateFormatter.string(from: endDate)

        // 并发请求三个端点
        async let modelUsage = fetchZaiModelUsage(startTime: startTime, endTime: endTime, account: account)
        async let toolUsage = fetchZaiToolUsage(startTime: startTime, endTime: endTime, account: account)
        async let quotaLimit = fetchZaiQuotaLimit(account: account)

        // 等待所有请求完成
        let (modelData, toolData, quotaData) = try await (modelUsage, toolUsage, quotaLimit)

        // 组合数据
        return UsageData(
            tokenLimit: quotaData.tokenLimit,
            tokenUsed: quotaData.tokenUsed,
            mcpLimit: quotaData.mcpLimit,
            mcpUsed: quotaData.mcpUsed,
            modelUsage: modelData,
            toolUsage: toolData,
            lastUpdateTime: now,
            tokenResetTime: nil,
            mcpResetTime: nil
        )
    }

    private func fetchZaiModelUsage(startTime: String, endTime: String, account: AccountConfig) async throws -> [ModelUsageItem] {
        var components = URLComponents(string: account.baseURL + "/api/monitor/usage/model-usage")
        components?.queryItems = [
            URLQueryItem(name: "startTime", value: startTime),
            URLQueryItem(name: "endTime", value: endTime)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(account.authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(ModelUsageResponse.self, from: data)
            return result.data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func fetchZaiToolUsage(startTime: String, endTime: String, account: AccountConfig) async throws -> [ToolUsageItem] {
        var components = URLComponents(string: account.baseURL + "/api/monitor/usage/tool-usage")
        components?.queryItems = [
            URLQueryItem(name: "startTime", value: startTime),
            URLQueryItem(name: "endTime", value: endTime)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(account.authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(ToolUsageResponse.self, from: data)
            return result.data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func fetchZaiQuotaLimit(account: AccountConfig) async throws -> QuotaLimitData {
        guard let url = URL(string: account.baseURL + "/api/monitor/usage/quota/limit") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(account.authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(QuotaLimitResponse.self, from: data)
            return result.data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}
