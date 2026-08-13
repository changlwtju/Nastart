import SwiftUI

struct SectionHeader: View {
    let titleKey: LocalizedStringKey
    var trailingKey: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .nastartSectionTitle()
            Spacer()
            if let trailingKey {
                Text(trailingKey)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
    }
}
