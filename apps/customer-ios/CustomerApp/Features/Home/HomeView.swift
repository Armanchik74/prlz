import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MarketplaceStore
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                brand

                NavigationLink {
                    SearchView()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Что ищете рядом?")
                            .foregroundStyle(AppColor.muted)
                        Spacer()
                        Image(systemName: "camera")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .padding(6)
                    .padding(.leading, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.08))
                    }
                }
                .buttonStyle(.plain)

                sectionTitle("Категории", trailing: "\(store.categories.count)")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.categories) { category in
                        Button {
                            Task { await store.loadStores(category: category.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                    .foregroundStyle(Color(hex: category.color))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: category.color).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                Text(category.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColor.ink)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
                            .padding(15)
                            .appCard()
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionTitle("Магазины рядом", trailing: "\(store.stores.count)")
                ForEach(store.stores.prefix(8)) { item in
                    NavigationLink {
                        StoreDetailView(storeID: item.id)
                    } label: {
                        StoreRow(store: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(AppColor.paper)
        .refreshable { await store.bootstrap() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var brand: some View {
        HStack(spacing: 11) {
            Image(systemName: "location.fill.viewfinder")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("ЕСТЬ РЯДОМ")
                    .font(.headline.weight(.heavy))
                Label("Челябинск", systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
        }
    }

    private func sectionTitle(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(AppColor.muted)
        }
    }
}

struct StoreRow: View {
    let store: Store

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront")
                .font(.title3)
                .foregroundStyle(AppColor.primary)
                .frame(width: 46, height: 46)
                .background(AppColor.primaryTint, in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(store.name).font(.subheadline.weight(.bold))
                    if store.plan == "business" {
                        Label("ТОП", systemImage: "bolt.fill")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(AppColor.accent)
                    }
                }
                HStack(spacing: 5) {
                    Label(store.rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                    if let distance = store.distanceKm { Text("· \(distance.formatted()) км") }
                    if store.isVerified { Text("· Проверен") }
                }
                .font(.caption)
                .foregroundStyle(AppColor.muted)
                Text(store.address)
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(AppColor.muted)
        }
        .padding(13)
        .appCard()
    }
}
