import Foundation

enum AppModuleID: String, Codable, CaseIterable, Hashable, Identifiable {
    case dns
    case servers
    case certificates
    case deployments

    var id: String { rawValue }
}

enum ModuleAvailability: Hashable {
    case ready
    case preview

    var title: String {
        switch self {
        case .ready: "可用"
        case .preview: "原生预览"
        }
    }
}

struct AppModule: Identifiable, Hashable {
    let id: AppModuleID
    let title: String
    let subtitle: String
    let systemImage: String
    let availability: ModuleAvailability
    let highlights: [String]

    var destination: NavigationDestination {
        switch id {
        case .dns:
            .dnsWorkbench
        case .servers:
            .serversWorkbench
        case .certificates:
            .certificatesWorkbench
        case .deployments:
            .deploymentsWorkbench
        }
    }
}

enum AppModuleCatalog {
    static let modules: [AppModule] = [
        AppModule(
            id: .dns,
            title: "DNS 管理",
            subtitle: "集中管理多平台域名与解析记录",
            systemImage: "network",
            availability: .ready,
            highlights: ["跨 Provider 搜索", "域名与解析管理", "操作历史与恢复"]
        ),
        AppModule(
            id: .servers,
            title: "服务器管理",
            subtitle: "整理云服务器、VPS 与环境信息",
            systemImage: "server.rack",
            availability: .ready,
            highlights: ["资产总览", "TCP 可达检测", "到期提醒"]
        ),
        AppModule(
            id: .certificates,
            title: "证书管理",
            subtitle: "跟踪证书有效期和部署位置",
            systemImage: "checkmark.shield",
            availability: .ready,
            highlights: ["到期追踪", "部署记录", "风险提醒"]
        ),
        AppModule(
            id: .deployments,
            title: "部署记录",
            subtitle: "记录发布、回滚与环境状态",
            systemImage: "shippingbox",
            availability: .ready,
            highlights: ["发布历史", "环境对照", "回滚线索"]
        )
    ]

    static let defaultPinnedIDs = AppModuleID.allCases

    static func module(for id: AppModuleID) -> AppModule? {
        modules.first { $0.id == id }
    }
}
