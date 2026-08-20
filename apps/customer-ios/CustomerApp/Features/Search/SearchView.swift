import PhotosUI
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.isLoading {
                    ProgressView("Ищем предложения…").padding(.top, 40)
                } else if store.searchResults.isEmpty {
                    ContentUnavailableView(
                        store.searchText.isEmpty ? "Найдите товар" : "Ничего не найдено",
                        systemImage: "magnifyingglass",
                        description: Text("Сравним цены и наличие в магазинах рядом")
                    )
                    .padding(.top, 36)
                } else {
                    ForEach(store.searchResults) { listing in
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
        .navigationTitle("Поиск")
        .searchable(text: $store.searchText, prompt: "Название товара")
        .onSubmit(of: .search) { Task { await store.search() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera")
                }
                .accessibilityLabel("Поиск по фотографии")
            }
        }
        .onChange(of: selectedPhoto) {
            guard selectedPhoto != nil else { return }
            store.show("Поиск по фото будет подключён к сервису распознавания")
        }
    }
}

struct ListingRow: View {
    @EnvironmentObject private var store: MarketplaceStore
    let listing: Listing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let first = listing.imageUrls.first, let url = URL(string: first) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
                } else {
                    placeholder
                }
            }
            .frame(width: 86, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 5) {
                Text(listing.title).font(.subheadline.weight(.bold)).foregroundStyle(AppColor.ink)
                Text(listing.storeName ?? "")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                Text(listing.formattedPrice).font(.headline).foregroundStyle(AppColor.ink)
                Text(listing.stockLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(listing.availableStock > 2 ? AppColor.success : AppColor.warning)
            }
            Spacer()
            Button {
                Task { await store.toggleFavorite(listing) }
            } label: {
                Image(systemName: store.isFavorite(listing.id) ? "heart.fill" : "heart")
                    .foregroundStyle(AppColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .appCard()
    }

    private var placeholder: some View {
        Image(systemName: listing.categoryIcon ?? "shippingbox")
            .font(.title)
            .foregroundStyle(AppColor.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.primaryTint)
    }
}
