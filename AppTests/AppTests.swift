//
//  AppTests.swift
//  menubar-min Tests
//
//  Created on 2025-02-08.
//

import XCTest
@testable import glm_usage

// MARK: - AccountConfig Tests

final class AccountConfigTests: XCTestCase {

    func testAccountConfigInitialization() {
        let account = AccountConfig(
            id: "test-id-123",
            name: "测试账号",
            baseURL: "https://api.zai.ai",
            authToken: "Bearer test-token"
        )

        XCTAssertEqual(account.id, "test-id-123")
        XCTAssertEqual(account.name, "测试账号")
        XCTAssertEqual(account.baseURL, "https://api.zai.ai")
        XCTAssertEqual(account.authToken, "Bearer test-token")
    }

    func testAccountConfigIsValid() {
        let validAccount = AccountConfig(
            id: "test-id",
            name: "有效账号",
            baseURL: "https://api.zai.ai",
            authToken: "Bearer token"
        )
        XCTAssertTrue(validAccount.isValid)

        let emptyBaseURL = AccountConfig(
            id: "test-id-2",
            name: "无效账号1",
            baseURL: "",
            authToken: "Bearer token"
        )
        XCTAssertFalse(emptyBaseURL.isValid)

        let emptyToken = AccountConfig(
            id: "test-id-3",
            name: "无效账号2",
            baseURL: "https://api.zai.ai",
            authToken: ""
        )
        XCTAssertFalse(emptyToken.isValid)
    }

    func testServiceProviderDetection() {
        let zaiAccount = AccountConfig(
            id: "zai-id",
            name: "Zai账号",
            baseURL: "https://api.zai.ai",
            authToken: "token"
        )
        XCTAssertEqual(zaiAccount.serviceProvider, "z.ai")

        let bigmodelAccount = AccountConfig(
            id: "bigmodel-id",
            name: "BigModel账号",
            baseURL: "https://open.bigmodel.cn/api",
            authToken: "token"
        )
        XCTAssertEqual(bigmodelAccount.serviceProvider, "bigmodel.cn")
    }
}

// MARK: - UserDefaults Account Management Tests

final class UserDefaultsAccountTests: XCTestCase {

