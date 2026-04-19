// PDFImportLoadingView.swift
// Non-dismissible progress while a PDF is read and parsed (vet or shelter flow).

import SwiftUI

struct PDFImportLoadingView: View {
    /// Primary line, e.g. "Reading your vet record..." or "Reading your shelter record..."
    var primaryMessage: String = "Reading your vet record..."
    /// Secondary reassurance line.
    var subMessage: String = "This usually takes a few seconds"

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.15)
            Text(primaryMessage)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(subMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(24)
    }
}
