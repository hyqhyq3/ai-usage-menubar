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
}
