/// Uygulamanın premium özellikleri. Hangi özelliğin ücretli olduğunu tek listede toplar.
enum PremiumFeature {
    case unlimitedProjects
    case smartAlignment
    case cloudBackup
    case coupleMode
    case highResExport
}

/// Para kazanma (monetization) kurallarının yaşadığı saf, test edilebilir tip.
/// Kuralları arayüze dağıtmak yerine burada toplamak hem testi hem ileride fiyat/limit
/// değişikliklerini kolaylaştırır.
enum FeatureGate {

    /// Ücretsiz katmanda izin verilen en fazla aktif proje sayısı.
    static let freeProjectLimit = 1

    /// Yeni bir proje oluşturulabilir mi?
    static func canCreateProject(isPro: Bool, currentProjectCount: Int) -> Bool {
        isPro || currentProjectCount < freeProjectLimit
    }

    /// Bir premium özellik açık mı? Şimdilik hepsi tek kapıdan (Pro aboneliği) açılır.
    static func isUnlocked(_ feature: PremiumFeature, isPro: Bool) -> Bool {
        isPro
    }
}
