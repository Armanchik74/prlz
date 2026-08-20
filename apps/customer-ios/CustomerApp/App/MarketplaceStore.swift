import Foundation

@MainActor
final class MarketplaceStore: ObservableObject {
    @Published var selectedTab: AppTab = .catalog
    @Published private(set) var categories: [Category] = []
    @Published private(set) var stores: [Store] = []
    @Published private(set) var favorites: [Listing] = []
    @Published private(set) var reservations: [Reservation] = []
    @Published private(set) var profile: UserProfile?
    @Published private(set) var searchResults: [Listing] = []
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published var bannerMessage: String?

    let location = LocationProvider()
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var activeReservationCount: Int { reservations.filter(\.isActive).count }

    func bootstrap() async {
        location.request()
        isLoading = true
        defer { isLoading = false }
        async let categoriesTask: Void = loadCategories()
        async let storesTask: Void = loadStores()
        async let favoritesTask: Void = loadFavorites()
        async let reservationsTask: Void = loadReservations()
        async let profileTask: Void = loadProfile()
        _ = await (categoriesTask, storesTask, favoritesTask, reservationsTask, profileTask)
    }

    func loadCategories() async {
        do {
            let response: CollectionResponse<Category> = try await api.get("categories")
            categories = response.items
        } catch { show(error.localizedDescription) }
    }

    func loadStores(category: UUID? = nil) async {
        var query = [
            URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(location.coordinate.longitude))
        ]
        if let category { query.append(URLQueryItem(name: "category", value: category.uuidString)) }
        do {
            let response: CollectionResponse<Store> = try await api.get("stores", query: query)
            stores = response.items
        } catch { show(error.localizedDescription) }
    }

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: SearchResponse = try await api.get("listings/search", query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
                URLQueryItem(name: "lon", value: String(location.coordinate.longitude))
            ])
            searchResults = response.items
        } catch { show(error.localizedDescription) }
    }

    func storeDetail(id: UUID) async throws -> StoreDetail {
        try await api.get("stores/\(id.uuidString)")
    }

    func listingDetail(id: UUID) async throws -> Listing {
        try await api.get("listings/\(id.uuidString)")
    }

    func loadFavorites() async {
        do {
            let response: CollectionResponse<Listing> = try await api.get("favorites", authenticated: true)
            favorites = response.items
        } catch { show(error.localizedDescription) }
    }

    func isFavorite(_ id: UUID) -> Bool { favorites.contains { $0.id == id } }

    func toggleFavorite(_ listing: Listing) async {
        do {
            if isFavorite(listing.id) {
                try await api.sendEmpty("favorites/\(listing.id.uuidString)", method: "DELETE", body: Optional<String>.none)
                favorites.removeAll { $0.id == listing.id }
                show("Убрано из избранного")
            } else {
                try await api.sendEmpty("favorites/\(listing.id.uuidString)", method: "PUT", body: Optional<String>.none)
                favorites.insert(listing, at: 0)
                show("Добавлено в избранное")
            }
        } catch { show(error.localizedDescription) }
    }

    func reserve(_ listing: Listing) async {
        do {
            let _: Reservation = try await api.send(
                "reservations",
                method: "POST",
                body: ReservationRequest(listingId: listing.id, quantity: 1)
            )
            await loadReservations()
            selectedTab = .bookings
            show("Бронь оформлена на 2 часа")
        } catch { show(error.localizedDescription) }
    }

    func loadReservations() async {
        do {
            let response: CollectionResponse<Reservation> = try await api.get("reservations", authenticated: true)
            reservations = response.items
        } catch { show(error.localizedDescription) }
    }

    func cancel(_ reservation: Reservation) async {
        do {
            try await api.sendEmpty("reservations/\(reservation.id.uuidString)", method: "DELETE", body: Optional<String>.none)
            await loadReservations()
            show("Бронь отменена")
        } catch { show(error.localizedDescription) }
    }

    func loadProfile() async {
        do {
            profile = try await api.get("me", authenticated: true)
        } catch { show(error.localizedDescription) }
    }

    func saveProfile(name: String, phone: String) async -> Bool {
        do {
            profile = try await api.send("me", method: "PUT", body: ProfileRequest(name: name, phone: phone))
            show("Профиль сохранён")
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func deleteAccount() async -> Bool {
        do {
            try await api.sendEmpty("me", method: "DELETE", body: Optional<String>.none)
            profile = nil
            favorites = []
            reservations = []
            show("Аккаунт удалён")
            return true
        } catch {
            show(error.localizedDescription)
            return false
        }
    }

    func show(_ message: String) {
        bannerMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if bannerMessage == message { bannerMessage = nil }
        }
    }
}
