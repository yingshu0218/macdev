import SwiftUI

struct AppShortcutCard: View {
    let module: AppModule
    let metrics: [AppShortcutMetric]
    let open: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: module.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(module.availability == .ready ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 48, height: 48)
                        .background(.quaternary, in: .rect(cornerRadius: 14))

                    Spacer()

                    AvailabilityBadge(availability: module.availability)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(module.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(module.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 0) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.value)
                                .font(.title3.weight(.semibold))
                                .contentTransition(.numericText())
                            Text(metric.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 2)

                HStack {
                    Text(module.availability == .ready ? "打开工作台" : "查看功能预览")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
            .contentShape(.rect(cornerRadius: 20))
            .scaleEffect(isHovering ? 1.012 : 1)
            .modernGlassCard(interactive: true)
            .animation(.snappy(duration: 0.18), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityHint("打开\(module.title)")
    }
}

struct AppShortcutMetric: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private struct AvailabilityBadge: View {
    let availability: ModuleAvailability

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(availability == .ready ? .green : .secondary)
                .frame(width: 6, height: 6)
            Text(availability.title)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }
}
