import SwiftUI
import SwiftData
import PhotosUI

struct RecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("privateModeEnabled") private var privateModeEnabled = false

    @Bindable var record: VinylRecord
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var shelfRecords: [VinylRecord]
    @Query(sort: \WishlistEntry.addedAt, order: .reverse) private var wishlist: [WishlistEntry]
    @State private var photoItem: PhotosPickerItem?
    @State private var showCameraSheet = false
    @State private var showShowcaseSheet = false
    @State private var artistReleases: [DiscogsSearchResult] = []
    @State private var isLoadingArtistReleases = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                coverHeader

                VStack(spacing: 6) {
                    Text(record.title)
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                    Text(record.artist)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkMuted)
                }
                .padding(.horizontal, 20)

                tags

                metaPanel
                storyBlock
                artistDiscographyBlock
                actionButtons
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Карточка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showShowcaseSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(AppTheme.gold)

                NavigationLink {
                    EditRecordView(record: record)
                } label: {
                    Image(systemName: "pencil")
                }
                .tint(AppTheme.gold)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(newItem) }
        }
        .sheet(isPresented: $showCameraSheet) {
            CameraView { image in
                if let data = image.jpegData(compressionQuality: 0.7) {
                    record.photoData = compress(data)
                    try? modelContext.save()
                }
                showCameraSheet = false
            }
        }
        .sheet(isPresented: $showShowcaseSheet) {
            ShowcaseRecordView(record: record)
        }
        .task(id: record.artist) {
            await loadArtistReleases()
        }
    }

    private var coverHeader: some View {
        VStack(spacing: 12) {
            RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 10)

            HStack(spacing: 14) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Из галереи", systemImage: "photo.on.rectangle")
                        .font(.system(size: 11, design: .monospaced))
                }
                .tint(AppTheme.gold)

                Button {
                    showCameraSheet = true
                } label: {
                    Label("Снять", systemImage: "camera")
                        .font(.system(size: 11, design: .monospaced))
                }
                .tint(AppTheme.gold)

                if record.photoData != nil {
                    Button(role: .destructive) {
                        record.photoData = nil
                        try? modelContext.save()
                    } label: {
                        Label("Убрать", systemImage: "trash")
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
        }
    }

    private var tags: some View {
        WrapLayout(spacing: 6) {
            ForEach(record.tags + (record.isFavorite ? ["любимое"] : []), id: \.self) { tag in
                GoldChip(text: tag, active: tag == "любимое" && record.isFavorite)
            }
        }
        .padding(.horizontal, 20)
    }

    private var metaPanel: some View {
        VStack(spacing: 0) {
            row(label: "Лейбл", value: record.label.isEmpty ? "—" : record.label)
            divider
            row(label: "Жанры", value: genresText)
            divider
            row(label: "Прессинг", value: record.pressing)
            divider
            row(label: "Состояние") { Text(record.grade.display).foregroundStyle(AppTheme.green) }
            divider
            row(label: "Цвет винила", value: record.vinylColor.label)
            divider
            row(label: "Цена покупки") {
                Text(priceText)
                    .foregroundStyle(AppTheme.gold)
            }
            if let purchasedAtText {
                divider
                row(label: "Куплено", value: purchasedAtText)
            }
            if !record.purchaseLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                divider
                row(label: "Где куплено", value: record.purchaseLocation)
            }
        }
        .padding(.horizontal, 14)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var genresText: String {
        let values = record.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "—" && $0.localizedCaseInsensitiveCompare("любимое") != .orderedSame }
        return values.isEmpty ? "—" : values.joined(separator: ", ")
    }

    private var purchasedAtText: String? {
        guard let date = record.purchasedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private func row(label: String, value: String) -> some View {
        row(label: label) { Text(value).foregroundStyle(AppTheme.ink) }
    }

    private func row<Trailing: View>(label: String, @ViewBuilder _ trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
            Spacer()
            trailing()
                .font(.system(size: 12))
        }
        .padding(.vertical, 9)
    }

    private var divider: some View {
        Rectangle().fill(AppTheme.rowLine).frame(height: 1)
    }

    private var storyBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("история".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            if privateModeEnabled {
                Text("история скрыта")
                    .italic()
                    .foregroundStyle(AppTheme.inkMuted)
                    .font(.system(.callout, design: .serif))
            } else if record.story.isEmpty {
                Text("История пока не добавлена.")
                    .italic()
                    .foregroundStyle(AppTheme.inkMuted)
                    .font(.system(.callout, design: .serif))
            } else {
                Text(record.story)
                    .italic()
                    .foregroundStyle(AppTheme.inkSoft)
                    .font(.system(.callout, design: .serif))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var priceText: String {
        guard !record.formattedPrice.isEmpty else { return "—" }
        return privateModeEnabled ? "\(record.currency)••• приватно" : "\(record.formattedPrice) · приватно"
    }

    private var artistDiscographyBlock: some View {
        Group {
            if isLoadingArtistReleases {
                ProgressView()
                    .tint(AppTheme.gold)
                    .padding(.vertical, 10)
            } else if artistReleases.count >= 3 {
                VStack(alignment: .leading, spacing: 10) {
                    Text(discographyTitle.uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.inkFaint)

                    ForEach(artistReleases.prefix(12)) { release in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(release.parsedAlbum)
                                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .lineLimit(1)
                                Text(release.yearInt.map(String.init) ?? "год неизвестен")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.inkMuted)
                            }
                            Spacer()
                            discographyStatus(for: release)
                        }
                    }
                }
                .padding(14)
                .background(AppTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
        }
    }

    private var discographyTitle: String {
        discographyCompletion >= 0.7 ? "Почти полная дискография" : "Что ещё есть у артиста"
    }

    private var discographyCompletion: Double {
        guard !artistReleases.isEmpty else { return 0 }
        let owned = artistReleases.filter { isOnShelf($0) }.count
        return Double(owned) / Double(artistReleases.count)
    }

    @ViewBuilder
    private func discographyStatus(for release: DiscogsSearchResult) -> some View {
        if isOnShelf(release) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.green)
        } else if isInWishlist(release) {
            Image(systemName: "heart.fill")
                .foregroundStyle(AppTheme.gold)
        } else {
            Button {
                modelContext.insert(WishlistEntry(
                    title: release.parsedAlbum,
                    artist: release.parsedArtist,
                    year: release.yearInt
                ))
                try? modelContext.save()
            } label: {
                Image(systemName: "heart")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.inkMuted)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    record.isFavorite.toggle()
                    try? modelContext.save()
                } label: {
                    Label(record.isFavorite ? "в любимом" : "в любимое",
                          systemImage: record.isFavorite ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity)
                }
                .tint(record.isFavorite ? AppTheme.gold : AppTheme.inkMuted)

                NavigationLink {
                    ShowcaseRecordView(record: record)
                } label: {
                    Label("витрина", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .tint(AppTheme.gold)
            }

            Button(role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
                dismiss()
            } label: {
                Label("снять с полки", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .buttonStyle(.bordered)
    }

    @MainActor
    private func loadArtistReleases() async {
        guard artistReleases.isEmpty else { return }
        isLoadingArtistReleases = true
        defer { isLoadingArtistReleases = false }
        artistReleases = (try? await DiscogsService.shared.searchArtist(name: record.artist)) ?? []
    }

    private func isOnShelf(_ release: DiscogsSearchResult) -> Bool {
        shelfRecords.contains {
            $0.artist.localizedCaseInsensitiveCompare(release.parsedArtist) == .orderedSame &&
            $0.title.localizedCaseInsensitiveCompare(release.parsedAlbum) == .orderedSame
        }
    }

    private func isInWishlist(_ release: DiscogsSearchResult) -> Bool {
        wishlist.contains {
            $0.artist.localizedCaseInsensitiveCompare(release.parsedArtist) == .orderedSame &&
            $0.title.localizedCaseInsensitiveCompare(release.parsedAlbum) == .orderedSame
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        record.photoData = compress(data)
        try? modelContext.save()
    }

    private func compress(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxSide: CGFloat = 800
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.72) ?? data
    }
}

/// Камера через UIImagePickerController — простой способ снять фото
struct CameraView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onImage(img)
            }
        }
    }
}

struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}
