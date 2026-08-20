import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Каталог", systemImage: "square.grid.2x2") }
                .tag(AppTab.catalog)

            NavigationStack { StoresMapView() }
                .tabItem { Label("Карта", systemImage: "map") }
                .tag(AppTab.map)

            NavigationStack { FavoritesView() }
                .tabItem { Label("Избранное", systemImage: "heart") }
                .badge(store.favorites.count)
                .tag(AppTab.favorites)

            NavigationStack { BookingsView() }
                .tabItem { Label("Брони", systemImage: "bookmark") }
                .badge(store.activeReservationCount)
                .tag(AppTab.bookings)

            NavigationStack { ProfileView() }
                .tabItem { Label("Профиль", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .overlay(alignment: .top) {
            if let message = store.bannerMessage {
                BannerView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }
}

struct BannerView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(AppColor.ink, in: Capsule())
            .shadow(radius: 12, y: 6)
            .padding(.horizontal)
    }
}
