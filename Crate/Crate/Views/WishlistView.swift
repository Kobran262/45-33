import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistEntry.addedAt, order: .reverse) private var wishlist: [WishlistEntry]

    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("в розыске · \(wishlist.count)".uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(AppTheme.inkFaint)
                    Text("Вишлист")
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("То, за чем ты охотишься.")
                        .italic()
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(AppTheme.inkFaint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerPanel)
                        .stroke(AppTheme.panelLine, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerPanel))
                .padding(.horizontal, 16)

                HStack {
                    Text("хочу найти".uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(AppTheme.inkFaint)
                    Spacer()
                    Button { showAdd = true } label: {
                        Text("＋ добавить")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .tint(AppTheme.gold)
                }
                .padding(.horizontal, 20)

                if wishlist.isEmpty {
                    Text(VoiceContent.phrase(.emptyWishlist))
                        .font(.callout)
                        .foregroundStyle(AppTheme.inkFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(wishlist) { item in
                            WishlistRow(item: item) {
                                moveToShelf(item)
                            } onRemove: {
                                modelContext.delete(item)
                                try? modelContext.save()
                            }
                            Rectangle().fill(AppTheme.rowLine).frame(height: 1).padding(.leading, 60)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) {
            AddSingleView(mode: .wishlist)
        }
    }

    private func moveToShelf(_ item: WishlistEntry) {
        let record = VinylRecord(
            title: item.title,
            artist: item.artist,
            year: item.year ?? 1970,
            coverColorHex: "#5a4a7a",
            tags: ["рок"]
        )
        modelContext.insert(record)
        modelContext.delete(item)
        try? modelContext.save()
    }
}

struct WishlistRow: View {
    let item: WishlistEntry
    let onMove: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(AppTheme.panelLine, style: StrokeStyle(lineWidth: 1, dash: [3]))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(item.artist)\(item.year.map { " · \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
            }

            Spacer()

            Button(action: onMove) {
                Image(systemName: "heart.fill").foregroundStyle(AppTheme.gold)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark").foregroundStyle(AppTheme.inkFaint)
            }
        }
        .padding(.vertical, 10)
    }
}
