import SwiftUI

struct SectionHeader: View {
    let titleKey: LocalizedStringKey
    var trailingKey: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.headline.weight(.semibold))
            Spacer()
            if let trailingKey {
                Text(trailingKey)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }
}
