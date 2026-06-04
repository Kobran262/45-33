import SwiftUI
import SwiftData

struct AchievementUnlockedSheet: View {
    let achievements: [Achievement]
    let records: [VinylRecord]
    @Binding var index: Int
    var onDismissAll: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showcaseRecord: VinylRecord?

    private var current: Achievement? {
        guard index >= 0, index < achievements.count else { return nil }
        return achievements[index]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)

                Image(systemName: "seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.gold)
                    .shadow(color: AppTheme.gold.opacity(0.35), radius: 16)

                if let current {
                    Text(AchievementService.title(for: current.kind))
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text(VoiceContent.achievementBody(for: current.kind))
                        .font(.callout)
                        .foregroundStyle(AppTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 10) {
                    if triggerRecord != nil {
                        Button {
                            showcaseRecord = triggerRecord
                        } label: {
                            Text("Сделать витрину")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.gold)
                    }

                    Button {
                        advanceOrClose()
                    } label: {
                        Text(isLast ? "Готово" : "Дальше")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.inkMuted)
                }
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismissAll()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppTheme.inkFaint)
                    }
                }
            }
            .sheet(item: $showcaseRecord) { record in
                ShowcaseRecordView(record: record)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isLast: Bool {
        index >= achievements.count - 1
    }

    private var triggerRecord: VinylRecord? {
        guard let id = current?.recordIdAtUnlock else { return nil }
        return records.first { $0.id == id }
    }

    private func advanceOrClose() {
        if isLast {
            onDismissAll()
            dismiss()
        } else {
            index += 1
        }
    }
}
