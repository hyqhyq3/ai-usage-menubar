//
//  Models.swift
//  menubar-min
//
//  Created on 2025-02-02.
//

import Foundation

// MARK: - API 响应模型 (zai.ai 格式)

/// 模型使用情况响应
struct ModelUsageResponse: Codable {
    let data: [ModelUsageItem]
}

struct ModelUsageItem: Codable, Identifiable {
    let id: String
    let modelName: String
    let usageCount: Int
    let totalTokens: Int
    let cachedTokens: Int
    let readCacheTokens: Int

    enum CodingKeys: String, CodingKey {
        case id
        case modelName = "model_name"
        case usageCount = "usage_count"
        case totalTokens = "total_tokens"
        case cachedTokens = "cached_tokens"
        case readCacheTokens = "read_cache_tokens"
    }
}

/// 工具使用情况响应
struct ToolUsageResponse: Codable {
    let data: [ToolUsageItem]
}

struct ToolUsageItem: Codable, Identifiable {
    let id: String
    let toolName: String
    let usageCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case toolName = "tool_name"
        case usageCount = "usage_count"
    }
}

/// 配额限制响应
struct QuotaLimitResponse: Codable {
    let data: QuotaLimitData
}

struct QuotaLimitData: Codable {
    let tokenLimit: Int
    let tokenUsed: Int
    let mcpLimit: Int
    let mcpUsed: Int

    enum CodingKeys: String, CodingKey {
        case tokenLimit = "token_limit"
        case tokenUsed = "token_used"
        case mcpLimit = "mcp_limit"
        case mcpUsed = "mcp_used"
    }
}

// MARK: - API 响应模型 (bigmodel.cn 格式)

/// BigModel API 通用响应
struct BigModelResponse<T: Decodable>: Decodable {
    let code: Int
    let msg: String
    let data: T
    let success: Bool
}

/// BigModel 配额限制
struct BigModelQuotaData: Codable {
    let limits: [BigModelLimitItem]
}

struct BigModelLimitItem: Codable {
    let type: String
    let unit: Int?
    let number: Int?
    let usage: Int
    let currentValue: Int
    let remaining: Int?
    let percentage: Int
    let usageDetails: [BigModelUsageDetail]?
    let nextResetTime: Int64?

    enum CodingKeys: String, CodingKey {
        case type, unit, number, usage, currentValue, remaining, percentage
        case usageDetails
        case nextResetTime
    }
}

struct BigModelUsageDetail: Codable {
    let modelCode: String
    let usage: Int

    enum CodingKeys: String, CodingKey {
        case modelCode
        case usage
    }
}

/// BigModel 模型使用情况
struct BigModelModelUsageData: Codable {
    let xTime: [String]
    let modelCallCount: [Int?]
    let tokensUsage: [Int?]
    let totalUsage: BigModelTotalUsage

    enum CodingKeys: String, CodingKey {
        case xTime = "x_time"
        case modelCallCount
        case tokensUsage
        case totalUsage
    }
}

struct BigModelTotalUsage: Codable {
    let totalModelCallCount: Int
    let totalTokensUsage: Int

    enum CodingKeys: String, CodingKey {
        case totalModelCallCount
        case totalTokensUsage
    }
}

// MARK: - Moonshot API 响应模型

/// Moonshot 余额响应
struct MoonshotBalanceResponse: Codable {
    let code: Int
    let data: MoonshotBalanceData
    let scode: String
    let status: Bool
}

struct MoonshotBalanceData: Codable {
    let availableBalance: Double
    let voucherBalance: Double
    let cashBalance: Double

    enum CodingKeys: String, CodingKey {
        case availableBalance = "available_balance"
        case voucherBalance = "voucher_balance"
        case cashBalance = "cash_balance"
    }
}

// MARK: - DeepSeek API 响应模型

