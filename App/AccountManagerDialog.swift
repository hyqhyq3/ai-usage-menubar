//
//  AccountManagerDialog.swift
//  menubar-min
//
//  Created on 2025-02-08.
//

import AppKit

// MARK: - 账号管理对话框

class AccountManagerDialog: NSWindow {
    private let tableView: NSTableView
    private let dataSource: AccountManagerDataSource
    private var accounts: [AccountConfig] = []
    private var selectedIndex: Int = -1
    private var originalAccount: AccountConfig? // 保存原始账号数据用于比较

    // UI 组件
    private let nameLabel: NSTextField
    private let nameField: NSTextField
    private let serviceProviderLabel: NSTextField
    private let serviceProviderPopup: NSPopUpButton
    private let tokenLabel: NSTextField
    private let tokenField: NSSecureTextField
    private let addButton: NSButton
    private let removeButton: NSButton
    private let setCurrentButton: NSButton
    private let saveButton: NSButton
    private let closeButton: NSButton

    var onAccountChanged: (() -> Void)?

    init() {
        // 创建数据源
        dataSource = AccountManagerDataSource()

        // 初始化表格视图
        tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        tableView.style = .plain
        tableView.rowHeight = 24
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.dataSource = dataSource
        tableView.delegate = dataSource

        // 创建列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "账号名称"
        nameColumn.width = 120
        tableView.addTableColumn(nameColumn)

        let providerColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("provider"))
        providerColumn.title = "服务商"
        providerColumn.width = 100
        tableView.addTableColumn(providerColumn)

        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "状态"
        statusColumn.width = 80
        tableView.addTableColumn(statusColumn)

