// Sheet: pick which PetMonthlyPhoto represents each month on Year in Review Slide 4.

import SwiftUI
import SwiftData

#if os(iOS)

struct YearInReviewPhotoPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    let year: Int
    let allMonthlyPhotos: [PetMonthlyPhoto]
    @Binding var selectedPhotoIdByMonth: [Int: UUID]

    @State private var monthToPickFrom: Int?

    private func monthName(_ m: Int) -> String {
        guard m >= 1, m <= 12 else { return "Month" }
        return Calendar.current.monthSymbols[m - 1]
    }

    private func photosForMonth(_ month: Int) -> [PetMonthlyPhoto] {
        allMonthlyPhotos
            .filter { $0.petId == pet.id && $0.year == year && $0.month == month }
            .sorted { $0.addedDate < $1.addedDate }
    }

    private func thumbnail(for month: Int) -> UIImage? {
        let id = selectedPhotoIdByMonth[month]
        let pool = photosForMonth(month)
        let photo: PetMonthlyPhoto? = {
            if let id, let p = pool.first(where: { $0.id == id }) { return p }
            return pool.first
        }()
        guard let photo else { return nil }
        return UIImage(data: photo.photoData)
    }

    var body: some View {
        NavigationStack {
            List {
                Text("Select one photo to represent each month in your Year in Review")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                ForEach(1...12, id: \.self) { month in
                    monthRow(month: month)
                }
            }
            .navigationTitle("Choose Monthly Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { monthToPickFrom.map { YIRAlbumPickMonth(month: $0) } },
                set: { monthToPickFrom = $0?.month }
            )) { wrap in
                MonthAlbumPhotoPickSheet(
                    month: wrap.month,
                    monthTitle: monthName(wrap.month),
                    photos: photosForMonth(wrap.month),
                    selectedId: selectedPhotoIdByMonth[wrap.month],
                    onSelect: { picked in
                        if let picked {
                            selectedPhotoIdByMonth[wrap.month] = picked.id
                        }
                        monthToPickFrom = nil
                    },
                    onCancel: { monthToPickFrom = nil }
                )
            }
        }
    }

    @ViewBuilder
    private func monthRow(month: Int) -> some View {
        let pool = photosForMonth(month)
        let hasPhotos = !pool.isEmpty

        HStack(alignment: .center, spacing: 12) {
            Text(monthName(month))
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 120, alignment: .leading)

            Button {
                if hasPhotos { monthToPickFrom = month }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemFill))
                    if let ui = thumbnail(for: month) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipped()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!hasPhotos)

            Spacer(minLength: 8)

            if hasPhotos {
                Button("Change") {
                    monthToPickFrom = month
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color("BrandOrange"))
            } else {
                Text("No photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct YIRAlbumPickMonth: Identifiable {
    let month: Int
    var id: Int { month }
}

/// Pick from existing `PetMonthlyPhoto` rows for that month (Highlights album).
private struct MonthAlbumPhotoPickSheet: View {
    let month: Int
    let monthTitle: String
    let photos: [PetMonthlyPhoto]
    let selectedId: UUID?
    let onSelect: (PetMonthlyPhoto?) -> Void
    let onCancel: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(photos, id: \.id) { p in
                        Button {
                            onSelect(p)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                if let ui = UIImage(data: p.photoData) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.25))
                                        .frame(width: 96, height: 96)
                                }
                                if p.id == selectedId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color("BrandOrange"), Color.white)
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

#endif
