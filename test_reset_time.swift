#!/usr/bin/env swift

import Foundation

// 测试重置时间解析和格式化

// 假设 API 返回的重置时间戳（毫秒）
let resetTimestamp: Int64 = 1770051606728  // 对应 2026-06-02 左右

// 转换为 Date
let resetDate = Date(timeIntervalSince1970: TimeInterval(resetTimestamp) / 1000)

let now = Date()
let interval = resetDate.timeIntervalSince(now)

print("=== 重置时间测试 ===")
print("当前时间: \(Date())")
print("重置时间戳: \(resetTimestamp) ms")
print("重置时间: \(resetDate)")
print("相差秒数: \(Int(interval)) 秒")

// 计算友好的描述
let hours = Int(interval / 3600)
let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

var description = ""
if interval <= 0 {
    description = "已重置"
} else if hours > 24 {
    let days = hours / 24
    description = "\(days)天后"
} else if hours > 0 {
    description = "\(hours)小时后"
} else if minutes > 0 {
    description = "\(minutes)分钟后"
} else {
    description = "即将重置"
}

print("友好描述: \(description)")

// 格式化日期
let formatter = DateFormatter()
formatter.dateFormat = "MM-dd HH:mm"
formatter.timeZone = TimeZone.current
print("格式化日期: \(formatter.string(from: resetDate))")

// 测试不同的重置时间场景
print("\n=== 不同场景测试 ===")

let scenarios: [(Int64, String)] = [
    (0, "现在"),
    (60000, "1分钟后"),
    (3600000, "1小时后"),
    (86400000, "1天后"),
    (-3600000, "1小时前（已过期）")
]

for (timestamp, name) in scenarios {
    let testDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    let testInterval = testDate.timeIntervalSince(now)
    let testHours = Int(testInterval / 3600)
    let testMinutes = Int((testInterval.truncatingRemainder(dividingBy: 3600)) / 60)

    var desc = ""
    if testInterval <= 0 {
        desc = "已重置"
    } else if testHours > 24 {
        let days = testHours / 24
        desc = "\(days)天后"
    } else if testHours > 0 {
        desc = "\(testHours)小时后"
    } else if testMinutes > 0 {
        desc = "\(testMinutes)分钟后"
    } else {
        desc = "即将重置"
    }

    print("\(name): \(desc)")
}
