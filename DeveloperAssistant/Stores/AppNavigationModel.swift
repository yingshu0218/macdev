import Observation

@MainActor
@Observable
final class AppNavigationModel {
    var selection: NavigationDestination? = .home

    func open(_ destination: NavigationDestination) {
        selection = destination
    }
}
