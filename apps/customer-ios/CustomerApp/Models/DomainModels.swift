import CoreLocation
import Foundation

struct CollectionResponse<Item: Decodable>: Decodable {
    let items: [Item]
}

struct SearchResponse: Decodable {
    let query: String
    let items: [Listing]
}

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let icon: String
    let color: String
    let subcategories: [Subcategory]
}

struct Subcategory: Identifiable, Codable, Hashable {
    let id: UUID
    let slug: String
    let name: String
}

struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let address: String
    let phonePublic: String
    let rating: Double
    let reviewCount: Int
    let openingHours: String
    let isVerified: Bool
    let plan: String
    let latitude: Double
    let longitude: Double
    let distanceKm: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct StoreDetail: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String
    let address: String
    let phonePublic: String
    let rating: Double
    let reviewCount: Int
    let openingHours: String
    let isVerified: Bool
    let plan: String
    let latitude: Double
    let longitude: Double
    let listings: [Listing]
}

struct Listing: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let priceMinor: Int
    let currency: String
    let availableStock: Int
    let condition: String
    let tags: [String]
    let imageUrls: [String]
    let storeId: UUID?
    let storeName: String?
    let storeAddress: String?
    let storeRating: Double?
    let isVerified: Bool?
    let plan: String?
    let categoryId: UUID?
    let categoryName: String?
    let categoryIcon: String?
    let distanceKm: Double?
    let phonePublic: String?
    let latitude: Double?
    let longitude: Double?

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: Double(priceMinor) / 100)) ?? "\(priceMinor / 100) ₽"
    }

    var stockLabel: String {
        if availableStock <= 0 { return "Нет в наличии" }
        if availableStock <= 2 { return "Осталось \(availableStock) шт." }
        return "В наличии"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, priceMinor, currency, availableStock, condition, tags, imageUrls
        case storeId, storeName, storeAddress, storeRating, isVerified, plan
        case categoryId, categoryName, categoryIcon, distanceKm, phonePublic, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        priceMinor = try c.decode(Int.self, forKey: .priceMinor)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "RUB"
        availableStock = try c.decodeIfPresent(Int.self, forKey: .availableStock) ?? 0
        condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? "new"
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        imageUrls = try c.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        storeId = try c.decodeIfPresent(UUID.self, forKey: .storeId)
        storeName = try c.decodeIfPresent(String.self, forKey: .storeName)
        storeAddress = try c.decodeIfPresent(String.self, forKey: .storeAddress)
        storeRating = try c.decodeIfPresent(Double.self, forKey: .storeRating)
        isVerified = try c.decodeIfPresent(Bool.self, forKey: .isVerified)
        plan = try c.decodeIfPresent(String.self, forKey: .plan)
        categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
        categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName)
        categoryIcon = try c.decodeIfPresent(String.self, forKey: .categoryIcon)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        phonePublic = try c.decodeIfPresent(String.self, forKey: .phonePublic)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

struct Reservation: Identifiable, Decodable {
    let id: UUID
    let listingId: UUID
    let storeId: UUID
    let quantity: Int
    let unitPriceMinor: Int
    let status: String
    let createdAt: Date
    let expiresAt: Date
    let title: String?
    let imageUrls: [String]?
    let storeName: String?
    let storeAddress: String?
    let phonePublic: String?

    var isActive: Bool { status == "pending" || status == "confirmed" }
    var formattedPrice: String {
        (Double(unitPriceMinor) / 100).formatted(.currency(code: "RUB").precision(.fractionLength(0)))
    }
}

struct UserProfile: Decodable {
    let id: UUID
    let role: String
    let name: String?
    let phone: String?
    let consentVersion: String?
}

struct ReservationRequest: Encodable {
    let listingId: UUID
    let quantity: Int
}

struct ProfileRequest: Encodable {
    let name: String
    let phone: String
}

enum AppTab: Hashable {
    case catalog, map, favorites, bookings, profile
}
