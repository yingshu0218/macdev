import Foundation

enum ServerProvider: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case selfHosted
    case aliyun
    case tencentCloud
    case aws
    case huaweiCloud
    case digitalOcean
    case vultr
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfHosted: "自建 / VPS"
        case .aliyun: "阿里云"
        case .tencentCloud: "腾讯云"
        case .aws: "AWS"
        case .huaweiCloud: "华为云"
        case .digitalOcean: "DigitalOcean"
        case .vultr: "Vultr"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .selfHosted: "server.rack"
        case .aliyun, .tencentCloud, .aws, .huaweiCloud: "cloud"
        case .digitalOcean, .vultr: "globe.americas"
        case .other: "shippingbox"
        }
    }
}

enum ServerEnvironment: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case production
    case staging
    case development
    case testing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .production: "生产"
        case .staging: "预发布"
        case .development: "开发"
        case .testing: "测试"
        }
    }
}

enum ServerHealthStatus: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case unknown
    case online
    case offline
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown: "未检测"
        case .online: "在线"
        case .offline: "不可达"
        case .maintenance: "维护中"
        }
    }

    var systemImage: String {
        switch self {
        case .unknown: "questionmark.circle.fill"
        case .online: "checkmark.circle.fill"
        case .offline: "xmark.circle.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }
}

struct ServerDraft: Equatable, Sendable {
    var name = ""
    var provider: ServerProvider = .selfHosted
    var host = ""
    var port = 22
    var username = "root"
    var environment: ServerEnvironment = .production
    var project = ""
    var region = ""
    var operatingSystem = ""
    var tags = ""
    var note = ""
    var expiresAt: Date?
    var isFavorite = false
}

enum ServerValidationError: LocalizedError, Equatable {
    case missingName
    case missingHost
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .missingName: "请输入服务器名称。"
        case .missingHost: "请输入 IP 地址或主机名。"
        case .invalidPort: "SSH 端口必须在 1–65535 之间。"
        }
    }
}
