import SwiftUI

struct StoreDetailView: View {
    @EnvironmentObject private var marketplace: MarketplaceStore
    let storeID: UUID
    @State private var detail: StoreDetail?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if let detail {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(detail.name).font(.title2.weight(.bold))
                            if detail.isVerified {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(AppColor.primary)
                            }
                            Spacer()
                            if detail.plan == "business" {
                                Label("ТОП", systemImage: "bolt.fill")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(AppColor.accent)
                            }
                        }
                        Text(detail.description).foregroundStyle(AppColor.muted)
                        Label(detail.address, systemImage: "mappin.and.ellipse")
                        Label(detail.openingHours, systemImage: "clock")
                        Label("\(detail.rating.formatted(.number.precision(.fractionLength(1)))) · \(detail.reviewCount) отзывов", systemImage: "star.fill")
                        if let url = URL(string: "tel:\(detail.phonePublic.filter { $0.isNumber || $0 == "+" })") {
                            Link(destination: url) {
                                Label("Позвонить · \(detail.phonePublic)", systemImage: "phone.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(13)
                                    .foregroundStyle(.white)
                                    .background(AppColor.accent, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                    .appCard()

                    Text("Товары магазина").font(.headline)
                    ForEach(detail.listings) { listing in
                        NavigationLink {
                            ListingDetailView(seed: listing)
                        } label: {
                            ListingRow(listing: listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            } else if let errorMessage {
                ContentUnavailableView("Не удалось открыть магазин", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    .padding(.top, 60)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(AppColor.paper)
        .navigationTitle("Магазин")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { detail = try await marketplace.storeDetail(id: storeID) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

struct ListingDetailView: View {
    @EnvironmentObject private var store: MarketplaceStore
    let seed: Listing
    @State private var listing: Listing
    @State private var showingReservation = false

    init(seed: Listing) {
        self.seed = seed
        _listing = State(initialValue: seed)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Group {
                    if let first = listing.imageUrls.first, let url = URL(string: first) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { heroPlaceholder }
                    } else {
                        heroPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack(alignment: .top) {
                    Text(listing.title).font(.title2.weight(.bold))
                    Spacer()
                    Button {
                        Task { await store.toggleFavorite(listing) }
                    } label: {
                        Image(systemName: store.isFavorite(listing.id) ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(AppColor.accent)
                    }
                }
                Text(listing.formattedPrice).font(.title2.weight(.heavy))
                Text(listing.stockLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(listing.availableStock > 2 ? AppColor.success : AppColor.warning)

                if !listing.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(listing.tags, id: \.self) {
                                Text($0).font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(AppColor.primaryTint, in: Capsule())
                            }
                        }
                    }
                }
                Text(listing.description).foregroundStyle(AppColor.muted)

                if let name = listing.storeName {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(name, systemImage: "storefront.fill").font(.headline)
                        if let address = listing.storeAddress { Text(address).font(.subheadline).foregroundStyle(AppColor.muted) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .appCard()
                }

                Button {
                    showingReservation = true
                } label: {
                    Label("Забронировать на 2 часа", systemImage: "bookmark.fill")
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .foregroundStyle(.white)
                        .background(AppColor.accent, in: RoundedRectangle(cornerRadius: 13))
                }
                .disabled(listing.availableStock <= 0)
                .opacity(listing.availableStock <= 0 ? 0.5 : 1)
            }
            .padding()
        }
        .background(AppColor.paper)
        .navigationTitle("Товар")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Подтвердить бронирование?", isPresented: $showingReservation, titleVisibility: .visible) {
            Button("Забронировать") { Task { await store.reserve(listing) } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Оплата на месте. Магазин подтвердит бронь, она действует 2 часа.")
        }
        .task {
            if listing.storeName == nil, let loaded = try? await store.listingDetail(id: seed.id) {
                listing = loaded
            }
        }
    }

    private var heroPlaceholder: some View {
        Image(systemName: listing.categoryIcon ?? "shippingbox.fill")
            .font(.system(size: 62))
            .foregroundStyle(AppColor.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.primaryTint)
    }
}
