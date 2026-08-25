import SwiftUI

struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let actions: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(title, systemImage: systemImage)
                    .font(.largeTitle.weight(.semibold))

                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(actions, id: \.self) { action in
                        Label(action, systemImage: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
                .frame(maxWidth: 560, alignment: .leading)
                .modernGlassCard()
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(title)
    }
}
