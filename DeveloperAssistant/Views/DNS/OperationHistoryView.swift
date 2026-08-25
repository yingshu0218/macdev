import SwiftUI

struct OperationHistoryView: View {
    let store: DNSStore

    @State private var selectedOperationID: UUID?
    @State private var restoringOperationID: UUID?
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("操作历史")
                        .font(.title2.weight(.semibold))
                    Text("记录同步、解析变更与恢复结果；可恢复成功的解析变更。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isRestoring { ProgressView().controlSize(.small) }
                Button("恢复所选操作", systemImage: "arrow.uturn.backward") {
                    restoringOperationID = selectedOperationID
                }
                .disabled(!canRestoreSelection || isRestoring)
            }
            .padding(20)

            Divider()

            if store.operations.isEmpty {
                ContentUnavailableView(
                    "还没有操作记录",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("同步域名或修改解析后，记录会显示在这里。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(store.operations, selection: $selectedOperationID) {
                    TableColumn("时间") { operation in
                        Text(operation.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .width(min: 125, ideal: 140, max: 150)
                    TableColumn("操作") { operation in
                        Label(operation.action.title, systemImage: operationIcon(operation.action))
                    }
                    .width(min: 115, ideal: 130, max: 145)
                    TableColumn("域名", value: \.domainName)
                        .width(min: 145, ideal: 170, max: 195)
                    TableColumn("账号") { operation in
                        Text(store.account(id: operation.accountID)?.name ?? "已删除账号")
                            .foregroundStyle(store.account(id: operation.accountID) == nil ? .secondary : .primary)
                    }
                    .width(min: 105, ideal: 125, max: 145)
                    TableColumn("状态") { operation in
                        Label(operation.status.title, systemImage: statusIcon(operation.status))
                            .foregroundStyle(statusColor(operation.status))
                    }
                    .width(90)
                    TableColumn("结果", value: \.message)
                        .width(min: 150, ideal: 195, max: 230)
                }
                .contextMenu(forSelectionType: UUID.self) { selected in
                    if let id = selected.first,
                       let operation = store.operations.first(where: { $0.id == id }),
                       store.canRestore(operation) {
                        Button("恢复这次变更", systemImage: "arrow.uturn.backward") {
                            restoringOperationID = id
                        }
                    }
                }
            }
        }
        .navigationTitle("操作历史")
        .confirmationDialog(
            "恢复这次 DNS 变更？",
            isPresented: Binding(
                get: { restoringOperationID != nil },
                set: { if !$0 { restoringOperationID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("确认恢复") { restore() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将向 DNS 服务商发起一次新的变更，把解析恢复到操作前的状态。恢复结果也会写入操作历史。")
        }
        .errorAlert(message: $errorMessage)
    }

    private var canRestoreSelection: Bool {
        guard let selectedOperationID,
              let operation = store.operations.first(where: { $0.id == selectedOperationID }) else { return false }
        return store.canRestore(operation)
    }

    private func restore() {
        guard let restoringOperationID else { return }
        isRestoring = true
        Task {
            do {
                try await store.restore(operationID: restoringOperationID)
                selectedOperationID = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isRestoring = false
            self.restoringOperationID = nil
        }
    }

    private func operationIcon(_ action: DNSOperationAction) -> String {
        switch action {
        case .createRecord: "plus.circle"
        case .updateRecord: "pencil.circle"
        case .deleteRecord: "trash.circle"
        case .restore: "arrow.uturn.backward.circle"
        case .syncDomains, .syncRecords: "arrow.trianglehead.2.clockwise"
        }
    }

    private func statusIcon(_ status: DNSOperationStatus) -> String {
        switch status {
        case .pending: "clock.fill"
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: DNSOperationStatus) -> Color {
        switch status {
        case .pending: .blue
        case .success: .green
        case .failed: .red
        }
    }
}
