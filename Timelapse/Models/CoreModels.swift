import Foundation
import SwiftData

// MARK: - Enum'lar

/// Projenin neyi takip ettiğini belirtir. String tabanlı olduğu için SwiftData ve
/// CloudKit bunu sorunsuz saklar; CaseIterable sayesinde arayüzde seçim listesi
/// olarak gösterebiliriz.
enum ProjectCategory: String, Codable, CaseIterable, Identifiable {
    case selfPortrait = "self"
    case child
    case plant
    case hairAndBeard = "hair_beard"
    case pet
    case other

    var id: String { rawValue }

    /// Kullanıcıya gösterilecek okunabilir ad. (switch-as-expression: Swift 5.9+)
    var displayName: String {
        switch self {
        case .selfPortrait: "Kendim"
        case .child:        "Çocuk"
        case .plant:        "Bitki"
        case .hairAndBeard: "Saç & Sakal"
        case .pet:          "Evcil hayvan"
        case .other:        "Diğer"
        }
    }
}

/// Çekim sıklığı (kadans). Hatırlatıcıların ve "çekim zamanı geldi mi?" mantığının
/// temelini oluşturur.
enum CaptureCadence: String, Codable, CaseIterable, Identifiable {
    case daily
    case everyOtherDay = "every_other_day"
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:         "Her gün"
        case .everyOtherDay: "Gün aşırı"
        case .weekly:        "Haftalık"
        }
    }

    /// İki çekim arasındaki gün sayısı.
    var dayInterval: Int {
        switch self {
        case .daily:         1
        case .everyOtherDay: 2
        case .weekly:        7
        }
    }

    /// Son çekimden sonra bir sonraki çekimin beklendiği gün.
    func nextDueDate(after lastCapture: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayInterval, to: lastCapture) ?? lastCapture
    }

    /// `now` anı itibarıyla yeni bir çekimin zamanı geldi mi?
    ///
    /// `now` ve `calendar` parametre olarak alınır (varsayılanları var). Böylece
    /// üretimde `Date()` ile çağırırız, testte ise sabit bir tarih enjekte ederek
    /// sonucu deterministik (her makinede aynı) hale getiririz. Bu, test edilebilir
    /// kod yazmanın en pratik tekniklerinden biri.
    func isCaptureDue(lastCapture: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        // Hiç çekim yapılmamışsa ilk çekim her zaman beklenebilir.
        guard let lastCapture else { return true }
        let due = nextDueDate(after: lastCapture, calendar: calendar)
        // Saat farklarından etkilenmemek için gün başlangıçlarını karşılaştırıyoruz.
        return calendar.startOfDay(for: now) >= calendar.startOfDay(for: due)
    }
}

// MARK: - Modeller

/// Tek bir çekim: bir fotoğraf + ne zaman çekildiği + hizalama referansı.
@Model
final class Entry {
    // CloudKit eşitlemesi için: her alanın varsayılan değeri var.
    var id: UUID = UUID()
    var capturedAt: Date = Date()

    // Büyük görsel veri kaydın içine gömülmez. `.externalStorage` ile SwiftData
    // bunu ayrı bir dosyaya yazar; CloudKit'e gittiğinde otomatik olarak CKAsset'e
    // dönüşür. Performans ve maliyet için kritik tercih.
    @Attribute(.externalStorage) var imageData: Data?

    // "Ghost" hizalaması için referans noktası. 0...1 aralığında NORMALIZE koordinat
    // tutuyoruz; böylece farklı çözünürlüklerde bile aynı yere denk gelir.
    var anchorX: Double?
    var anchorY: Double?

    // Ait olduğu proje. Ters ilişki (inverse) Project tarafında tanımlı.
    // CloudKit kısıtı gereği optional.
    var project: Project?

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        imageData: Data? = nil,
        anchorX: Double? = nil,
        anchorY: Double? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.imageData = imageData
        self.anchorX = anchorX
        self.anchorY = anchorY
    }
}

/// Bir takip projesi (ör. "Sakal", "Limon fidanı"). Birden çok Entry içerir.
@Model
final class Project {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()

    // SwiftData, Codable enum'ları doğrudan saklayabilir — ayrıca String'e çevirmemize
    // gerek yok. Varsayılan değer CloudKit için gerekli.
    var category: ProjectCategory = ProjectCategory.other
    var cadence: CaptureCadence = CaptureCadence.daily

    // Bir proje silinince çekimleri de silinsin: .cascade.
    // CloudKit kısıtı gereği to-many ilişki optional olmak zorunda.
    @Relationship(deleteRule: .cascade, inverse: \Entry.project)
    var entries: [Entry]? = []

    // MARK: Hesaplanan (computed) yardımcılar — saklanmaz, anlık türetilir.

    /// Çekimler kronolojik sırada (en eski → en yeni). Timelapse bu sırayla üretilir.
    var sortedEntries: [Entry] {
        (entries ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    /// En son çekimin tarihi (hiç yoksa nil).
    var lastCaptureDate: Date? {
        sortedEntries.last?.capturedAt
    }

    /// Bu proje için yeni çekim zamanı geldi mi? Mantığı CaptureCadence'e devrediyoruz.
    func isCaptureDue(now: Date = Date()) -> Bool {
        cadence.isCaptureDue(lastCapture: lastCaptureDate, now: now)
    }

    init(
        id: UUID = UUID(),
        title: String,
        category: ProjectCategory = .other,
        cadence: CaptureCadence = .daily,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.cadence = cadence
        self.createdAt = createdAt
    }
}
