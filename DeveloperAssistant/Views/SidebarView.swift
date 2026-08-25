import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationDestination?

    var body: some View {
        List(selection: $selection) {
            Label("首页", systemImage: "square.grid.2x2")
                .tag(NavigationDestination.home)

            Section("DNS 管理") {
                Label("工作台", systemImage: "rectangle.3.group")
                    .tag(NavigationDestination.dnsWorkbench)
                Label("项目与标签", systemImage: "tag")
                    .tag(NavigationDestination.projectsAndTags)
                Label("操作历史", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .tag(NavigationDestination.history)
                Label("服务商连接", systemImage: "link")
                    .tag(NavigationDestination.connections)
                Label("全局搜索", systemImage: "magnifyingglass")
                    .tag(NavigationDestination.globalSearch)
            }

            Section("服务器管理") {
                Label("资产总览", systemImage: "server.rack")
                    .tag(NavigationDestination.serversWorkbench)
            }

            Section("运维管理") {
                Label("证书管理", systemImage: "checkmark.shield")
                    .tag(NavigationDestination.certificatesWorkbench)
                Label("部署记录", systemImage: "shippingbox")
                    .tag(NavigationDestination.deploymentsWorkbench)
            }

            Section("系统") {
                Label("系统设置", systemImage: "gearshape")
                    .tag(NavigationDestination.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("开发管理助手")
    }
}
