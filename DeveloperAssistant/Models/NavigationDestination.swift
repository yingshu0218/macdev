import Foundation

enum NavigationDestination: Hashable {
    case home
    case dnsWorkbench
    case projectsAndTags
    case history
    case connections
    case globalSearch
    case serversWorkbench
    case certificatesWorkbench
    case deploymentsWorkbench
    case modulePreview(AppModuleID)
    case settings
}
