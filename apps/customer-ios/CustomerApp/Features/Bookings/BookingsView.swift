import SwiftUI

struct BookingsView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.reservations.isEmpty {
                    ContentUnavailableView(
                        "Пока нет броней",
                        systemImage: "bookmark",
                        description: Text("Забронируйте товар — он будет ждать вас 2 часа")
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(store.reservations) { reservation in
                        ReservationCard(reservation: reservation)
                    }
                }
            }
            .padding()
        }
        .background(AppColor.paper)
        .navigationTitle("Мои брони")
        .refreshable { await store.loadReservations() }
    }
}

private struct ReservationCard: View {
    @EnvironmentObject private var store: MarketplaceStore
    let reservation: Reservation

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(reservation.title ?? "Товар").font(.headline)
                Spacer()
                Text(reservation.formattedPrice).font(.headline)
            }
            Text([reservation.storeName, reservation.storeAddress].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(AppColor.muted)

            HStack {
                Circle()
                    .fill(reservation.isActive ? AppColor.warning : AppColor.muted)
                    .frame(width: 7, height: 7)
                Text(statusText).font(.caption.weight(.semibold))
            }

            if reservation.isActive {
                Text(timerInterval: Date()...max(Date(), reservation.expiresAt), countsDown: true)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColor.muted)
                HStack {
                    if let phone = reservation.phonePublic,
                       let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                        Link("Позвонить", destination: url).buttonStyle(.bordered)
                    }
                    Button("Отменить", role: .destructive) {
                        Task { await store.cancel(reservation) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .appCard()
    }

    private var statusText: String {
        switch reservation.status {
        case "pending": "Ожидает подтверждения"
        case "confirmed": "Подтверждено · ждём вас"
        case "completed": "Получено"
        case "cancelled": "Отменено"
        case "declined": "Отклонено продавцом"
        default: "Срок брони истёк"
        }
    }
}
