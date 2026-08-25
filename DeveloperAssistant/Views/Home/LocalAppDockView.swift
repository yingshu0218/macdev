import AppKit
import SwiftUI

struct LocalAppDockView: View {
    let store: LocalAppShortcutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("应用快捷入口").font(.title2.weight(.semibold))
                    Text("添加本机已安装的应用，点击图标快速打开。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("添加应用", systemImage: "plus") { store.chooseApplications() }
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(store.shortcuts) { shortcut in
                        LocalAppDockItem(shortcut: shortcut, store: store)
                    }

                    Button { store.chooseApplications() } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.medium))
                                .frame(width: 58, height: 58)
                                .background(.quaternary, in: .rect(cornerRadius: 14))
                            Text("添加").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(18)
        .modernGlassCard()
    }
}

private struct LocalAppDockItem: View {
    let shortcut: LocalAppShortcut
    let store: LocalAppShortcutStore

    var body: some View {
        Button { store.open(shortcut) } label: {
            VStack(spacing: 7) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: shortcut.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 58, height: 58)
                Text(shortcut.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: 76)
            }
        }
        .buttonStyle(.plain)
        .help("打开 \(shortcut.displayName)")
        .contextMenu {
            Button("向左移动", systemImage: "arrow.left") { store.move(shortcut.id, offset: -1) }
            Button("向右移动", systemImage: "arrow.right") { store.move(shortcut.id, offset: 1) }
            Divider()
            Button("从快捷入口移除", systemImage: "minus.circle", role: .destructive) { store.remove(shortcut.id) }
        }
    }
}
