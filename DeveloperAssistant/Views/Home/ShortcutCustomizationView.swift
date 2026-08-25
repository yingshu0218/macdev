import SwiftUI

struct ShortcutCustomizationView: View {
    let store: ShortcutStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自定义快捷入口")
                        .font(.title2.weight(.semibold))
                    Text("选择首页显示的应用，并调整它们的顺序。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)

            Divider()

            List {
                ForEach(AppModuleCatalog.modules) { module in
                    ShortcutCustomizationRow(module: module, store: store)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("恢复默认", action: store.reset)
                Spacer()
                Text("更改会自动保存")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
        }
        .frame(width: 560, height: 500)
    }
}

private struct ShortcutCustomizationRow: View {
    let module: AppModule
    let store: ShortcutStore

    private var isPinned: Binding<Bool> {
        Binding(
            get: { store.isPinned(module.id) },
            set: { store.setPinned(module.id, $0) }
        )
    }

    private var pinnedIndex: Int? {
        store.pinnedModuleIDs.firstIndex(of: module.id)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: module.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.title)
                Text(module.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let pinnedIndex {
                HStack(spacing: 4) {
                    Button("上移", systemImage: "chevron.up") {
                        store.moveUp(module.id)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(pinnedIndex == 0)

                    Button("下移", systemImage: "chevron.down") {
                        store.moveDown(module.id)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(pinnedIndex == store.pinnedModuleIDs.count - 1)
                }
                .buttonStyle(.borderless)
            }

            Toggle("在首页显示", isOn: isPinned)
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }
}
