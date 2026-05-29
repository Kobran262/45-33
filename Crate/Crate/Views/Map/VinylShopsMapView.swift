import SwiftUI
import SwiftData
import MapKit

struct VinylShopsMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \UserVinylStore.updatedAt, order: .reverse) private var userStores: [UserVinylStore]

    @StateObject private var locationService = LocationService()
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.0, longitude: 20.0),
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        )
    )

    @State private var osmStores: [VinylShop] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var addCoordinate = CLLocationCoordinate2D(latitude: 44.0, longitude: 20.0)
    @State private var showAddStore = false
    @State private var hasCenteredOnUser = false
    @State private var fetchTask: Task<Void, Never>?
    @State private var visibleRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.0, longitude: 20.0),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
    @State private var lastFetchedRegionSignature: String?

    private var visibleUserStores: [UserVinylStore] {
        userStores.filter { !$0.isDeleted }
    }

    private var mapPins: [MapShopPin] {
        osmStores.map(MapShopPin.osm) + visibleUserStores.map(MapShopPin.user)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapArea
                messageArea
                storesList
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Винил рядом")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        prepareAddStore()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(AppTheme.gold)

                    Button {
                        refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(AppTheme.gold)
                }
            }
            .onAppear { refresh() }
            .onReceive(locationService.$currentLocation.compactMap { $0 }) { coord in
                handleLocation(coord)
            }
            .sheet(isPresented: $showAddStore) {
                AddVinylStoreView(coordinate: addCoordinate)
            }
            .onDisappear {
                fetchTask?.cancel()
            }
        }
    }

    private var mapArea: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(mapPins) { pin in
                    Marker(pin.title, systemImage: pin.systemImage, coordinate: pin.coordinate)
                        .tint(pin.tint)
                }
            }
            .mapStyle(.standard)
            .frame(height: 350)
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                addCoordinate = context.region.center
                fetch(region: context.region)
            }

            if loading {
                ProgressView()
                    .tint(AppTheme.gold)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(AppTheme.bg)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.gold)
                        .clipShape(Circle())
                }

                Text("OSM · \(osmStores.count)")
                Text("Мои · \(visibleUserStores.count)")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(AppTheme.inkMuted)
            .padding(9)
            .background(AppTheme.panel.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 52)
            .padding(.trailing, 10)
        }
    }

    @ViewBuilder
    private var messageArea: some View {
        if let errorText {
            Text(errorText)
                .font(.callout)
                .foregroundStyle(AppTheme.red)
                .padding()
        } else {
            Text("Кнопка + добавляет твою метку. Сейчас она хранится локально, но уже имеет syncID и статус для будущей общей карты.")
                .font(.caption)
                .foregroundStyle(AppTheme.inkFaint)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    private var storesList: some View {
        List {
            if visibleUserStores.isEmpty && osmStores.isEmpty && !loading {
                Text("Магазины не найдены — попробуй обновить или добавь свою метку.")
                    .foregroundStyle(AppTheme.inkFaint)
                    .listRowBackground(AppTheme.bg)
            }

            if !visibleUserStores.isEmpty {
                Section("Мои метки") {
                    ForEach(visibleUserStores) { store in
                        UserStoreRow(store: store) {
                            softDelete(store)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            centerOnStore(
                                CLLocationCoordinate2D(latitude: store.latitude, longitude: store.longitude)
                            )
                        }
                        .listRowBackground(AppTheme.bg)
                    }
                }
            }

            if !osmStores.isEmpty {
                Section("OpenStreetMap") {
                    ForEach(osmStores) { shop in
                        Button {
                            centerOnStore(shop.coordinate)
                        } label: {
                            OSMStoreRow(shop: shop)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppTheme.bg)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
    }

    private func refresh() {
        errorText = nil
        locationService.requestPermission()
        locationService.refreshLocation()
        fetch(region: visibleRegion, force: true)
    }

    private func handleLocation(_ coordinate: CLLocationCoordinate2D, forceFetch: Bool = false) {
        addCoordinate = coordinate
        if !hasCenteredOnUser {
            centerOnUser()
            hasCenteredOnUser = true
        }
        if forceFetch {
            fetch(region: visibleRegion, force: true)
        }
    }

    private func centerOnUser() {
        guard let coord = locationService.currentLocation else {
            cameraPosition = .userLocation(
                followsHeading: false,
                fallback: .region(
                    MKCoordinateRegion(
                        center: addCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                    )
                )
            )
            return
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
            )
        }
    }

    private func centerOnStore(_ coordinate: CLLocationCoordinate2D) {
        addCoordinate = coordinate
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: max(visibleRegion.span.latitudeDelta * 0.55, 0.008),
                        longitudeDelta: max(visibleRegion.span.longitudeDelta * 0.55, 0.008)
                    )
                )
            )
        }
    }

    private func prepareAddStore() {
        showAddStore = true
    }

    private func fetch(region: MKCoordinateRegion, force: Bool = false) {
        let signature = regionSignature(region)
        if !force, signature == lastFetchedRegionSignature {
            return
        }

        fetchTask?.cancel()
        errorText = nil

        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                loading = true
            }

            do {
                let found = try await OverpassService.shared.fetchShops(
                    in: region,
                    userLocation: locationService.currentLocation
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    osmStores = found
                    lastFetchedRegionSignature = signature
                    loading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorText = "Не удалось быстро получить магазины. Попробуй обновить или добавить метку вручную."
                    loading = false
                }
            }
        }
    }

    private func regionSignature(_ region: MKCoordinateRegion) -> String {
        let lat = (region.center.latitude * 200).rounded() / 200
        let lon = (region.center.longitude * 200).rounded() / 200
        let latSpan = (region.span.latitudeDelta * 100).rounded() / 100
        let lonSpan = (region.span.longitudeDelta * 100).rounded() / 100
        return "\(lat):\(lon):\(latSpan):\(lonSpan)"
    }

    private func softDelete(_ store: UserVinylStore) {
        store.isDeleted = true
        store.syncStatus = .pendingDelete
        store.updatedAt = .now
        try? modelContext.save()
    }
}

