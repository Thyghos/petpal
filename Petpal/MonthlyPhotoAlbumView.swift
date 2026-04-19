// One month’s photo album for the active pet (Highlights).

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import PhotosUI

struct MonthlyPhotoAlbumView: View {
    @Environment(\.modelContext) private var modelContext
    let pet: Pet
    let month: Int
    let year: Int

    @Query private var allPhotos: [PetMonthlyPhoto]

    @State private var pickerPresented = false
    @State private var selectedPhotoSheet: MonthlyPhotoSheetItem?
    @State private var pendingDelete: PetMonthlyPhoto?

    private var displayName: String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your pet" : n
    }

    private var monthTitle: String {
        let idx = max(0, min(11, month - 1))
        return DateFormatter().monthSymbols[idx]
    }

    private var photosForMonth: [PetMonthlyPhoto] {
        allPhotos.filter { $0.petId == pet.id && $0.month == month && $0.year == year }
            .sorted { $0.addedDate < $1.addedDate }
    }

    private var photoCount: Int { photosForMonth.count }
    private var atMonthlyPhotoLimit: Bool { photoCount >= 30 }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if photosForMonth.isEmpty {
                ContentUnavailableView {
                    Label("No photos yet", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("No photos yet for this month. Add your favorites!")
                } actions: {
                    Button("Add Photo") { pickerPresented = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !atMonthlyPhotoLimit && photoCount > 0 {
                            Text(photoCount < 10 ? "\(photoCount) photos · Tap + to add more" : "\(photoCount) photos")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        if !atMonthlyPhotoLimit {
                            InlineAddListRow(title: "Add Photo") { pickerPresented = true }
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(photosForMonth, id: \.id) { p in
                                photoCell(p)
                            }
                        }
                        if atMonthlyPhotoLimit {
                            Text("30 photos this month · Delete some to add more")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("\(displayName)'s \(monthTitle) \(year)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !atMonthlyPhotoLimit {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { pickerPresented = true }
                }
            }
        }
        .sheet(isPresented: $pickerPresented) {
            MonthlyPhotoPickerSheet { images in
                addPhotos(images)
            }
        }
        .sheet(item: $selectedPhotoSheet) { item in
            MonthlyPhotoZoomSheet(photo: item.photo)
        }
        .confirmationDialog("Delete this photo?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let p = pendingDelete {
                    modelContext.delete(p)
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private func photoCell(_ p: PetMonthlyPhoto) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Group {
                    if let ui = UIImage(data: p.photoData) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .clipped()
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                selectedPhotoSheet = MonthlyPhotoSheetItem(photo: p)
            }
            .onLongPressGesture {
                pendingDelete = p
            }
    }

    private func addPhotos(_ images: [UIImage]) {
        let startCount = photosForMonth.count
        let remaining = max(0, 30 - startCount)
        for img in images.prefix(remaining) {
            guard let data = img.jpegData(compressionQuality: 0.88) else { continue }
            let row = PetMonthlyPhoto(petId: pet.id, month: month, year: year, photoData: data)
            modelContext.insert(row)
        }
        try? modelContext.save()
    }
}

private struct MonthlyPhotoSheetItem: Identifiable {
    var id: UUID { photo.id }
    let photo: PetMonthlyPhoto
}

private struct MonthlyPhotoZoomSheet: View {
    let photo: PetMonthlyPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()
            if let ui = UIImage(data: photo.photoData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 1), 6)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .padding()
        }
        .presentationBackground(.black)
        .presentationDragIndicator(.visible)
    }
}

/// PHPicker-based multi-select.
private struct MonthlyPhotoPickerSheet: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 20
        let p = PHPickerViewController(configuration: config)
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        init(onComplete: @escaping ([UIImage]) -> Void) { self.onComplete = onComplete }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            var images: [UIImage] = []
            let group = DispatchGroup()
            for r in results {
                group.enter()
                if r.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    r.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                        defer { group.leave() }
                        if let img = obj as? UIImage {
                            images.append(img)
                        }
                    }
                } else {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.onComplete(images)
            }
        }
    }
}
#endif
