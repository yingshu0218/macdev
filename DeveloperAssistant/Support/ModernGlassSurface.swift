import SwiftUI

extension View {
    @ViewBuilder
    func modernGlassCard(interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: 20))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                }
        }
    }
}
