import SwiftUI

@main
struct CustomerApp: App {
    @StateObject private var store = MarketplaceStore(api: APIClient.live)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(AppColor.accent)
                .task { await store.bootstrap() }
        }
    }
}
