import AppKit
import SwiftUI

struct ServerInspectorView: View {
    let server: ManagedServer
    let isChecking: Bool
    let check: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let toggleFavorite: () -> Void

    @State private var didCopySSHCommand = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                connectionCard
                metadataCard
                if !server.tagList.isEmpty { tagsCard }
                if !server.note.isEmpty { noteCard }

                Button("删除本地资产", systemImage: "trash", role: .destructive, action: delete)
                    .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(.background.secondary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: server.provider.systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(.tint.opacity(0.12), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(server.name).font(.title3.weight(.semibold))
                    Label(server.status.title, systemImage: server.status.systemImage)
                        .font(.callout)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                Button(action: toggleFavorite) {
                    Image(systemName: server.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(server.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(server.isFavorite ? "取消收藏" : "收藏")
            }

            HStack {
                Button(isChecking ? "检测中" : "检测连接", systemImage: "wave.3.right", action: check)
                    .disabled(isChecking)
                Button("编辑", systemImage: "pencil", action: edit)
            }
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接").font(.headline)
            LabeledContent("地址") {
                Text("\(server.host):\(server.port)").font(.callout.monospaced()).textSelection(.enabled)
            }
            LabeledContent("用户", value: server.username.isEmpty ? "—" : server.username)
            if let latency = server.latencyMilliseconds {
                LabeledContent("TCP 延迟", value: "\(latency) ms")
            }
            if let date = server.lastCheckedAt {
                LabeledContent("最近检测", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            Button(didCopySSHCommand ? "已复制" : "复制 SSH 命令", systemImage: didCopySSHCommand ? "checkmark" : "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(server.sshCommand, forType: .string)
                didCopySSHCommand = true
            }
            Button("在终端中打开 SSH", systemImage: "terminal") {
                let user = server.username.isEmpty ? "" : "\(server.username)@"
                if let url = URL(string: "ssh://\(user)\(server.host):\(server.port)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(16)
        .modernGlassCard()
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("资产信息").font(.headline)
            LabeledContent("Provider", value: server.provider.title)
            LabeledContent("环境", value: server.environment.title)
            LabeledContent("项目", value: server.project.isEmpty ? "—" : server.project)
            LabeledContent("区域", value: server.region.isEmpty ? "—" : server.region)
            LabeledContent("系统", value: server.operatingSystem.isEmpty ? "—" : server.operatingSystem)
            if let expiresAt = server.expiresAt {
                LabeledContent("到期", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding(16)
        .modernGlassCard()
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签").font(.headline)
            FlowLayout(spacing: 6) {
                ForEach(server.tagList, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.1), in: .capsule)
                }
            }
        }
        .padding(16)
        .modernGlassCard()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注").font(.headline)
            Text(server.note)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(16)
        .modernGlassCard()
    }

    private var statusColor: Color {
        switch server.status {
        case .unknown: .secondary
        case .online: .green
        case .offline: .red
        case .maintenance: .orange
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, point) in arrangement.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: min(maxWidth, max(0, x - spacing)), height: y + rowHeight), points)
    }
}
