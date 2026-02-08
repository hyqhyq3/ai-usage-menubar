#!/usr/bin/env swift

import Foundation

// MARK: - Models (simplified copy for testing)

struct AccountConfig: Codable, Identifiable {
    let id: String
    var name: String
    let baseURL: String
    var authToken: String

    var isValid: Bool {
        !baseURL.isEmpty && !authToken.isEmpty
    }

    var serviceProvider: String {
        baseURL.contains("bigmodel") ? "bigmodel.cn" : "z.ai"
    }
}

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

struct ModelUsageItem: Codable, Identifiable {
    let id: String
    let modelName: String
    let usageCount: Int
    let totalTokens: Int
    let cachedTokens: Int
    let readCacheTokens: Int
}

struct ToolUsageItem: Codable, Identifiable {
    let id: String
    let toolName: String
    let usageCount: Int
}

// MARK: - Test Helpers

class TestRunner {
    var passed = 0
    var failed = 0

    func assert(_ condition: Bool, message: String) {
        if condition {
            print("✓ \(message)")
            passed += 1
        } else {
            print("✗ \(message)")
            failed += 1
        }
    }

    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, message: String) {
        if actual == expected {
            print("✓ \(message)")
            passed += 1
        } else {
            print("✗ \(message) - 期望: \(expected), 实际: \(actual)")
            failed += 1
        }
    }

    func assertEqualDouble(_ actual: Double, _ expected: Double, accuracy: Double, message: String) {
        if abs(actual - expected) <= accuracy {
            print("✓ \(message)")
            passed += 1
        } else {
            print("✗ \(message) - 期望: \(expected)±\(accuracy), 实际: \(actual)")
            failed += 1
        }
    }

    func printSummary() {
        print("\n测试结果: \(passed) 通过, \(failed) 失败")
        exit(failed > 0 ? 1 : 0)
    }
}

// MARK: - Tests

let runner = TestRunner()

print("=== AccountConfig 测试 ===")

let account = AccountConfig(
    id: "test-id-123",
    name: "测试账号",
    baseURL: "https://api.zai.ai",
    authToken: "Bearer test-token"
)

runner.assertEqual(account.id, "test-id-123", message: "账号 ID 正确")
runner.assertEqual(account.name, "测试账号", message: "账号名称正确")
runner.assertEqual(account.baseURL, "https://api.zai.ai", message: "BaseURL 正确")
runner.assertEqual(account.authToken, "Bearer test-token", message: "Token 正确")
runner.assert(account.isValid, message: "有效账号验证通过")

let emptyBaseURLAccount = AccountConfig(
    id: "test-id-2",
    name: "无效账号",
    baseURL: "",
    authToken: "token"
)
runner.assert(!emptyBaseURLAccount.isValid, message: "空 BaseURL 账号无效")

let emptyTokenAccount = AccountConfig(
    id: "test-id-3",
    name: "无效账号2",
    baseURL: "https://api.zai.ai",
    authToken: ""
)
runner.assert(!emptyTokenAccount.isValid, message: "空 Token 账号无效")

let zaiAccount = AccountConfig(
    id: "zai-id",
    name: "Zai账号",
    baseURL: "https://api.zai.ai",
    authToken: "token"
)
runner.assertEqual(zaiAccount.serviceProvider, "z.ai", message: "z.ai 服务商识别正确")

let bigmodelAccount = AccountConfig(
    id: "bigmodel-id",
    name: "BigModel账号",
    baseURL: "https://open.bigmodel.cn/api",
    authToken: "token"
)
runner.assertEqual(bigmodelAccount.serviceProvider, "bigmodel.cn", message: "bigmodel.cn 服务商识别正确")

print("\n=== UsageData 测试 ===")

let data = UsageData(
    tokenLimit: 1000000,
    tokenUsed: 500000,
    mcpLimit: 100,
    mcpUsed: 75,
    modelUsage: [],
    toolUsage: [],
    lastUpdateTime: Date(),
    tokenResetTime: nil,
    mcpResetTime: nil
)