    var testUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        // 创建一个独立的测试 UserDefaults
        testUserDefaults = UserDefaults(suiteName: "com.glm-usage.test")!
        testUserDefaults.removePersistentDomain(forName: "com.glm-usage.test")
    }

    override func tearDown() {
        // 清理测试数据
        testUserDefaults.removePersistentDomain(forName: "com.glm-usage.test")
        super.tearDown()
    }

    func testAddAndGetAccounts() {
        // 准备测试数据
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

        // 使用 Category/Extension 添加方法到测试 UserDefaults
        testUserDefaults.addAccount(account1)
        testUserDefaults.addAccount(account2)

        // 验证
        let accounts = testUserDefaults.getAccounts()
        XCTAssertEqual(accounts.count, 2)
        XCTAssertEqual(accounts[0].name, "账号1")
        XCTAssertEqual(accounts[1].name, "账号2")
    }

    func testUpdateAccount() {
        let account = AccountConfig(
            id: "test-id",
            name: "原始名称",
            baseURL: "https://api.zai.ai",
            authToken: "original-token"
        )

        testUserDefaults.addAccount(account)

        // 更新账号
        let updatedAccount = AccountConfig(
            id: "test-id",
            name: "更新后的名称",
            baseURL: "https://api.zai.ai",
            authToken: "new-token"
        )
        testUserDefaults.updateAccount(updatedAccount)

        // 验证
        let accounts = testUserDefaults.getAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].name, "更新后的名称")
        XCTAssertEqual(accounts[0].authToken, "new-token")
    }

    func testRemoveAccount() {
        let account1 = AccountConfig(
            id: "id-1",
            name: "账号1",
            baseURL: "https://api.zai.ai",
            authToken: "token1"
        )
        let account2 = AccountConfig(
            id: "id-2",
            name: "账号2",
            baseURL: "https://open.bigmodel.cn/api",
            authToken: "token2"
        )

        testUserDefaults.addAccount(account1)
        testUserDefaults.addAccount(account2)

        // 删除第一个账号
        testUserDefaults.removeAccount("id-1")

        // 验证
        let accounts = testUserDefaults.getAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].id, "id-2")
    }

    func testCurrentAccountManagement() {
        let account1 = AccountConfig(
            id: "id-1",
            name: "账号1",
            baseURL: "https://api.zai.ai",
            authToken: "token1"
        )
        let account2 = AccountConfig(
            id: "id-2",
            name: "账号2",
            baseURL: "https://open.bigmodel.cn/api",
            authToken: "token2"
        )

        testUserDefaults.addAccount(account1)
        testUserDefaults.addAccount(account2)

        // 第一个账号应该自动设为当前账号
        XCTAssertEqual(testUserDefaults.getCurrentAccount()?.id, "id-1")

        // 切换到第二个账号
        testUserDefaults.setCurrentAccount("id-2")
        XCTAssertEqual(testUserDefaults.getCurrentAccount()?.id, "id-2")
    }

    func testDeleteCurrentAccountAutoSwitch() {
        let account1 = AccountConfig(
            id: "id-1",
            name: "账号1",
            baseURL: "https://api.zai.ai",
            authToken: "token1"
        )
        let account2 = AccountConfig(
            id: "id-2",
            name: "账号2",
            baseURL: "https://open.bigmodel.cn/api",
            authToken: "token2"
        )
        let account3 = AccountConfig(
            id: "id-3",
            name: "账号3",
            baseURL: "https://api.zai.ai",
            authToken: "token3"
        )

        testUserDefaults.addAccount(account1)
        testUserDefaults.addAccount(account2)
        testUserDefaults.addAccount(account3)

        // 设置当前账号为 account2
        testUserDefaults.setCurrentAccount("id-2")
        XCTAssertEqual(testUserDefaults.getCurrentAccount()?.id, "id-2")

        // 删除当前账号
        testUserDefaults.removeAccount("id-2")

        // 应该自动切换到第一个可用账号 (account1)
        XCTAssertEqual(testUserDefaults.getCurrentAccount()?.id, "id-1")
    }

    func testHasAnyValidAccount() {
        // 初始状态应该没有账号
        XCTAssertFalse(testUserDefaults.hasAnyValidAccount())

        // 添加账号后应该返回 true
        let account = AccountConfig(
            id: "test-id",
            name: "测试账号",
            baseURL: "https://api.zai.ai",
            authToken: "token"
        )
        testUserDefaults.addAccount(account)
        XCTAssertTrue(testUserDefaults.hasAnyValidAccount())
    }
}

// MARK: - Legacy Migration Tests

final class LegacyMigrationTests: XCTestCase {

