import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.favorites.isEmpty {
                    ContentUnavailableView(
                        "Пока пусто",
                        systemImage: "heart",
                        description: Text("Сохраняйте товары, чтобы быстро вернуться к ним")
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(store.favorites) { listing in
                        NavigationLink {
                            ListingDetailView(seed: listing)
                        } label: {
                            ListingRow(listing: listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(AppColor.paper)
        .navigationTitle("Избранное")
        .refreshable { await store.loadFavorites() }
    }
}
