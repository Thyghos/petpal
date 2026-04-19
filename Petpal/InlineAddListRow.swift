// Shared “Add …” row for list-style screens (matches inset list + card rows).

import SwiftUI

struct InlineAddListRow: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("BrandOrange"))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color("BrandOrange"))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