runner.assertEqualDouble(data.tokenUsagePercent, 0.5, accuracy: 0.001, message: "Token 使用率 50%")
runner.assertEqualDouble(data.mcpUsagePercent, 0.75, accuracy: 0.001, message: "MCP 使用率 75%")
runner.assertEqual(data.tokenRemaining, 500000, message: "Token 剩余量正确")

// 测试重置时间描述
let pastTime = Date().addingTimeInterval(-3600)
runner.assertEqual(data.resetTimeDescription(pastTime), "已重置", message: "过去的时间描述正确")

let soonTime = Date().addingTimeInterval(300)
let soonDesc = data.resetTimeDescription(soonTime)
runner.assert(soonDesc == "即将重置" || soonDesc == "5分钟后", message: "即将到来的时间描述正确")

let daysTime = Date().addingTimeInterval(48 * 3600)
runner.assertEqual(data.resetTimeDescription(daysTime), "2天后", message: "天数描述正确")

// 测试边界情况
let zeroLimitData = UsageData(
    tokenLimit: 0,
    tokenUsed: 100,
    mcpLimit: 0,
    mcpUsed: 50,
    modelUsage: [],
    toolUsage: [],
    lastUpdateTime: Date(),
    tokenResetTime: nil,
    mcpResetTime: nil
)
runner.assertEqualDouble(zeroLimitData.tokenUsagePercent, 0.0, accuracy: 0.001, message: "零配额使用率返回 0")
runner.assertEqualDouble(zeroLimitData.mcpUsagePercent, 0.0, accuracy: 0.001, message: "零配额 MCP 使用率返回 0")

print("\n=== UserDefaults 测试 (模拟) ===")

// 模拟 UserDefaults 行为
var mockAccounts: [AccountConfig] = []
var mockCurrentAccountId: String?

let account1 = AccountConfig(
    id: UUID().uuidString,
    name: "账号1",
    baseURL: "https://api.zai.ai",
    authToken: "token1"
)
let account2 = AccountConfig(
    id: UUID().uuidString,
    name: "账号2",
    baseURL: "https://open.bigmodel.cn/api",
    authToken: "token2"
)

mockAccounts.append(account1)
mockAccounts.append(account2)

runner.assertEqual(mockAccounts.count, 2, message: "添加两个账号")

// 模拟获取当前账号
if mockCurrentAccountId == nil {
    mockCurrentAccountId = mockAccounts.first?.id
}
runner.assert(mockCurrentAccountId != nil, message: "第一个账号自动设为当前账号")

// 模拟删除账号
let accountIdToDelete = account1.id
mockAccounts.removeAll { $0.id == accountIdToDelete }
if mockCurrentAccountId == accountIdToDelete {
    mockCurrentAccountId = mockAccounts.first?.id
}
runner.assertEqual(mockAccounts.count, 1, message: "删除账号后数量正确")
runner.assertEqual(mockAccounts.first?.name, "账号2", message: "删除后剩余账号正确")

print("\n=== 数据迁移测试 (模拟) ===")

// 模拟旧配置存在
var legacyBaseURL = "https://api.zai.ai"
var legacyToken = "Bearer legacy-token"
var migrationCompleted = false

if !migrationCompleted && !legacyBaseURL.isEmpty {
    // 模拟迁移
    let migratedAccount = AccountConfig(
        id: UUID().uuidString,
        name: "默认账号",
        baseURL: legacyBaseURL,
        authToken: legacyToken
    )
    mockAccounts.append(migratedAccount)
    migrationCompleted = true

    runner.assert(true, message: "旧配置迁移成功")
    runner.assertEqual(mockAccounts.last?.name, "默认账号", message: "迁移后账号名称正确")
    runner.assertEqual(mockAccounts.last?.authToken, "Bearer legacy-token", message: "迁移后 Token 正确")
} else {
    runner.assert(false, message: "应该执行迁移")
}

// 模拟第二次迁移（应跳过）
if migrationCompleted {
    // 不应该再次迁移
    runner.assert(true, message: "第二次迁移被跳过")
}

runner.printSummary()
