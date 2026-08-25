import SwiftUI

struct ProjectsAndTagsView: View {
    let store: DNSStore

    @State private var projectName = ""
    @State private var tagName = ""
    @State private var projectToDelete: UUID?
    @State private var tagToDelete: UUID?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("项目与标签")
                        .font(.largeTitle.weight(.semibold))
                    Text("项目用于单一归属，标签用于跨项目组合筛选。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 18) {
                    managementCard(
                        title: "项目",
                        subtitle: "每个域名可归属一个项目",
                        systemImage: "folder",
                        text: $projectName,
                        items: store.projects.map { project in
                            ManagedCategory(
                                id: project.id,
                                name: project.name,
                                count: store.domains.filter { $0.projectID == project.id }.count
                            )
                        },
                        add: addProject,
                        delete: { projectToDelete = $0 }
                    )

                    managementCard(
                        title: "标签",
                        subtitle: "每个域名可添加多个标签",
                        systemImage: "tag",
                        text: $tagName,
                        items: store.tags.map { tag in
                            ManagedCategory(id: tag.id, name: tag.name, count: store.tagLinks.filter { $0.tagID == tag.id }.count)
                        },
                        add: addTag,
                        delete: { tagToDelete = $0 }
                    )
                }
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("项目与标签")
        .confirmationDialog(
            "删除项目？",
            isPresented: Binding(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除项目", role: .destructive) { deleteProject() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("项目中的域名将变为未分类，DNS 数据不会受影响。")
        }
        .confirmationDialog(
            "删除标签？",
            isPresented: Binding(get: { tagToDelete != nil }, set: { if !$0 { tagToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除标签", role: .destructive) { deleteTag() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该标签会从所有域名移除，DNS 数据不会受影响。")
        }
        .errorAlert(message: $errorMessage)
    }

    private func managementCard(
        title: String,
        subtitle: String,
        systemImage: String,
        text: Binding<String>,
        items: [ManagedCategory],
        add: @escaping () -> Void,
        delete: @escaping (UUID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                TextField("新建\(title)名称", text: text)
                    .textFieldStyle(.darkBorder)
                    .onSubmit(add)
                Button("添加", systemImage: "plus", action: add)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            if items.isEmpty {
                ContentUnavailableView("还没有\(title)", systemImage: systemImage)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: systemImage)
                                .foregroundStyle(.tint)
                                .frame(width: 22)
                            Text(item.name)
                            Spacer()
                            Text("\(item.count) 个域名")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("删除", systemImage: "trash", role: .destructive) {
                                delete(item.id)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 10)
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modernGlassCard()
    }

    private func addProject() {
        do {
            try store.createProject(name: projectName)
            projectName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addTag() {
        do {
            try store.createTag(name: tagName)
            tagName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteProject() {
        guard let projectToDelete else { return }
        do { try store.deleteProject(id: projectToDelete) }
        catch { errorMessage = error.localizedDescription }
        self.projectToDelete = nil
    }

    private func deleteTag() {
        guard let tagToDelete else { return }
        do { try store.deleteTag(id: tagToDelete) }
        catch { errorMessage = error.localizedDescription }
        self.tagToDelete = nil
    }
}

private struct ManagedCategory: Identifiable {
    let id: UUID
    let name: String
    let count: Int
}
