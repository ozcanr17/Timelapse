import Foundation

/// Uygulamanın yasal bağlantıları. App Store, otomatik yenilenen abonelikler için
/// paywall'da Kullanım Koşulları (EULA) ve Gizlilik Politikası bağlantılarını zorunlu
/// tutar (Yönerge 3.1.2).
///
/// ⚠️ YAYINDAN ÖNCE: `privacyPolicy` adresini kendi barındırdığın gerçek gizlilik
/// politikası sayfasıyla değiştir ve App Store Connect'e de aynı adresi gir.
enum LegalLinks {

    /// Apple'ın standart EULA'sı. Kendi özel sözleşmen yoksa bunu kullanabilirsin.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// TODO: Kendi gizlilik politikan URL'i ile değiştir (ör. GitHub Pages / kendi siten).
    static let privacyPolicy = URL(string: "https://ozcanr17.github.io/Timelapse/privacy")!

    /// Destek / iletişim adresi (App Store Connect'te de istenir).
    static let support = URL(string: "https://ozcanr17.github.io/Timelapse/support")!
}