    var testUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: "com.glm-usage.migration-test")!
        testUserDefaults.removePersistentDomain(forName: "com.glm-usage.migration-test")
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "com.glm-usage.migration-test")
        super.tearDown()
    }

    func testMigrationFromLegacyConfig() {
        // 设置旧版配置
        testUserDefaults.set("https://api.zai.ai", forKey: "ANTHROPIC_BASE_URL")
        testUserDefaults.set("Bearer legacy-token", forKey: "ANTHROPIC_AUTH_TOKEN")

        // 执行迁移
        testUserDefaults.migrateLegacyConfig()

        // 验证新格式
        let accounts = testUserDefaults.getAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].name, "默认账号")
        XCTAssertEqual(accounts[0].baseURL, "https://api.zai.ai")
        XCTAssertEqual(accounts[0].authToken, "Bearer legacy-token")

        // 验证旧配置已清理
        XCTAssertNil(testUserDefaults.string(forKey: "ANTHROPIC_BASE_URL"))
        XCTAssertNil(testUserDefaults.string(forKey: "ANTHROPIC_AUTH_TOKEN"))

        // 验证迁移标记
        XCTAssertTrue(testUserDefaults.bool(forKey: "GLM_MIGRATION_COMPLETED"))
    }

    func testMigrationDoesNotRunTwice() {
        // 设置旧版配置
        testUserDefaults.set("https://api.zai.ai", forKey: "ANTHROPIC_BASE_URL")
        testUserDefaults.set("Bearer token", forKey: "ANTHROPIC_AUTH_TOKEN")

        // 第一次迁移
        testUserDefaults.migrateLegacyConfig()
        let accountsAfterFirst = testUserDefaults.getAccounts()

        // 手动添加一些新数据
        let newAccount = AccountConfig(
            id: UUID().uuidString,
            name: "新账号",
            baseURL: "https://open.bigmodel.cn/api",
            authToken: "new-token"
        )
        testUserDefaults.addAccount(newAccount)

        // 第二次迁移（应该跳过）
        testUserDefaults.migrateLegacyConfig()
        let accountsAfterSecond = testUserDefaults.getAccounts()

        // 账号数量应该是第一次迁移的 1 个 + 手动添加的 1 个 = 2 个
        // 而不是再次迁移导致重复
        XCTAssertEqual(accountsAfterSecond.count, 2)
    }

    func testMigrationSkippedWhenNewFormatExists() {
        // 添加新格式账号
        let existingAccount = AccountConfig(
            id: UUID().uuidString,
            name: "已存在的账号",
            baseURL: "https://api.zai.ai",
            authToken: "existing-token"
        )
        testUserDefaults.addAccount(existingAccount)

        // 设置旧版配置（但已有新格式，应该被忽略）
        testUserDefaults.set("https://open.bigmodel.cn/api", forKey: "ANTHROPIC_BASE_URL")
        testUserDefaults.set("Bearer legacy-token", forKey: "ANTHROPIC_AUTH_TOKEN")

        // 执行迁移
        testUserDefaults.migrateLegacyConfig()

        // 应该只保留原有账号，不会重复添加
        let accounts = testUserDefaults.getAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].name, "已存在的账号")
        XCTAssertEqual(accounts[0].authToken, "existing-token")
    }

    func testMigrationWithNoConfig() {
        // 没有任何配置，执行迁移
        testUserDefaults.migrateLegacyConfig()

        // 应该不创建任何账号
        let accounts = testUserDefaults.getAccounts()
        XCTAssertEqual(accounts.count, 0)

        // 迁移标记应该被设置
        XCTAssertTrue(testUserDefaults.bool(forKey: "GLM_MIGRATION_COMPLETED"))
    }
}

// MARK: - UsageData Tests

final class UsageDataTests: XCTestCase {

    func testTokenUsagePercent() {
        let data = UsageData(
            tokenLimit: 1000000,
            tokenUsed: 500000,
            mcpLimit: 100,
            mcpUsed: 50,
            modelUsage: [],
            toolUsage: [],
            lastUpdateTime: Date(),
            tokenResetTime: nil,
            mcpResetTime: nil
        )

        XCTAssertEqual(data.tokenUsagePercent, 0.5, accuracy: 0.001)
    }

    func testMcpUsagePercent() {
        let data = UsageData(
            tokenLimit: 1000000,
            tokenUsed: 0,
            mcpLimit: 100,
            mcpUsed: 75,
            modelUsage: [],
            toolUsage: [],
            lastUpdateTime: Date(),
            tokenResetTime: nil,
            mcpResetTime: nil
        )

        XCTAssertEqual(data.mcpUsagePercent, 0.75, accuracy: 0.001)
    }

    func testTokenRemaining() {
        let data = UsageData(
            tokenLimit: 1000000,
            tokenUsed: 300000,
            mcpLimit: 0,
            mcpUsed: 0,
            modelUsage: [],
            toolUsage: [],
            lastUpdateTime: Date(),
            tokenResetTime: nil,
            mcpResetTime: nil
        )

        XCTAssertEqual(data.tokenRemaining, 700000)
    }

    func testResetTimeDescription() {
        let data = UsageData(
            tokenLimit: 0,
            tokenUsed: 0,
            mcpLimit: 0,
            mcpUsed: 0,
            modelUsage: [],
            toolUsage: [],
            lastUpdateTime: Date(),
            tokenResetTime: nil,
            mcpResetTime: nil
        )

        // 测试过去的重置时间
        let pastTime = Date().addingTimeInterval(-3600)
        XCTAssertEqual(data.resetTimeDescription(pastTime), "已重置")

        // 测试即将到来的重置时间
        let soonTime = Date().addingTimeInterval(300)
        let description = data.resetTimeDescription(soonTime)
        XCTAssertTrue(description == "即将重置" || description == "5分钟后")

        // 测试几天后的重置时间
        let daysTime = Date().addingTimeInterval(48 * 3600)
        XCTAssertEqual(data.resetTimeDescription(daysTime), "2天后")
    }
}