/// DeepSeek 余额响应
struct DeepSeekBalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [DeepSeekBalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

struct DeepSeekBalanceInfo: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

// MARK: - OpenRouter API 响应模型

/// OpenRouter 余额响应
struct OpenRouterBalanceResponse: Codable {
    let data: OpenRouterBalanceData
}

struct OpenRouterBalanceData: Codable {
    let label: String
    let limit: Double?
    let limitRemaining: Double?
    let usage: Double
    let usageDaily: Double
    let usageWeekly: Double
    let usageMonthly: Double
    let isFreeTier: Bool

    enum CodingKeys: String, CodingKey {
        case label
        case limit
        case limitRemaining = "limit_remaining"
        case usage
        case usageDaily = "usage_daily"
        case usageWeekly = "usage_weekly"
        case usageMonthly = "usage_monthly"
        case isFreeTier = "is_free_tier"
    }
}

// MARK: - 应用数据模型

/// 用量数据汇总
struct UsageData {
    let tokenLimit: Int
    let tokenUsed: Int
    let mcpLimit: Int
    let mcpUsed: Int
    let modelUsage: [ModelUsageItem]
    let toolUsage: [ToolUsageItem]
    let lastUpdateTime: Date
    let tokenResetTime: Date?
    let mcpResetTime: Date?

    // Moonshot 余额信息（可选）
    let availableBalance: Double?
    let cashBalance: Double?
    let voucherBalance: Double?

    var isBalanceBased: Bool {
        return availableBalance != nil
    }

    var tokenUsagePercent: Double {
        guard tokenLimit > 0 else { return 0 }
        return Double(tokenUsed) / Double(tokenLimit)
    }

    var mcpUsagePercent: Double {
        guard mcpLimit > 0 else { return 0 }
        return Double(mcpUsed) / Double(mcpLimit)
    }

    var tokenRemaining: Int {
        max(0, tokenLimit - tokenUsed)
    }

    var mcpRemaining: Int {
        max(0, mcpLimit - mcpUsed)
    }

    /// 格式化余额显示
    func formatBalance() -> String? {
        guard let balance = availableBalance else { return nil }
        return String(format: "¥%.2f", balance)
    }

    /// 格式化重置时间显示
    func formatResetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// 获取重置时间的友好描述
    func resetTimeDescription(_ date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval <= 0 {
            return "已重置"
        }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "\(days)天后"
        } else if hours > 0 {
            return "\(hours)小时后"
        } else if minutes > 0 {
            return "\(minutes)分钟后"
        } else {
            return "即将重置"
        }
    }
}

/// API 配置模型
struct APIConfig: Codable {
    var baseURL: String
    var authToken: String

    var isValid: Bool {
        !baseURL.isEmpty && !authToken.isEmpty
    }
}

/// 账号配置模型
struct AccountConfig: Codable, Identifiable {
    let id: String
    var name: String
    let baseURL: String
    var authToken: String

    var isValid: Bool {
        !baseURL.isEmpty && !authToken.isEmpty
    }

    var serviceProvider: String {
        if baseURL.contains("bigmodel") {
            return "bigmodel.cn"
        } else if baseURL.contains("moonshot") {
            return "moonshot.cn"
        } else if baseURL.contains("deepseek") {
            return "deepseek.com"
        } else if baseURL.contains("openrouter") {
            return "openrouter.ai"
        } else {
            return "z.ai"
        }
    }
}

// MARK: - 默认配置

extension APIConfig {
    static let `default` = APIConfig(
        baseURL: "https://api.zai.ai",
        authToken: ""
    )

    static let zaiURL = "https://api.zai.ai"
    static let zhipuURL = "https://open.bigmodel.cn/api"
}

// MARK: - 错误类型

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unauthorized:
            return "未授权，请检查 API Token"
        case .serverError(let statusCode):
            return "服务器错误 (\(statusCode))"
        }
    }
}

// MARK: - UserDefaults 扩展

extension UserDefaults {
    // MARK: - 旧版配置（兼容性）

    private enum Keys {
        static let baseURL = "ANTHROPIC_BASE_URL"
        static let authToken = "ANTHROPIC_AUTH_TOKEN"
    }

