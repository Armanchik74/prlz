import MapKit
import SwiftUI

struct StoresMapView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @State private var selectedStoreID: UUID?

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: store.location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        ))) {
            UserAnnotation()
            ForEach(store.stores) { item in
                Annotation(item.name, coordinate: item.coordinate) {
                    Button {
                        selectedStoreID = item.id
                    } label: {
                        Image(systemName: item.plan == "business" ? "bolt.fill" : "storefront.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(item.plan == "business" ? AppColor.accent : AppColor.primary, in: Circle())
                            .shadow(radius: 4, y: 2)
                    }
                }
            }
        }
        .navigationTitle("Магазины на карте")
        .safeAreaInset(edge: .bottom) {
            if let selectedStoreID, let item = store.stores.first(where: { $0.id == selectedStoreID }) {
                NavigationLink {
                    StoreDetailView(storeID: item.id)
                } label: {
                    StoreRow(store: item)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            store.location.request()
            await store.loadStores()
        }
    }
}
