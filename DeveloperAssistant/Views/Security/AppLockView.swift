import SwiftUI

struct AppLockView: View {
    let model: AppLockModel

    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 76, height: 76)
                    .background(.tint.opacity(0.12), in: .rect(cornerRadius: 22))

                VStack(spacing: 7) {
                    Text("开发管理助手已锁定")
                        .font(.title.weight(.semibold))
                    Text("使用 Touch ID 或 Mac 登录密码解锁。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Button("解锁", systemImage: "touchid") {
                    model.unlock()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isAuthenticating)

                if model.isAuthenticating {
                    ProgressView("正在等待系统验证…")
                        .controlSize(.small)
                }
            }
            .padding(36)
            .frame(maxWidth: 480)
            .modernGlassCard()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .task { model.unlock() }
    }
}
