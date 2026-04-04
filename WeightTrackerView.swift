import SwiftUI
import SwiftData
import UIKit

struct WeightTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetWeightEntry.entryDate, order: .reverse) private var entries: [PetWeightEntry]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var entryDate = Date()
    @State private var weightText = ""
    @State private var unit: WeightUnit = .lbs
    @State private var selectedEntryId: UUID?
    @State private var entryToEdit: PetWeightEntry?
    @State private var showingAddEntry = false
    @State private var pendingDelete: PetWeightEntry?
    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif

    private var scopedPetId: UUID? { FeaturePetScope.resolvedPetId(pets: pets) }

    private var scopedEntries: [PetWeightEntry] {
        guard let pid = scopedPetId else { return [] }
        return entries.filter { $0.petId == pid }
    }

    var body: some View {
        NavigationStack {
            weightTrackerRoot
                .navigationTitle("Weight Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .accessibilityHint("Returns to the home screen")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            dismissDecimalKeyboard()
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
        #if os(iOS)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        #endif
        .sheet(isPresented: $showingAddEntry, onDismiss: {
            weightText = ""
        }) {
            WeightAddEntrySheet(
                unit: $unit,
                weightText: $weightText,
                entryDate: $entryDate,
                onSave: { addEntry() }
            )
        }
        .sheet(item: $entryToEdit) { entry in
            WeightEntryEditSheet(entry: entry, unit: $unit, onDelete: { deleteWeightEntry(entry) })
        }
        .confirmationDialog(
            "Delete this weight entry?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let e = pendingDelete {
                    deleteWeightEntry(e)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    @ViewBuilder
    private var weightTrackerRoot: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeaturePetScopeHeader(pets: pets)
            weightTrackerHeader
            weightTrackerForm
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var weightTrackerHeader: some View {
        Text("Track your pet’s weight over time.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 4)
    }

    /// Chart fixed on top; history scrolls; + opens add sheet (UIKit field not embedded in main scroll).
    @ViewBuilder
    private var weightTrackerForm: some View {
        VStack(spacing: 0) {
            trendBlock
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if scopedEntries.isEmpty {
                        emptyEntriesSection
                    } else {
                        entriesBlock
                        sharePrintBlock
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.never)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            addEntryPlusBar
                .padding(.vertical, 12)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
        }
    }

    private var addEntryPlusBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                weightText = ""
                entryDate = Date()
                showingAddEntry = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 52))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color("BrandBlue"))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add weigh-in")
            Spacer(minLength: 0)
        }
    }

    private var emptyEntriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)
                .foregroundStyle(Color("BrandDark"))
            ContentUnavailableView {
                Label("No entries yet", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Tap + below to add your first weigh-in.")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private var trendBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend")
                .font(.headline)
                .foregroundStyle(Color("BrandDark"))
            Picker("Units", selection: $unit) {
                Text("lbs").tag(WeightUnit.lbs)
                Text("kg").tag(WeightUnit.kg)
                Text("g").tag(WeightUnit.g)
            }
            .pickerStyle(.segmented)
            if scopedEntries.isEmpty {
                Text("Your pet’s weight line will appear here after the first entry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            WeightChartWithAxes(
                entries: scopedEntries,
                unit: unit,
                selectedEntryId: $selectedEntryId,
                plotHeight: 220
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private var entriesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entries (\(scopedEntries.count))")
                .font(.headline)
                .foregroundStyle(Color("BrandDark"))
            VStack(spacing: 0) {
                ForEach(Array(scopedEntries.enumerated()), id: \.element.id) { index, e in
                    WeightEntryRowView(
                        entry: e,
                        weightLabel: displayWeight(for: e),
                        isSelected: selectedEntryId == e.id,
                        onTapRow: {
                            selectedEntryId = selectedEntryId == e.id ? nil : e.id
                        },
                        onEdit: { entryToEdit = e },
                        onDelete: { pendingDelete = e }
                    )
                    if index < scopedEntries.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 4)
            Text("Tap a row to highlight it on the chart. Use the menu to edit or delete.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var sharePrintBlock: some View {
        #if os(iOS)
        VStack(spacing: 12) {
            Button {
                let printable = WeightTrackerPrintableView(entries: scopedEntries, unit: unit)
                    .preferredColorScheme(.light)
                if let img = PrintShareHelper.renderToImage(printable) {
                    let text = "Weight tracker — \(scopedEntries.count) entr\(scopedEntries.count == 1 ? "y" : "ies")"
                    DispatchQueue.main.async {
                        sharePayload = ShareSheetPayload(items: [img, text])
                    }
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                let printable = WeightTrackerPrintableView(entries: scopedEntries, unit: unit)
                DispatchQueue.main.async {
                    PrintShareHelper.printView(printable, title: "Weight Tracker")
                }
            } label: {
                Label("Print", systemImage: "printer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
        #else
        EmptyView()
        #endif
    }

    private func dismissDecimalKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var parsedWeight: Double? {
        let raw = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(raw), v > 0 else { return nil }
        return v
    }

    private func addEntry() {
        guard let v = parsedWeight else { return }
        let kg = unit.toKg(v)
        let entry = PetWeightEntry(petId: scopedPetId, entryDate: entryDate, weightKg: kg)
        modelContext.insert(entry)
        try? modelContext.save()
        weightText = ""
        showingAddEntry = false
        dismissDecimalKeyboard()
    }

    private func deleteWeightEntry(_ e: PetWeightEntry) {
        if selectedEntryId == e.id { selectedEntryId = nil }
        if entryToEdit?.id == e.id { entryToEdit = nil }
        modelContext.delete(e)
        try? modelContext.save()
    }

    private func displayWeight(for entry: PetWeightEntry) -> String {
        let v = unit.value(fromKg: entry.weightKg)
        return String(format: "%.1f %@", v, unit.shortSymbol)
    }
}

private struct WeightEntryRowView: View {
    let entry: PetWeightEntry
    let weightLabel: String
    let isSelected: Bool
    let onTapRow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack {
                Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text(weightLabel)
                    .fontWeight(.semibold)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTapRow)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Highlights this weigh-in on the chart")

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Edit or delete")
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color("BrandSoftBlue").opacity(0.35) : Color.clear)
        )
    }
}

private struct WeightAddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var unit: WeightUnit
    @Binding var weightText: String
    @Binding var entryDate: Date
    var onSave: () -> Void

    private var parsedWeight: Double? {
        let raw = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(raw), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        DecimalWeightTextField(
                            text: $weightText,
                            placeholder: unit.placeholderExample
                        )
                        .frame(height: 40)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Picker("Unit", selection: $unit) {
                            Text("lbs").tag(WeightUnit.lbs)
                            Text("kg").tag(WeightUnit.kg)
                            Text("g").tag(WeightUnit.g)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                DatePicker("Date", selection: $entryDate, displayedComponents: .date)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("New weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityHint("Returns to the weight graph and entries")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(parsedWeight == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .scrollDismissesKeyboard(.never)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct WeightEntryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: PetWeightEntry
    @Binding var unit: WeightUnit
    let onDelete: () -> Void

    @State private var draftDate = Date()
    @State private var draftWeightText = ""
    @State private var showDeleteConfirm = false

    private var parsedWeight: Double? {
        let raw = draftWeightText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(raw), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            editForm
        }
    }

    private var editWeightInputRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DecimalWeightTextField(
                text: $draftWeightText,
                placeholder: unit.placeholderExample
            )
            .frame(minHeight: 44, alignment: .center)
            .frame(maxWidth: .infinity)
            Picker("Unit", selection: $unit) {
                Text("lbs").tag(WeightUnit.lbs)
                Text("kg").tag(WeightUnit.kg)
                Text("g").tag(WeightUnit.g)
            }
            .pickerStyle(.segmented)
        }
    }

    private var editForm: some View {
        Form {
            Section {
                editWeightInputRow
                DatePicker("Date", selection: $draftDate, displayedComponents: .date)
            }
            Section {
                Button("Save") { save() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedWeight == nil)
            }
            Section {
                Button("Delete Entry", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .accessibilityHint("Returns to the weight graph and entries")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .scrollDismissesKeyboard(.never)
        .onAppear {
            draftDate = entry.entryDate
            draftWeightText = formatDraftWeight(entry: entry, unit: unit)
        }
        .onChange(of: unit) { oldUnit, newUnit in
            guard let v = parseWeightValue(from: draftWeightText) else { return }
            let kg = oldUnit.toKg(v)
            let newDisplay = newUnit.value(fromKg: kg)
            draftWeightText = String(format: "%.1f", newDisplay)
        }
        .confirmationDialog(
            "Delete this weight entry?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func save() {
        guard let v = parsedWeight else { return }
        let kg = unit.toKg(v)
        entry.entryDate = draftDate
        entry.weightKg = kg
        try? modelContext.save()
        dismiss()
    }

    private func formatDraftWeight(entry: PetWeightEntry, unit: WeightUnit) -> String {
        let v = unit.value(fromKg: entry.weightKg)
        return String(format: "%.1f", v)
    }

    private func parseWeightValue(from text: String) -> Double? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(raw), v > 0 else { return nil }
        return v
    }
}

enum WeightUnit: String, CaseIterable {
    case lbs
    case kg
    case g

    /// Canonical storage is kg; convert to the unit shown in the UI.
    func value(fromKg kg: Double) -> Double {
        switch self {
        case .lbs: return kg / 0.453_592_37
        case .kg: return kg
        case .g: return kg * 1000
        }
    }

    /// User-entered value in this unit → kilograms for `PetWeightEntry.weightKg`.
    func toKg(_ display: Double) -> Double {
        switch self {
        case .lbs: return display * 0.453_592_37
        case .kg: return display
        case .g: return display / 1000
        }
    }

    var shortSymbol: String {
        switch self {
        case .lbs: return "lbs"
        case .kg: return "kg"
        case .g: return "g"
        }
    }

    var placeholderExample: String {
        switch self {
        case .lbs: return "e.g. 45.2"
        case .kg: return "e.g. 20.5"
        case .g: return "e.g. 450"
        }
    }
}

private struct WeightChartWithAxes: View {
    let entries: [PetWeightEntry]
    let unit: WeightUnit
    @Binding var selectedEntryId: UUID?
    /// Height of the plot area (axis labels draw inside this).
    var plotHeight: CGFloat = 220

    private var chron: [PetWeightEntry] {
        entries.sorted { $0.entryDate < $1.entryDate }
    }

    private func yValue(_ e: PetWeightEntry) -> Double {
        unit.value(fromKg: e.weightKg)
    }

    private func weightLabel(_ value: Double) -> String {
        String(format: "%.1f %@", value, unit.shortSymbol)
    }

    private func dateRange(for pts: [PetWeightEntry]) -> (min: Date, max: Date) {
        guard let first = pts.first, let last = pts.last else {
            return (Date(), Date())
        }
        if pts.count == 1 {
            let d = first.entryDate
            return (d.addingTimeInterval(-86_400), d.addingTimeInterval(86_400))
        }
        let raw = last.entryDate.timeIntervalSince(first.entryDate)
        let pad = max(raw * 0.04, 86_400 * 0.25)
        return (first.entryDate.addingTimeInterval(-pad), last.entryDate.addingTimeInterval(pad))
    }

    private func yRange(values: [Double]) -> (min: Double, max: Double) {
        guard let lo = values.min(), let hi = values.max() else { return (0, 1) }
        let span = max(hi - lo, 0.000_1)
        let minPad: Double = {
            switch unit {
            case .kg: return 0.2
            case .lbs: return 0.5
            case .g: return max(5, span * 0.02)
            }
        }()
        let pad = max(span * 0.12, minPad)
        return (lo - pad, hi + pad)
    }

    private func yTickValues(minY: Double, maxY: Double) -> [Double] {
        guard maxY > minY else { return [minY] }
        let n = 4
        return (0..<n).map { i in
            minY + (maxY - minY) * Double(i) / Double(n - 1)
        }
    }

    private func weightChartPlot(in geo: GeometryProxy) -> some View {
        let pts = chron
        let values = pts.map(yValue)
        let (tMin, tMax) = dateRange(for: pts)
        let (yMin, yMax) = yRange(values: values)
        let yTicks = yTickValues(minY: yMin, maxY: yMax)

        let left: CGFloat = 52
        let bottom: CGFloat = 26
        let topPad: CGFloat = 6
        let rightPad: CGFloat = 8
        let plotW = geo.size.width - left - rightPad
        let plotH = geo.size.height - topPad - bottom

        let t0 = tMin.timeIntervalSinceReferenceDate
        let t1 = tMax.timeIntervalSinceReferenceDate
        let denom = max(t1 - t0, 1)

        let xLabelDates: [Date] = {
            if pts.isEmpty { return [] }
            if pts.count == 1 { return [pts[0].entryDate] }
            let mid = Date(timeIntervalSinceReferenceDate: (t0 + t1) / 2)
            return [tMin, mid, tMax].sorted()
        }()

        func formatAxisDate(_ d: Date) -> String {
            let span = tMax.timeIntervalSince(tMin)
            let cal = Calendar.current
            let y1 = cal.component(.year, from: tMin)
            let y2 = cal.component(.year, from: tMax)
            if y1 != y2 || span > 120 * 86_400 {
                return d.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits))
            }
            return d.formatted(.dateTime.month(.abbreviated).day())
        }

        func xPos(_ date: Date) -> CGFloat {
            let u = (date.timeIntervalSinceReferenceDate - t0) / denom
            return left + CGFloat(u) * plotW
        }

        func yPos(_ w: Double) -> CGFloat {
            let u = (w - yMin) / (yMax - yMin)
            return topPad + (1 - CGFloat(u)) * plotH
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
                .frame(width: geo.size.width, height: geo.size.height)

            Path { p in
                p.move(to: CGPoint(x: left, y: topPad))
                p.addLine(to: CGPoint(x: left, y: topPad + plotH))
                p.addLine(to: CGPoint(x: left + plotW, y: topPad + plotH))
            }
            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
            .allowsHitTesting(false)

            ForEach(yTicks, id: \.self) { yv in
                let yy = yPos(yv)
                Path { p in
                    p.move(to: CGPoint(x: left, y: yy))
                    p.addLine(to: CGPoint(x: left + plotW, y: yy))
                }
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
            }

            if pts.count >= 2 {
                Path { p in
                    for (i, e) in pts.enumerated() {
                        let pt = CGPoint(x: xPos(e.entryDate), y: yPos(yValue(e)))
                        if i == 0 { p.move(to: pt) }
                        else { p.addLine(to: pt) }
                    }
                }
                .stroke(Color("BrandBlue"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
            } else if let e = pts.first {
                Path { p in
                    let pt = CGPoint(x: xPos(e.entryDate), y: yPos(yValue(e)))
                    p.move(to: pt)
                    p.addLine(to: pt)
                }
                .stroke(Color("BrandBlue"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
            }

            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: plotW, height: plotH)
                .position(x: left + plotW / 2, y: topPad + plotH / 2)
                .onTapGesture { selectedEntryId = nil }

            ForEach(pts) { e in
                let cx = xPos(e.entryDate)
                let cy = yPos(yValue(e))
                let isSel = selectedEntryId == e.id
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                    Circle()
                        .fill(isSel ? Color("BrandBlue").opacity(0.25) : Color(.systemBackground))
                        .frame(width: 12, height: 12)
                    Circle()
                        .stroke(Color("BrandBlue"), lineWidth: isSel ? 3 : 2)
                        .frame(width: 12, height: 12)
                }
                .position(x: cx, y: cy)
                .onTapGesture { selectedEntryId = e.id }
            }

            ForEach(Array(yTicks.enumerated()), id: \.offset) { _, yv in
                Text(String(format: "%.1f %@", yv, unit.shortSymbol))
                    .font(.system(size: 8))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: left - 4, alignment: .trailing)
                    .position(x: (left - 4) / 2, y: yPos(yv))
                    .allowsHitTesting(false)
            }

            ForEach(Array(xLabelDates.enumerated()), id: \.offset) { _, d in
                Text(formatAxisDate(d))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 44)
                    .position(x: xPos(d), y: topPad + plotH + bottom / 2)
                    .allowsHitTesting(false)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let id = selectedEntryId, let e = chron.first(where: { $0.id == id }) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color("BrandBlue"))
                    Text(e.entryDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(weightLabel(yValue(e)))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Selected weigh-in")
            }

            GeometryReader { geo in
                weightChartPlot(in: geo)
            }
            .frame(height: plotHeight)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Weight chart")
        }
    }
}

private struct WeightTrackerPrintableView: View {
    let entries: [PetWeightEntry]
    let unit: WeightUnit

    private var chron: [PetWeightEntry] {
        entries.sorted { $0.entryDate < $1.entryDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weight Tracker")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.black)
            Divider()
            WeightChartWithAxes(entries: chron, unit: unit, selectedEntryId: .constant(nil))
                .frame(height: 220)
                .allowsHitTesting(false)
            Divider()
            ForEach(chron.reversed().prefix(15)) { e in
                HStack {
                    Text(e.entryDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Text(String(format: "%.1f %@", unit.value(fromKg: e.weightKg), unit.shortSymbol))
                    .foregroundStyle(Color.black)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color.white)
        .preferredColorScheme(.light)
    }
}

// MARK: - UIKit decimal field (SwiftUI TextField + Form/List is unreliable for focus/keyboard on some iPhones)

private struct DecimalWeightTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
        tf.textContentType = nil
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.clearButtonMode = .whileEditing
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.delegate = context.coordinator
        tf.font = .preferredFont(forTextStyle: .body)
        tf.isUserInteractionEnabled = true
        tf.accessibilityLabel = "Weight"
        tf.setContentHuggingPriority(.defaultHigh, for: .vertical)
        tf.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isEditing, uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DecimalWeightTextField
        var isEditing = false

        init(_ parent: DecimalWeightTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isEditing = false
            parent.text = textField.text ?? ""
        }
    }
}

