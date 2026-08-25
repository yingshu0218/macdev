import SwiftUI

struct DarkBorderTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.72), lineWidth: 1)
            }
    }
}

extension TextFieldStyle where Self == DarkBorderTextFieldStyle {
    static var darkBorder: DarkBorderTextFieldStyle { DarkBorderTextFieldStyle() }
}

private struct DarkBorderTextEditorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.72), lineWidth: 1)
            }
    }
}

extension View {
    func darkBorderTextEditor() -> some View {
        modifier(DarkBorderTextEditorModifier())
    }
}