        // 初始化 UI 组件
        nameLabel = NSTextField(labelWithString: "账号名称:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        nameField = NSTextField(frame: .zero)
        nameField.placeholderString = "我的 GLM 账号"
        nameField.translatesAutoresizingMaskIntoConstraints = false

        serviceProviderLabel = NSTextField(labelWithString: "API 服务商:")
        serviceProviderLabel.translatesAutoresizingMaskIntoConstraints = false

        serviceProviderPopup = NSPopUpButton(frame: .zero)
        serviceProviderPopup.addItem(withTitle: "z.ai (api.zai.ai)")
        serviceProviderPopup.addItem(withTitle: "bigmodel.cn (open.bigmodel.cn/api)")
        serviceProviderPopup.addItem(withTitle: "moonshot.cn (api.moonshot.cn/v1)")
        serviceProviderPopup.addItem(withTitle: "deepseek.com (api.deepseek.com)")
        serviceProviderPopup.addItem(withTitle: "openrouter.ai (openrouter.ai)")
        serviceProviderPopup.translatesAutoresizingMaskIntoConstraints = false

        tokenLabel = NSTextField(labelWithString: "Auth Token:")
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false

        tokenField = NSSecureTextField(frame: .zero)
        tokenField.placeholderString = "Bearer eyJ..."
        tokenField.translatesAutoresizingMaskIntoConstraints = false

        addButton = NSButton(title: "添加账号", target: nil, action: nil)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        removeButton = NSButton(title: "删除账号", target: nil, action: nil)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.isEnabled = false

        setCurrentButton = NSButton(title: "设为当前", target: nil, action: nil)
        setCurrentButton.translatesAutoresizingMaskIntoConstraints = false
        setCurrentButton.isEnabled = false

        saveButton = NSButton(title: "保存修改", target: nil, action: nil)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.isEnabled = false
        saveButton.keyEquivalent = "\r"

        closeButton = NSButton(title: "关闭", target: nil, action: nil)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.keyEquivalent = "\u{1B}"

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        // 设置按钮目标（必须在 super.init 之后）
        addButton.target = self
        addButton.action = #selector(addAccount)
        removeButton.target = self
        removeButton.action = #selector(removeAccount)
        setCurrentButton.target = self
        setCurrentButton.action = #selector(setCurrentAccount)
        saveButton.target = self
        saveButton.action = #selector(saveCurrentAccount)
        closeButton.target = self
        closeButton.action = #selector(closeDialog)

        // 设置数据源对对话框的引用
        dataSource.dialog = self

        // 设置字段代理以监听变化
        nameField.delegate = self
        tokenField.delegate = self

        // 设置服务商下拉菜单的 action
        serviceProviderPopup.target = self
        serviceProviderPopup.action = #selector(serviceProviderChanged)

        title = "GLM 用量统计 - 账号管理"
        isReleasedWhenClosed = false

        setupUI()
        refreshAccounts()
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 400))
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // 使用 NSScrollView 包裹表格
        let scrollView = NSScrollView(frame: .zero)
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // 详情区域容器
        let detailContainer = NSView(frame: .zero)
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.wantsLayer = true
        detailContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor

        contentView.addSubview(scrollView)
        contentView.addSubview(detailContainer)
        detailContainer.addSubview(nameLabel)
        detailContainer.addSubview(nameField)
        detailContainer.addSubview(serviceProviderLabel)
        detailContainer.addSubview(serviceProviderPopup)
        detailContainer.addSubview(tokenLabel)
        detailContainer.addSubview(tokenField)
        detailContainer.addSubview(saveButton)
        contentView.addSubview(addButton)
        contentView.addSubview(removeButton)
        contentView.addSubview(setCurrentButton)
        contentView.addSubview(closeButton)

        // 布局约束
        NSLayoutConstraint.activate([
            // 表格视图
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 150),

            // 详情容器
            detailContainer.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            detailContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            detailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // 账号名称
            nameLabel.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 12),
            nameLabel.widthAnchor.constraint(equalToConstant: 80),

            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12),

            // 服务商
            serviceProviderLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            serviceProviderLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 12),
            serviceProviderLabel.widthAnchor.constraint(equalToConstant: 80),

            serviceProviderPopup.centerYAnchor.constraint(equalTo: serviceProviderLabel.centerYAnchor),
            serviceProviderPopup.leadingAnchor.constraint(equalTo: serviceProviderLabel.trailingAnchor, constant: 8),
            serviceProviderPopup.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12),

            // Token
            tokenLabel.topAnchor.constraint(equalTo: serviceProviderPopup.bottomAnchor, constant: 12),
            tokenLabel.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 12),
            tokenLabel.widthAnchor.constraint(equalToConstant: 80),

            tokenField.centerYAnchor.constraint(equalTo: tokenLabel.centerYAnchor),
            tokenField.leadingAnchor.constraint(equalTo: tokenLabel.trailingAnchor, constant: 8),
            tokenField.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12),

            // 保存按钮
            saveButton.topAnchor.constraint(equalTo: tokenField.bottomAnchor, constant: 12),
            saveButton.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -12),
            saveButton.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: -12),

            // 操作按钮
            addButton.topAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: 16),
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            removeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 12),

            setCurrentButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            setCurrentButton.leadingAnchor.constraint(equalTo: removeButton.trailingAnchor, constant: 12),

            closeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        self.contentView = contentView
    }

    func refreshAccounts() {
        accounts = UserDefaults.standard.getAccounts()
        let currentId = UserDefaults.standard.string(forKey: "GLM_CURRENT_ACCOUNT_ID")

        // 更新数据源
        var displayAccounts: [(account: AccountConfig, isCurrent: Bool)] = []
        for account in accounts {
            displayAccounts.append((account, account.id == currentId))
        }
        dataSource.accounts = displayAccounts

        tableView.reloadData()
        updateButtonStates()
        clearDetailFields()
    }

    private func updateButtonStates() {
        let hasSelection = selectedIndex >= 0 && selectedIndex < accounts.count
        removeButton.isEnabled = hasSelection
        setCurrentButton.isEnabled = hasSelection && selectedIndex != getCurrentAccountIndex()
        updateSaveButtonState()
    }

    private func updateSaveButtonState() {
        guard selectedIndex >= 0 && selectedIndex < accounts.count else {
            saveButton.isEnabled = false
            return
        }

        // 检查字段是否有变化
        let hasChanges = checkForChanges()
        saveButton.isEnabled = hasChanges
    }

    private func checkForChanges() -> Bool {
        guard let original = originalAccount else { return false }

        // 获取当前字段值
        let currentName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var currentToken = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceIndex = serviceProviderPopup.indexOfSelectedItem

        // 自动添加 Bearer 前缀进行比较
        if !currentToken.hasPrefix("Bearer ") {
            currentToken = "Bearer " + currentToken
        }

        // 获取当前选中的 baseURL
        let currentBaseURL: String
        switch serviceIndex {
        case 1:
            currentBaseURL = "https://open.bigmodel.cn/api"
        case 2:
            currentBaseURL = "https://api.moonshot.cn/v1"
        case 3:
            currentBaseURL = "https://api.deepseek.com"
        case 4:
            currentBaseURL = "https://openrouter.ai"
        default:
            currentBaseURL = "https://api.zai.ai"
        }

        // 比较是否有变化
        return original.name != currentName ||
               original.baseURL != currentBaseURL ||
               original.authToken != currentToken
    }

    private func getCurrentAccountIndex() -> Int? {
        let currentId = UserDefaults.standard.string(forKey: "GLM_CURRENT_ACCOUNT_ID")
        return accounts.firstIndex { $0.id == currentId }
    }

    private func clearDetailFields() {
        nameField.stringValue = ""
        serviceProviderPopup.selectItem(at: 0)
        tokenField.stringValue = ""
        originalAccount = nil
        saveButton.isEnabled = false
    }

    private func populateDetailFields(account: AccountConfig) {
        // 保存原始数据用于比较
        originalAccount = account

        nameField.stringValue = account.name
        if account.baseURL.contains("bigmodel") {
            serviceProviderPopup.selectItem(at: 1)
        } else if account.baseURL.contains("moonshot") {
            serviceProviderPopup.selectItem(at: 2)
        } else if account.baseURL.contains("deepseek") {
            serviceProviderPopup.selectItem(at: 3)
        } else if account.baseURL.contains("openrouter") {
            serviceProviderPopup.selectItem(at: 4)
        } else {
            serviceProviderPopup.selectItem(at: 0)
        }
        // 隐藏 Bearer 前缀以便于查看
        let displayToken = account.authToken.hasPrefix("Bearer ")
            ? String(account.authToken.dropFirst(7))
            : account.authToken
        tokenField.stringValue = displayToken

        // 填充后检查是否有变化
        updateSaveButtonState()
    }

    @objc private func addAccount() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let index = serviceProviderPopup.indexOfSelectedItem
        let baseURL: String
        switch index {
        case 1:
            baseURL = "https://open.bigmodel.cn/api"
        case 2:
            baseURL = "https://api.moonshot.cn/v1"
        case 3:
            baseURL = "https://api.deepseek.com"
        case 4:
            baseURL = "https://openrouter.ai"
        default:
            baseURL = "https://api.zai.ai"
        }

        guard !name.isEmpty && !token.isEmpty else {
            showAlert(message: "请填写账号名称和 Token")
            return
        }

        // 自动添加 Bearer 前缀（如果没有）
        if !token.hasPrefix("Bearer ") {
            token = "Bearer " + token
        }

        let account = AccountConfig(
            id: UUID().uuidString,
            name: name,
            baseURL: baseURL,
            authToken: token
        )

        UserDefaults.standard.addAccount(account)
        refreshAccounts()
        onAccountChanged?()
        clearDetailFields()
    }

    @objc private func removeAccount() {
        guard selectedIndex >= 0 && selectedIndex < accounts.count else { return }

        let account = accounts[selectedIndex]
        let isCurrent = getCurrentAccountIndex() == selectedIndex

        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除账号「\(account.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            UserDefaults.standard.removeAccount(account.id)
            refreshAccounts()
            if isCurrent {
                onAccountChanged?()
            }
        }
    }

    @objc private func setCurrentAccount() {
        guard selectedIndex >= 0 && selectedIndex < accounts.count else { return }

        let account = accounts[selectedIndex]
        UserDefaults.standard.setCurrentAccount(account.id)
        refreshAccounts()
        onAccountChanged?()
    }

    @objc private func saveCurrentAccount() {
        guard selectedIndex >= 0 && selectedIndex < accounts.count else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let index = serviceProviderPopup.indexOfSelectedItem
        let baseURL: String
        switch index {
        case 1:
            baseURL = "https://open.bigmodel.cn/api"
        case 2:
            baseURL = "https://api.moonshot.cn/v1"
        case 3:
            baseURL = "https://api.deepseek.com"
        case 4:
            baseURL = "https://openrouter.ai"
        default:
            baseURL = "https://api.zai.ai"
        }

        guard !name.isEmpty && !token.isEmpty else {
            showAlert(message: "请填写账号名称和 Token")
            return
        }

        // 自动添加 Bearer 前缀（如果没有）
        if !token.hasPrefix("Bearer ") {
            token = "Bearer " + token
        }

        var account = accounts[selectedIndex]
        // 创建新账号配置（因为 id 是 let）
        let updatedAccount = AccountConfig(
            id: account.id,
            name: name,
            baseURL: baseURL,
            authToken: token
        )

        UserDefaults.standard.updateAccount(updatedAccount)
        refreshAccounts()

        // 如果修改的是当前账号，触发刷新
        if getCurrentAccountIndex() == selectedIndex {
            onAccountChanged?()
        }
    }

    @objc private func serviceProviderChanged() {
        updateSaveButtonState()
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        center()
        makeKeyAndOrderFront(nil)
    }

    @objc func closeDialog() {
        close()
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - NSTextFieldDelegate
}

