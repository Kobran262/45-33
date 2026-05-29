import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @Query private var collections: [SavedCollection]

    @State private var name: String = ""
    @State private var handle: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    avatar
                    statsTrio
                    chart
                    settings
                }
                .padding(.vertical, 14)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }.tint(AppTheme.gold)
                }
            }
            .onAppear { syncFromProfile() }
        }
    }

    private var avatar: some View {
        VStack(spacing: 10) {
            Text(profileOrSeed().avatarLetter)
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.bg)
                .frame(width: 70, height: 70)
                .background(AppTheme.gold)
                .clipShape(Circle())

            VStack(spacing: 8) {
                TextField("Имя", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Ник", text: $handle)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }
            .padding(.horizontal, 32)
        }
    }

    private var statsTrio: some View {
        HStack(spacing: 8) {
            statBox("\(records.count)", "пластинок")
            statBox("€\(Int(totalInvested))", "вложено")
            statBox("\(collections.count + 4)", "коллекций")
        }
        .padding(.horizontal, 20)
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.gold)
            Text(label.uppercased())
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var chart: some View {
        let stats = decadeBars()
        return VStack(alignment: .leading, spacing: 8) {
            Text("статистика коллекции".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(stats.enumerated()), id: \.offset) { idx, val in
                    Rectangle()
                        .fill(idx == 2 ? AppTheme.gold : AppTheme.goldSoft)
                        .frame(height: max(4, CGFloat(val) * 46))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 46)

            Text("по десятилетиям")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var settings: some View {
        VStack(spacing: 0) {
            settingsRow("О приложении", icon: "chevron.right")
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            settingsRow("Экспорт коллекции (JSON)", icon: "square.and.arrow.up")
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            settingsRow("Очистить все данные", icon: "trash", color: AppTheme.red, onTap: clearAll)
        }
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func settingsRow(_ title: String, icon: String, color: Color = AppTheme.inkSoft, onTap: (() -> Void)? = nil) -> some View {
        Button {
            onTap?()
        } label: {
            HStack {
                Text(title).foregroundStyle(color)
                Spacer()
                Image(systemName: icon).foregroundStyle(AppTheme.inkFaint)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var totalInvested: Double {
        records.reduce(0) { $0 + $1.price }
    }

    private func decadeBars() -> [Double] {
        var by: [Int: Int] = [50: 0, 60: 0, 70: 0, 80: 0, 90: 0, 0: 0]
        for r in records {
            let d = (r.year / 10) * 10
            let key = d % 100
            if by[key] != nil { by[key]! += 1 }
        }
        let max = by.values.max() ?? 1
        return [50, 60, 70, 80, 90, 0].map { Double(by[$0] ?? 0) / Double(Swift.max(1, max)) }
    }

    private func profileOrSeed() -> UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile(name: "Marko", handle: "marko.collects", memberSince: 2024, avatarLetter: "M")
        modelContext.insert(p)
        try? modelContext.save()
        return p
    }

    private func syncFromProfile() {
        let p = profileOrSeed()
        if name.isEmpty { name = p.name }
        if handle.isEmpty { handle = p.handle }
    }

    private func save() {
        let p = profileOrSeed()
        if !name.isEmpty { p.name = name }
        if !handle.isEmpty { p.handle = handle.replacingOccurrences(of: "@", with: "") }
        p.avatarLetter = String(p.name.prefix(1)).uppercased()
        try? modelContext.save()
        dismiss()
    }

    private func clearAll() {
        for r in records { modelContext.delete(r) }
        for c in collections { modelContext.delete(c) }
        try? modelContext.save()
    }
}