    func getAPIConfig() -> (baseURL: String, authToken: String)? {
        guard let baseURL = string(forKey: Keys.baseURL),
              !baseURL.isEmpty,
              let authToken = string(forKey: Keys.authToken),
              !authToken.isEmpty else {
            return nil
        }
        return (baseURL, authToken)
    }

    func setAPIConfig(baseURL: String, authToken: String) {
        set(baseURL, forKey: Keys.baseURL)
        set(authToken, forKey: Keys.authToken)
    }

    func clearAPIConfig() {
        removeObject(forKey: Keys.baseURL)
        removeObject(forKey: Keys.authToken)
    }

    // MARK: - 多账号配置

    private enum AccountKeys {
        static let accounts = "GLM_ACCOUNTS"
        static let currentAccountId = "GLM_CURRENT_ACCOUNT_ID"
        static let migrationCompleted = "GLM_MIGRATION_COMPLETED"
    }

    /// 迁移旧版配置到新账号系统
    func migrateLegacyConfig() {
        // 检查是否已完成迁移
        if bool(forKey: AccountKeys.migrationCompleted) {
            return
        }

        // 检查是否已有新格式数据
        guard getAccounts().isEmpty else {
            // 已有新数据，标记迁移完成
            set(true, forKey: AccountKeys.migrationCompleted)
            return
        }

        // 检查是否有旧配置
        guard let baseURL = string(forKey: Keys.baseURL),
              let authToken = string(forKey: Keys.authToken),
              !baseURL.isEmpty, !authToken.isEmpty else {
            // 没有旧配置，标记迁移完成
            set(true, forKey: AccountKeys.migrationCompleted)
            return
        }

        // 迁移到新格式
        let account = AccountConfig(
            id: UUID().uuidString,
            name: "默认账号",
            baseURL: baseURL,
            authToken: authToken
        )
        addAccount(account)

        // 清理旧配置
        removeObject(forKey: Keys.baseURL)
        removeObject(forKey: Keys.authToken)

        // 标记迁移完成
        set(true, forKey: AccountKeys.migrationCompleted)
    }

    /// 获取所有账号
    func getAccounts() -> [AccountConfig] {
        guard let data = data(forKey: AccountKeys.accounts),
              let accounts = try? JSONDecoder().decode([AccountConfig].self, from: data) else {
            return []
        }
        return accounts
    }

    /// 保存账号列表
    func saveAccounts(_ accounts: [AccountConfig]) {
        if let data = try? JSONEncoder().encode(accounts) {
            set(data, forKey: AccountKeys.accounts)
        }
    }

    /// 获取当前激活账号
    func getCurrentAccount() -> AccountConfig? {
        let accounts = getAccounts()
        guard let currentId = string(forKey: AccountKeys.currentAccountId) else {
            return accounts.first
        }
        return accounts.first { $0.id == currentId } ?? accounts.first
    }

    /// 设置当前激活账号
    func setCurrentAccount(_ accountId: String) {
        set(accountId, forKey: AccountKeys.currentAccountId)
    }

    /// 添加账号
    func addAccount(_ account: AccountConfig) {
        var accounts = getAccounts()
        accounts.append(account)
        saveAccounts(accounts)
        // 如果是第一个账号，自动设为当前账号
        if accounts.count == 1 {
            setCurrentAccount(account.id)
        }
    }

    /// 更新账号
    func updateAccount(_ account: AccountConfig) {
        var accounts = getAccounts()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts(accounts)
        }
    }

    /// 删除账号
    func removeAccount(_ accountId: String) {
        var accounts = getAccounts()
        accounts.removeAll { $0.id == accountId }
        saveAccounts(accounts)

        // 如果删除的是当前账号，切换到第一个可用账号
        if let currentId = string(forKey: AccountKeys.currentAccountId),
           currentId == accountId, let firstAccount = accounts.first {
            setCurrentAccount(firstAccount.id)
        }
    }

    /// 检查是否有任何有效账号
    func hasAnyValidAccount() -> Bool {
        return !getAccounts().isEmpty
    }
}
