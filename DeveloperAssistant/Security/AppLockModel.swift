import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockModel {
    var isUnlocked: Bool
    var isAuthenticating = false
    var errorMessage: String?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        #if DEBUG
        let allowsDebugBypass = environment["DEVELOPER_ASSISTANT_SKIP_LOCK"] == "1"
        #else
        let allowsDebugBypass = false
        #endif
        isUnlocked = environment["XCTestConfigurationFilePath"] != nil || allowsDebugBypass
    }

    func unlock() {
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil

        Task {
            let context = LAContext()
            context.localizedCancelTitle = "取消"
            context.localizedFallbackTitle = "使用系统密码"

            var evaluationError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
                errorMessage = evaluationError?.localizedDescription ?? "当前 Mac 无法验证设备所有者。"
                isAuthenticating = false
                return
            }

            do {
                let didAuthenticate = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "解锁开发管理助手中的 DNS 资产与服务商连接"
                )
                isUnlocked = didAuthenticate
            } catch {
                errorMessage = error.localizedDescription
            }
            isAuthenticating = false
        }
    }

    func lock() {
        isUnlocked = false
        errorMessage = nil
    }
}
