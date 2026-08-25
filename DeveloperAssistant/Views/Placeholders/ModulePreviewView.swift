import SwiftUI

struct ModulePreviewView: View {
    let module: AppModule
    let navigation: AppNavigationModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 18) {
                    Image(systemName: module.systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(.quaternary, in: .rect(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(module.title)
                            .font(.largeTitle.weight(.semibold))
                        Text("macOS 原生功能预览")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(module.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("计划能力")
                        .font(.headline)
                    ForEach(module.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "checkmark.circle")
                    }
                }
                .padding(24)
                .frame(maxWidth: 620, alignment: .leading)
                .modernGlassCard()

                Button("返回首页", systemImage: "arrow.left") {
                    navigation.open(.home)
                }
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(module.title)
    }
}