private struct MapShopPin: Identifiable {
    enum Source {
        case osm
        case user
    }

    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let source: Source

    var systemImage: String {
        switch source {
        case .osm: "music.note"
        case .user: "star.fill"
        }
    }

    var tint: Color {
        switch source {
        case .osm: AppTheme.gold
        case .user: AppTheme.green
        }
    }

    static func osm(_ shop: VinylShop) -> MapShopPin {
        MapShopPin(
            id: "osm-\(shop.id)",
            title: shop.name,
            coordinate: CLLocationCoordinate2D(latitude: shop.latitude, longitude: shop.longitude),
            source: .osm
        )
    }

    static func user(_ store: UserVinylStore) -> MapShopPin {
        MapShopPin(
            id: "user-\(store.syncID)",
            title: store.name,
            coordinate: CLLocationCoordinate2D(latitude: store.latitude, longitude: store.longitude),
            source: .user
        )
    }
}

private struct OSMStoreRow: View {
    let shop: VinylShop

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(shop.name)
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            if let distance = shop.distanceMeters {
                Text("~ \(Int(distance)) м")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkMuted)
            }
            if let address = shop.address {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
            }
            if let opening = shop.openingHours {
                Text(opening)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct UserStoreRow: View {
    let store: UserVinylStore
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundStyle(AppTheme.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                if !store.address.isEmpty {
                    Text(store.address)
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkMuted)
                }
                Text("sync: \(store.syncStatusRaw)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.inkFaint)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddVinylStoreView: View {
    let coordinate: CLLocationCoordinate2D

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var note = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Магазин") {
                    TextField("Название", text: $name)
                    TextField("Адрес", text: $address)
                    TextField("Заметка", text: $note, axis: .vertical)
                }

                Section("Координаты") {
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.decimalPad)
                    Text("По умолчанию берём текущую геопозицию симулятора/телефона. Позже сюда можно добавить drag-pin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(AppTheme.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            .navigationTitle("Новая метка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }.tint(AppTheme.gold)
                }
            }
            .onAppear {
                latitudeText = String(format: "%.6f", coordinate.latitude)
                longitudeText = String(format: "%.6f", coordinate.longitude)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorText = "Укажи название магазина."
            return
        }

        let lat = Double(latitudeText.replacingOccurrences(of: ",", with: "."))
        let lon = Double(longitudeText.replacingOccurrences(of: ",", with: "."))
        guard let lat, let lon, (-90...90).contains(lat), (-180...180).contains(lon) else {
            errorText = "Проверь координаты."
            return
        }

        let store = UserVinylStore(
            name: cleanName,
            latitude: lat,
            longitude: lon,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(store)
        try? modelContext.save()
        dismiss()
    }
}