extension AccountManagerDialog: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateSaveButtonState()
    }
}

// MARK: - 表格数据源

extension AccountManagerDialog {
    class AccountManagerDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var dialog: AccountManagerDialog?
        var accounts: [(account: AccountConfig, isCurrent: Bool)] = []

        func numberOfRows(in tableView: NSTableView) -> Int {
            return accounts.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < accounts.count else { return nil }

            let account = accounts[row].account
            let isCurrent = accounts[row].isCurrent

            let cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 100, height: 24))

            let textField = NSTextField(frame: NSRect(x: 4, y: 2, width: (tableColumn?.width ?? 100) - 8, height: 20))
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.cell?.usesSingleLineMode = true
            textField.cell?.lineBreakMode = .byTruncatingTail

            switch tableColumn?.identifier.rawValue {
            case "name":
                textField.stringValue = account.name + (isCurrent ? " (当前)" : "")
                if isCurrent {
                    textField.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                }
            case "provider":
                textField.stringValue = account.serviceProvider
            case "status":
                textField.stringValue = account.isValid ? "有效" : "无效"
                textField.textColor = account.isValid ? .systemGreen : .systemRed
            default:
                textField.stringValue = ""
            }

            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

            return cellView
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView,
                  let dialog = dialog else { return }

            dialog.selectedIndex = tableView.selectedRow
            dialog.updateButtonStates()

            if tableView.selectedRow >= 0 && tableView.selectedRow < accounts.count {
                dialog.populateDetailFields(account: accounts[tableView.selectedRow].account)
            } else {
                dialog.clearDetailFields()
            }
        }
    }
}