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
        case moonshot
        case deepseek
        case openrouter
    }

    // MARK: - 初始化

    init() {
        loadCurrentAccount()
    }

    // MARK: - 账号管理

    func loadCurrentAccount() {
        currentAccount = UserDefaults.standard.getCurrentAccount()
        if let account = currentAccount {
            print("APIService: Loaded account '\(account.name)' (\(account.serviceProvider))")
        } else {
            print("APIService: No current account found")
        }
    }

    func updateAccount(_ account: AccountConfig) {
        UserDefaults.standard.updateAccount(account)
        if account.id == currentAccount?.id {
            currentAccount = account
        }
    }

    func switchAccount(_ accountId: String) {
        print("APIService: Switching to account ID: \(accountId)")
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
            print("API: Invalid account or no current account")
            throw APIError.invalidURL
        }

        print("API: Fetching usage for account '\(account.name)' from \(account.baseURL)")

        // 检测 API 类型
        let apiType: APIType
        if account.baseURL.contains("bigmodel") {
            apiType = .bigmodel
        } else if account.baseURL.contains("moonshot") {
            apiType = .moonshot
        } else if account.baseURL.contains("deepseek") {
            apiType = .deepseek
        } else if account.baseURL.contains("openrouter") {
            apiType = .openrouter
        } else {
            apiType = .zai
        }

        print("API: Detected type: \(apiType)")

        switch apiType {
        case .bigmodel:
            return try await fetchBigModelUsageData(account: account)
        case .moonshot:
            return try await fetchMoonshotBalanceData(account: account)
        case .deepseek:
            return try await fetchDeepSeekBalanceData(account: account)
        case .openrouter:
            return try await fetchOpenRouterBalanceData(account: account)
        case .zai:
            return try await fetchZaiUsageData(account: account)
        }
    }

    // MARK: - BigModel API

    private func fetchBigModelUsageData(account: AccountConfig) async throws -> UsageData {
        // 并发请求配额和模型使用情况
        async let quotaLimit = fetchBigModelQuotaLimit(account: account)
        async let modelUsage = fetchBigModelModelUsage(account: account)

        let (quotaData, modelUsageData) = try await (quotaLimit, modelUsage)

        // 从 quota 数据中提取信息
        var tokenLimit = 0
        var tokenUsed = 0
        var mcpLimit = 0
        var mcpUsed = 0
        var tokenResetTime: Date?
        var mcpResetTime: Date?

        for limit in quotaData.limits {
            if limit.type == "TOKENS_LIMIT" {
                // 新 API 格式：usage 和 currentValue 不再返回
                // 需要从模型使用 API 获取已用量，用 percentage 反推总限制
                if limit.percentage > 0 {
                    // percentage 是过去 24 小时的使用占比
                    // 总限制 = 24小时使用量 / (percentage / 100)
                    tokenUsed = modelUsageData.totalUsage.totalTokensUsage
                    tokenLimit = Int(Double(tokenUsed) * 100.0 / Double(limit.percentage))
                }

                // nextResetTime 是毫秒级时间戳
                if let resetTimestamp = limit.nextResetTime {
                    tokenResetTime = Date(timeIntervalSince1970: TimeInterval(resetTimestamp) / 1000)
                }

                print("BigModel TOKENS_LIMIT: percentage=\(limit.percentage)%, tokenUsed=\(tokenUsed), tokenLimit=\(tokenLimit)")
            } else if limit.type == "TIME_LIMIT" {
                mcpLimit = limit.usage ?? 0
                mcpUsed = limit.currentValue ?? 0
                if let resetTimestamp = limit.nextResetTime {
                    mcpResetTime = Date(timeIntervalSince1970: TimeInterval(resetTimestamp) / 1000)
                }
            }
        }

        // 创建模型使用情况列表
        var modelUsageItems: [ModelUsageItem] = []

        // 尝试从 TIME_LIMIT 的 usageDetails 中获取工具使用情况
        if let timeLimit = quotaData.limits.first(where: { $0.type == "TIME_LIMIT" }),
           let details = timeLimit.usageDetails, !details.isEmpty {
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
                modelName: "24H总用量",
                usageCount: modelUsageData.totalUsage.totalModelCallCount,
                totalTokens: modelUsageData.totalUsage.totalTokensUsage,
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
            mcpResetTime: mcpResetTime,
            availableBalance: nil,
            cashBalance: nil,
            voucherBalance: nil
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
            mcpResetTime: nil,
            availableBalance: nil,
            cashBalance: nil,
            voucherBalance: nil
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

    // MARK: - Moonshot API

    private func fetchMoonshotBalanceData(account: AccountConfig) async throws -> UsageData {
        guard let url = URL(string: account.baseURL + "/users/me/balance") else {
            throw APIError.invalidURL
        }

        // 确保 token 有 Bearer 前缀
        let authToken = account.authToken.hasPrefix("Bearer ")
            ? account.authToken
            : "Bearer " + account.authToken

        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(MoonshotBalanceResponse.self, from: data)
            if !result.status {
                throw APIError.serverError(statusCode: result.code)
            }
            // 将余额数据转换为 UsageData 格式
            return UsageData(
                tokenLimit: 0,
                tokenUsed: 0,
                mcpLimit: 0,
                mcpUsed: 0,
                modelUsage: [],
                toolUsage: [],
                lastUpdateTime: Date(),
                tokenResetTime: nil,
                mcpResetTime: nil,
                availableBalance: result.data.availableBalance,
                cashBalance: result.data.cashBalance,
                voucherBalance: result.data.voucherBalance
            )
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - DeepSeek API

    private func fetchDeepSeekBalanceData(account: AccountConfig) async throws -> UsageData {
        guard let url = URL(string: account.baseURL + "/user/balance") else {
            print("DeepSeek: Invalid URL - \(account.baseURL + "/user/balance")")
            throw APIError.invalidURL
        }

        // 确保 token 有 Bearer 前缀
        let authToken = account.authToken.hasPrefix("Bearer ")
            ? account.authToken
            : "Bearer " + account.authToken

        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("DeepSeek: Fetching from \(url.absoluteString)")
        print("DeepSeek: Authorization header: \(account.authToken.prefix(20))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("DeepSeek: Invalid response")
            throw APIError.invalidResponse
        }

        print("DeepSeek: Status code \(httpResponse.statusCode)")

        // 打印响应内容用于调试
        if let responseString = String(data: data, encoding: .utf8) {
            print("DeepSeek: Response - \(responseString.prefix(500))")
        }

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
            guard let balanceInfo = result.balanceInfos.first else {
                throw APIError.decodingError(NSError(domain: "DeepSeekAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No balance info found"]))
            }

            // 解析余额字符串为 Double
            let totalBalance = Double(balanceInfo.totalBalance) ?? 0.0
            let grantedBalance = Double(balanceInfo.grantedBalance) ?? 0.0
            let toppedUpBalance = Double(balanceInfo.toppedUpBalance) ?? 0.0

            print("DeepSeek: Balance - Total: ¥\(totalBalance), Cash: ¥\(toppedUpBalance), Voucher: ¥\(grantedBalance)")

            // 将余额数据转换为 UsageData 格式
            return UsageData(
                tokenLimit: 0,
                tokenUsed: 0,
                mcpLimit: 0,
                mcpUsed: 0,
                modelUsage: [],
                toolUsage: [],
                lastUpdateTime: Date(),
                tokenResetTime: nil,
                mcpResetTime: nil,
                availableBalance: totalBalance,
                cashBalance: toppedUpBalance,
                voucherBalance: grantedBalance
            )
        case 401:
            print("DeepSeek: Unauthorized - check your API token")
            throw APIError.unauthorized
        default:
            print("DeepSeek: Server error \(httpResponse.statusCode)")
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - OpenRouter API

    private func fetchOpenRouterBalanceData(account: AccountConfig) async throws -> UsageData {
        guard let url = URL(string: account.baseURL + "/api/v1/auth/key") else {
            print("OpenRouter: Invalid URL - \(account.baseURL + "/api/v1/auth/key")")
            throw APIError.invalidURL
        }

        // 确保 token 有 Bearer 前缀
        let authToken = account.authToken.hasPrefix("Bearer ")
            ? account.authToken
            : "Bearer " + account.authToken

        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("OpenRouter: Fetching from \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("OpenRouter: Invalid response")
            throw APIError.invalidResponse
        }

        print("OpenRouter: Status code \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            let result = try JSONDecoder().decode(OpenRouterBalanceResponse.self, from: data)
            let balanceData = result.data

            print("OpenRouter: Usage - $\(balanceData.usage)")

            // OpenRouter 显示已使用额度（美元）
            // 如果 limit 为 null，表示无限额度，只显示已使用
            // 如果 limit 有值，可以显示剩余额度
            let availableBalance: Double?
            if let limit = balanceData.limit, let remaining = balanceData.limitRemaining {
                availableBalance = remaining
            } else {
                availableBalance = nil
            }

            // 将使用数据转换为 UsageData 格式
            return UsageData(
                tokenLimit: 0,
                tokenUsed: 0,
                mcpLimit: 0,
                mcpUsed: 0,
                modelUsage: [],
                toolUsage: [],
                lastUpdateTime: Date(),
                tokenResetTime: nil,
                mcpResetTime: nil,
                availableBalance: availableBalance,
                cashBalance: nil,
                voucherBalance: nil
            )
        case 401:
            print("OpenRouter: Unauthorized - check your API token")
            throw APIError.unauthorized
        default:
            print("OpenRouter: Server error \(httpResponse.statusCode)")
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}
