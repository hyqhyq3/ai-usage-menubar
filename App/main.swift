//
//  main.swift
//  menubar-min
//
//  Created on 2025-02-02.
//

import AppKit

// MARK: - 配置对话框

class ConfigDialog: NSWindow {
    private let baseURLField: NSTextField = {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://api.zai.ai"
        return field
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
        let urlLabel = NSTextField(labelWithString: "Base URL:")
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(urlLabel)

        // Base URL 输入框
        baseURLField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(baseURLField)

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

            baseURLField.centerYAnchor.constraint(equalTo: urlLabel.centerYAnchor),
            baseURLField.leadingAnchor.constraint(equalTo: urlLabel.trailingAnchor, constant: 12),
            baseURLField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            tokenLabel.topAnchor.constraint(equalTo: baseURLField.bottomAnchor, constant: 16),
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
            baseURLField.stringValue = config.baseURL
            tokenField.stringValue = config.authToken
        }
    }

    @objc private func saveConfig() {
        let baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseURL.isEmpty, !token.isEmpty else {
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

    // 菜单项引用
    private var tokenPercentItem: NSMenuItem?
    private var tokenDetailItem: NSMenuItem?
    private var mcpDetailItem: NSMenuItem?
    private var separator1: NSMenuItem?
    private var separator2: NSMenuItem?
    private var modelUsageItems: [NSMenuItem] = []
    private var updateTimeItem: NSMenuItem?
    private var refreshItem: NSMenuItem?
    private var configItem: NSMenuItem?
    private var quitItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 初始化 API 服务
        apiService = APIService()

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = " GLM"
        }

        // 检查配置，如果没有则显示配置对话框
        if !(apiService?.hasConfig() ?? false) {
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
    }

    private func buildMenu() {
        guard let statusItem = statusItem else { return }

        let menu = NSMenu()

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

        // 刷新按钮
        refreshItem = NSMenuItem(title: "刷新", action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem?.target = self
        menu.addItem(refreshItem!)

        // 配置按钮
        configItem = NSMenuItem(title: "配置...", action: #selector(showConfigDialog), keyEquivalent: ",")
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
                self?.apiService?.updateConfig(baseURL: baseURL, authToken: token)
                // 配置更新后立即刷新
                Task {
                    await self?.refreshUsageData()
                }
            }
        }
        configDialog?.showDialog()
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
