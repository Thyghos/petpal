// Bottom sheet: choose camera, photo library, or PDF import.

#if os(iOS)

import SwiftUI

struct ImportSourcePickerSheet: View {
    var title: String
    var subtitle: String
    var onTakePhoto: () -> Void
    var onChooseFromLibrary: () -> Void
    var onImportPDF: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color("BrandDark"))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    importCard(
                        title: "Take a Photo",
                        subtitle: "Point your camera at the document",
                        systemImage: "camera.fill",
                        gradient: [Color("BrandOrange"), Color("BrandOrange").opacity(0.65)],
                        action: onTakePhoto
                    )
                    importCard(
                        title: "Choose from Photos",
                        subtitle: "Select an existing photo",
                        systemImage: "photo.fill",
                        gradient: [Color("BrandBlue"), Color("BrandBlue").opacity(0.65)],
                        action: onChooseFromLibrary
                    )
                    importCard(
                        title: "Import PDF",
                        subtitle: "Import a PDF file",
                        systemImage: "doc.badge.arrow.up",
                        gradient: [Color("BrandPurple"), Color("BrandPurple").opacity(0.65)],
                        action: onImportPDF
                    )
                }

                Button("Cancel", role: .cancel, action: onCancel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func importCard(
        title: String,
        subtitle: String,
        systemImage: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color("BrandDark"))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#endif
