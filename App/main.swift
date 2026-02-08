//
//  main.swift
//  menubar-min
//
//  Created on 2025-02-02.
//

import AppKit

// MARK: - 配置对话框

class ConfigDialog: NSWindow {
    private let baseURLPopup: NSPopUpButton = {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        popup.addItem(withTitle: "z.ai (api.zai.ai)")
        popup.addItem(withTitle: "bigmodel.cn (open.bigmodel.cn/api)")
        return popup
    }()

    private let tokenField: NSTextField = {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "Bearer eyJ..."
        return field
    }()

    private var onSave: ((String, String) -> Void)?

    init(onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        title = "GLM 用量统计 - 配置"
        isReleasedWhenClosed = false

        setupUI()
        loadExistingConfig()
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // 标题
        let titleLabel = NSTextField(labelWithString: "GLM Coding Plan API 配置")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Base URL 标签
        let urlLabel = NSTextField(labelWithString: "API 服务商:")
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(urlLabel)

        // Base URL 下拉菜单
        baseURLPopup.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(baseURLPopup)

        // Token 标签
        let tokenLabel = NSTextField(labelWithString: "Auth Token:")
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tokenLabel)

        // Token 输入框
        tokenField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tokenField)

        // 按钮容器
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStack)

        // 保存按钮
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveConfig))
        saveButton.keyEquivalent = "\r"
        buttonStack.addArrangedSubview(saveButton)

        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(closeDialog))
        cancelButton.keyEquivalent = "\u{1B}"
        buttonStack.addArrangedSubview(cancelButton)

        // 布局约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            urlLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            urlLabel.widthAnchor.constraint(equalToConstant: 80),

            baseURLPopup.centerYAnchor.constraint(equalTo: urlLabel.centerYAnchor),
            baseURLPopup.leadingAnchor.constraint(equalTo: urlLabel.trailingAnchor, constant: 12),
            baseURLPopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            tokenLabel.topAnchor.constraint(equalTo: baseURLPopup.bottomAnchor, constant: 16),
            tokenLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tokenLabel.widthAnchor.constraint(equalToConstant: 80),

            tokenField.centerYAnchor.constraint(equalTo: tokenLabel.centerYAnchor),
            tokenField.leadingAnchor.constraint(equalTo: tokenLabel.trailingAnchor, constant: 12),
            tokenField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: tokenField.bottomAnchor, constant: 20),
            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])

        self.contentView = contentView
    }

    private func loadExistingConfig() {
        if let config = UserDefaults.standard.getAPIConfig() {
            // 根据 baseURL 设置下拉菜单选中项
            if config.baseURL.contains("bigmodel") {
                baseURLPopup.selectItem(at: 1)
            } else {
                baseURLPopup.selectItem(at: 0)
            }
            tokenField.stringValue = config.authToken
        }
    }

    @objc private func saveConfig() {
        let index = baseURLPopup.indexOfSelectedItem
        let baseURL: String
        switch index {
        case 1:
            baseURL = "https://open.bigmodel.cn/api"
        default: // case 0
            baseURL = "https://api.zai.ai"
        }

        let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            showAlert(message: "请填写完整的配置信息")
            return
        }

        onSave?(baseURL, token)
        // 关闭窗口并恢复 accessory 模式
        close()
        NSApp.setActivationPolicy(.accessory)
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "提示"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    func showDialog() {
        // 激活应用以便窗口可以接收键盘输入
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        center()
        makeKeyAndOrderFront(nil)
    }

    @objc func closeDialog() {
        close()
        // 恢复为 accessory 模式
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - 应用委托

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var apiService: APIService?
    private var timer: Timer?
    private var currentUsageData: UsageData?
    private var configDialog: ConfigDialog?
    private var accountManagerDialog: AccountManagerDialog?

    // 菜单项引用
    private var currentAccountItem: NSMenuItem?
    private var switchAccountItem: NSMenuItem?
    private var switchAccountMenu: NSMenu?
    private var tokenPercentItem: NSMenuItem?
    private var tokenDetailItem: NSMenuItem?
    private var mcpDetailItem: NSMenuItem?
    private var separator1: NSMenuItem?
    private var separator2: NSMenuItem?
    private var separator3: NSMenuItem?
    private var modelUsageItems: [NSMenuItem] = []
    private var updateTimeItem: NSMenuItem?
    private var refreshItem: NSMenuItem?
    private var manageAccountsItem: NSMenuItem?
    private var configItem: NSMenuItem?
    private var quitItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 迁移旧配置并初始化 API 服务
        UserDefaults.standard.migrateLegacyConfig()
        apiService = APIService()

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = " GLM"
        }

        // 检查是否有账号配置，如果没有则显示配置对话框
        if !UserDefaults.standard.hasAnyValidAccount() {
            showConfigDialog()
        } else {
            // 立即刷新一次数据
            Task {
                await refreshUsageData()
            }
        }

        // 启动定时刷新
        startTimer()

        // 构建菜单
        buildMenu()
        updateAccountDisplay()
    }

    private func buildMenu() {
        guard let statusItem = statusItem else { return }

        let menu = NSMenu()

        // 当前账号信息
        currentAccountItem = NSMenuItem(title: "账号: 加载中...", action: nil, keyEquivalent: "")
        currentAccountItem?.isEnabled = false
        menu.addItem(currentAccountItem!)

        // Token 用量百分比
        tokenPercentItem = NSMenuItem(title: "加载中...", action: nil, keyEquivalent: "")
        tokenPercentItem?.isEnabled = false
        menu.addItem(tokenPercentItem!)

        // Token 详细信息
        tokenDetailItem = NSMenuItem(title: "Token: -- / --", action: nil, keyEquivalent: "")
        tokenDetailItem?.isEnabled = false
        menu.addItem(tokenDetailItem!)

        // MCP 详细信息
        mcpDetailItem = NSMenuItem(title: "MCP: -- / --", action: nil, keyEquivalent: "")
        mcpDetailItem?.isEnabled = false
        menu.addItem(mcpDetailItem!)

        // 分隔符
        separator1 = NSMenuItem.separator()
        menu.addItem(separator1!)

        // 模型使用情况（占位符）
        for _ in 0..<3 {
            let item = NSMenuItem(title: "加载中...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            modelUsageItems.append(item)
        }

        // 分隔符
        separator2 = NSMenuItem.separator()
        menu.addItem(separator2!)

        // 更新时间
        updateTimeItem = NSMenuItem(title: "更新时间: --", action: nil, keyEquivalent: "")
        updateTimeItem?.isEnabled = false
        menu.addItem(updateTimeItem!)

        // 分隔符
        separator3 = NSMenuItem.separator()
        menu.addItem(separator3!)

        // 切换账号子菜单
        switchAccountItem = NSMenuItem(title: "切换账号", action: nil, keyEquivalent: "s")
        switchAccountMenu = NSMenu()
        switchAccountItem?.submenu = switchAccountMenu
        menu.addItem(switchAccountItem!)

        // 账号管理
        manageAccountsItem = NSMenuItem(title: "账号管理...", action: #selector(showAccountManager), keyEquivalent: "")
        manageAccountsItem?.target = self
        menu.addItem(manageAccountsItem!)

        // 刷新按钮
        refreshItem = NSMenuItem(title: "刷新", action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem?.target = self
        menu.addItem(refreshItem!)

        // 配置按钮（保留用于快速添加新账号）
        configItem = NSMenuItem(title: "添加账号...", action: #selector(showConfigDialog), keyEquivalent: ",")
        configItem?.target = self
        menu.addItem(configItem!)

        // 退出按钮
        quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem?.target = self
        menu.addItem(quitItem!)

        statusItem.menu = menu
    }

    private func updateMenu() {
        guard let data = currentUsageData else { return }

        // 更新账号显示
        updateAccountDisplay()

        // 更新标题栏百分比
        let percent = Int(data.tokenUsagePercent * 100)
        if let button = statusItem?.button {
            button.title = " GLM \(percent)%"
        }

        // 更新 Token 用量百分比
        tokenPercentItem?.title = "Token 用量: \(percent)%"

        // 更新 Token 详细信息（包含重置时间）
        var tokenTitle = "Token: \(formatNumber(data.tokenUsed)) / \(formatNumber(data.tokenLimit))"
        if let resetTime = data.tokenResetTime {
            tokenTitle += " (重置: \(data.resetTimeDescription(resetTime)))"
        }
        tokenDetailItem?.title = tokenTitle

        // 更新 MCP 详细信息（包含重置时间）
        let mcpPercent = Int(data.mcpUsagePercent * 100)
        var mcpTitle = "MCP: \(formatNumber(data.mcpUsed)) / \(formatNumber(data.mcpLimit)) (\(mcpPercent)%)"
        if let resetTime = data.mcpResetTime {
            mcpTitle += " (重置: \(data.resetTimeDescription(resetTime)))"
        }
        mcpDetailItem?.title = mcpTitle

        // 更新模型使用情况（显示前3个）
        let topModels = Array(data.modelUsage.prefix(3))
        for (index, item) in topModels.enumerated() {
            if index < modelUsageItems.count {
                let tokensStr = formatNumber(item.totalTokens)
                modelUsageItems[index].title = "\(item.modelName): \(tokensStr) tokens"
            }
        }

        // 隐藏多余的模型项
        for index in topModels.count..<modelUsageItems.count {
            modelUsageItems[index].isHidden = true
        }

        // 更新时间
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        updateTimeItem?.title = "更新时间: \(formatter.string(from: data.lastUpdateTime))"

        // 更新切换账号子菜单
        updateSwitchAccountMenu()
    }

    private func updateAccountDisplay() {
        if let accountName = apiService?.getCurrentAccountName() {
            currentAccountItem?.title = "账号: \(accountName)"
        } else {
            currentAccountItem?.title = "账号: 未配置"
        }
    }

    private func updateSwitchAccountMenu() {
        guard let menu = switchAccountMenu else { return }
        menu.removeAllItems()

        let accounts = UserDefaults.standard.getAccounts()
        let currentId = UserDefaults.standard.string(forKey: "GLM_CURRENT_ACCOUNT_ID")

        if accounts.isEmpty {
            let item = NSMenuItem(title: "无账号", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for account in accounts {
            let item = NSMenuItem(
                title: account.name,
                action: #selector(switchToAccount(_:)),
                keyEquivalent: ""
            )
            item.tag = Int(account.id.hashValue)
            item.target = self
            if account.id == currentId {
                item.state = .on
            }
            menu.addItem(item)
        }
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func startTimer() {
        // 每分钟刷新一次
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshUsageData()
            }
        }
    }

    @objc private func manualRefresh() {
        Task {
            await refreshUsageData()
        }
    }

    private func refreshUsageData() async {
        guard let apiService = apiService else { return }

        do {
            let data = try await apiService.refreshUsageData()
            currentUsageData = data
            updateMenu()
        } catch {
            print("刷新失败: \(error.localizedDescription)")
            // 显示错误状态
            if let button = statusItem?.button {
                button.title = " GLM !"
            }
            tokenPercentItem?.title = "刷新失败: \(error.localizedDescription)"
        }
    }

    @objc private func showConfigDialog() {
        if configDialog == nil {
            configDialog = ConfigDialog { [weak self] baseURL, token in
                // 创建新账号
                let account = AccountConfig(
                    id: UUID().uuidString,
                    name: "新账号 \(UserDefaults.standard.getAccounts().count + 1)",
                    baseURL: baseURL,
                    authToken: token
                )
                UserDefaults.standard.addAccount(account)
                // 切换到新账号
                self?.apiService?.switchAccount(account.id)
                // 立即刷新
                Task {
                    await self?.refreshUsageData()
                }
            }
        }
        configDialog?.showDialog()
    }

    @objc private func switchToAccount(_ sender: NSMenuItem) {
        let accounts = UserDefaults.standard.getAccounts()
        if let account = accounts.first(where: { Int($0.id.hashValue) == sender.tag }) {
            apiService?.switchAccount(account.id)
            Task {
                await refreshUsageData()
            }
        }
    }

    @objc private func showAccountManager() {
        if accountManagerDialog == nil {
            accountManagerDialog = AccountManagerDialog()
            accountManagerDialog?.onAccountChanged = { [weak self] in
                // 账号变更后刷新显示
                self?.updateAccountDisplay()
                self?.updateSwitchAccountMenu()
                // 重新加载当前账号并刷新数据
                Task {
                    await self?.refreshUsageData()
                }
            }
        }
        accountManagerDialog?.showDialog()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - 应用入口

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
