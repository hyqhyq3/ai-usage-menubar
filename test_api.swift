#!/usr/bin/env swift

//
//  测试 API 数据获取和解析
//

import Foundation

// MARK: - 数据模型

struct BigModelResponse<T: Decodable>: Decodable {
    let code: Int
    let msg: String
    let data: T
    let success: Bool
}

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

// MARK: - 测试函数

func testDecode() {
    print("=== 测试 1: 解析配额数据 ===")

    let quotaJSON = """
    {
        "code": 200,
        "msg": "Operation successful",
        "data": {
            "limits": [
                {
                    "type": "TIME_LIMIT",
                    "unit": 5,
                    "number": 1,
                    "usage": 100,
                    "currentValue": 48,
                    "remaining": 52,
                    "percentage": 48,
                    "usageDetails": [
                        {"modelCode": "search-prime", "usage": 43},
                        {"modelCode": "web-reader", "usage": 16}
                    ]
                },
                {
                    "type": "TOKENS_LIMIT",
                    "unit": 3,
                    "number": 5,
                    "usage": 40000000,
                    "currentValue": 28621088,
                    "remaining": 11378912,
                    "percentage": 71,
                    "nextResetTime": 1770051606728
                }
            ]
        },
        "success": true
    }
    """

    do {
        let data = quotaJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(BigModelResponse<BigModelQuotaData>.self, from: data)

        print("✓ 解析成功")
        print("  - code: \(response.code)")
        print("  - success: \(response.success)")
        print("  - limits 数量: \(response.data.limits.count)")

        for limit in response.data.limits {
            print("  - \(limit.type): \(limit.currentValue) / \(limit.usage) (\(limit.percentage)%)")
            if let details = limit.usageDetails {
                print("    - 使用详情: \(details.count) 项")
                for detail in details {
                    print("      • \(detail.modelCode): \(detail.usage)")
                }
            }
        }

        // 提取 Token 数据
        if let tokenLimit = response.data.limits.first(where: { $0.type == "TOKENS_LIMIT" }) {
            print("\n✓ Token 配额提取成功:")
            print("  - 限制: \(tokenLimit.usage)")
            print("  - 已用: \(tokenLimit.currentValue)")
            print("  - 剩余: \(tokenLimit.remaining ?? 0)")
            print("  - 百分比: \(tokenLimit.percentage)%")
        }

    } catch {
        print("✗ 解析失败: \(error)")
    }
}

func testModelUsageDecode() {
    print("\n=== 测试 2: 解析模型使用数据 ===")

    let usageJSON = """
    {
        "code": 200,
        "msg": "Operation successful",
        "data": {
            "x_time": ["2026-02-01 15:00", "2026-02-01 16:00"],
            "modelCallCount": [24, 1],
            "tokensUsage": [1516259, 105021],
            "totalUsage": {
                "totalModelCallCount": 2052,
                "totalTokensUsage": 115141020
            }
        },
        "success": true
    }
    """

    do {
        let data = usageJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(BigModelResponse<BigModelModelUsageData>.self, from: data)

        print("✓ 解析成功")
        print("  - 时间点数量: \(response.data.xTime.count)")
        print("  - 总调用次数: \(response.data.totalUsage.totalModelCallCount)")
        print("  - 总 Token 使用: \(response.data.totalUsage.totalTokensUsage)")

    } catch {
        print("✗ 解析失败: \(error)")
    }
}

func testRealAPI() async {
    print("\n=== 测试 3: 真实 API 调用 ===")

    let baseURL = "https://open.bigmodel.cn/api"
    let token = "8e258c05168d44d280296dc0bd823bf7.6quZMHb4R0aZzcfX"

    // 测试配额 API
    print("测试配额 API...")
    if let url = URL(string: "\(baseURL)/monitor/usage/quota/limit") {
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("  - 状态码: \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(BigModelResponse<BigModelQuotaData>.self, from: data)

            if result.success {
                print("✓ 配额 API 调用成功")
                for limit in result.data.limits {
                    print("  - \(limit.type): \(limit.currentValue) / \(limit.usage) (\(limit.percentage)%)")
                }
            } else {
                print("✗ API 返回失败: \(result.msg)")
            }

        } catch {
            print("✗ API 调用失败: \(error)")
        }
    }

    // 测试模型使用 API
    print("\n测试模型使用 API...")

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let now = Date()
    let startTime = dateFormatter.string(from: now.addingTimeInterval(-24 * 60 * 60))
    let endTime = dateFormatter.string(from: now)

    print("  - 时间范围: \(startTime) ~ \(endTime)")

    if var components = URLComponents(string: "\(baseURL)/monitor/usage/model-usage") {
        components.queryItems = [
            URLQueryItem(name: "startTime", value: startTime),
            URLQueryItem(name: "endTime", value: endTime)
        ]

        if let url = components.url {
            var request = URLRequest(url: url)
            request.setValue(token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    print("  - 状态码: \(httpResponse.statusCode)")
                }

                let decoder = JSONDecoder()
                let result = try decoder.decode(BigModelResponse<BigModelModelUsageData>.self, from: data)

                if result.success {
                    print("✓ 模型使用 API 调用成功")
                    print("  - 总调用次数: \(result.data.totalUsage.totalModelCallCount)")
                    print("  - 总 Token 使用: \(result.data.totalUsage.totalTokensUsage)")
                } else {
                    print("✗ API 返回失败: \(result.msg)")
                }

            } catch {
                print("✗ API 调用失败: \(error)")
            }
        }
    }
}

// MARK: - 运行测试

// 同步测试
testDecode()
testModelUsageDecode()

// 异步测试
Task {
    await testRealAPI()
    exit(0)
}

// 保持运行
dispatchMain()
