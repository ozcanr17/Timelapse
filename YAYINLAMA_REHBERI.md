# Flapse — App Store Yayınlama Rehberi

Bu doküman, uygulamayı App Store'da yayınlamak için gereken tüm adımları sırayla anlatır.
Teknik ön hazırlık (kod tarafı) tamamlandı: paywall yasal metinleri, hesap silme, isteğe
bağlı giriş, değerlendirme istemi, widget yerelleştirmesi ve `Configuration.storekit`
depoda hazır. Kalan adımların tamamı Apple hesabı gerektiren, insan eliyle yapılacak işler.

---

## 1. Apple Developer Program üyeliği

1. [developer.apple.com](https://developer.apple.com) → `ridvanozcan7@gmail.com` Apple ID'inle
   **Apple Developer Program**'a kayıt ol (yıllık 99 USD). Onay birkaç saat–2 gün sürebilir.
2. Onaylandıktan sonra Xcode → **Settings → Accounts** → Apple ID'ini ekle.
   Takım (`5ZYCHZ39QV`) listede görünmeli.

## 2. Gizlilik sayfaları — ✅ TAMAMLANDI (2026-07-18)

GitHub Pages açıldı (`main` / `/docs`); üç adres de canlı ve Flapse markalı sayfaları sunuyor
(uygulamadaki `LegalLinks` bunlara işaret eder):

- Gizlilik: `https://ozcanr17.github.io/Timelapse/privacy`
- Destek: `https://ozcanr17.github.io/Timelapse/support`
- Site (outro QR kodu): `https://ozcanr17.github.io/Timelapse/`

App Store Connect'e yazılacak adresler bunlardır.

> ⚠️ `https://github.com/ozcanr17/Timelapse/tree/main/docs/privacy` gibi repo adresleri
> **kullanılmaz** — GitHub'ın kod görünümüdür; politika metnini değil dosya listesini gösterir.

Not: Sayfa içerikleri `docs/privacy/index.html` ve `docs/support/index.html` dosyalarından
sunulur; düzenledikten sonra main'e push yeterlidir (Pages 1-2 dakikada yeniden yayınlar).

## 3. Sertifikalar ve imzalama (Xcode halleder)

1. Xcode'da projeyi aç → **Timelapse** target → **Signing & Capabilities**.
2. "Automatically manage signing" işaretli kalsın, Team olarak ücretli hesabı seç.
   Aynısını **Widgets** target için de yap.
3. Ücretli hesapla şu yetenekler artık gerçekten imzalanabilir: Sign in with Apple,
   iCloud/CloudKit (`iCloud.rozcan.Flapse`), Push Notifications, App Groups.
   Hata çıkarsa Capabilities listesinden ilgili satırı silip yeniden eklemek profili tazeler.
4. Gerçek iPhone'da **Release** yapılandırmasıyla bir kez çalıştır
   (Product → Scheme → Edit Scheme → Run → Build Configuration: Release).

## 4. App Store Connect'te uygulamayı oluştur

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps → + → New App**.
2. Platform: iOS · Name: **Flapse** · Primary language: Turkish ·
   Bundle ID: **rozcan.Flapse** · SKU: `flapse-ios`.
3. Bundle ID listede yoksa: [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
   → App IDs → `rozcan.Flapse`'ı kaydet.

## 5. Uygulama içi satın almaları tanımla

App Store Connect → uygulama → **Monetization → Subscriptions / In-App Purchases**:

1. **Abonelik grubu** oluştur: "Flapse Pro".
2. Grup içine iki otomatik yenilenen abonelik — Product ID'ler koddakiyle **birebir** aynı olmalı:
   - `com.ridvan.timelapse.pro.monthly` (1 ay)
   - `com.ridvan.timelapse.pro.yearly` (1 yıl)
3. Her ikisine **Introductory Offer**: 1 hafta, **Free trial**
   (paywall "7 günlük ücretsiz deneme" vaat ediyor — birebir uyuşmalı).
4. **Non-Consumable** ürün: `com.ridvan.timelapse.pro.lifetime`.
5. Her ürüne Türkçe + İngilizce ad/açıklama ve fiyat gir; "Review Information" kısmına
   paywall ekran görüntüsü ekle.
6. IAP'ler ilk sürümle **birlikte** incelemeye girer — sürüm sayfasında üçünü de sürüme iliştir.

**Yayın öncesi cihazsız test:** Xcode → Product → Scheme → Edit Scheme → Run → Options →
**StoreKit Configuration** → depodaki `Configuration.storekit` dosyasını seç; satın alma
akışı sahte mağazayla uçtan uca denenebilir. Gerçek sandbox testi için: App Store Connect →
Users and Access → **Sandbox Testers**'dan test hesabı aç.

## 6. Sürüm sayfasını doldur

1. **Ekran görüntüleri**: 6.9" (iPhone 17 Pro Max) zorunlu. Önerilen kareler: Ana sayfa,
   kamera (ghost overlay), proje detayı, export stüdyosu, Kaydedilenler, paywall.
   Simülatörde `Cmd+S` ile alınır.
2. **Description / Keywords / Promotional Text**: Türkçe + istenen diğer diller.
   (`docs/AppStoreListing.md` taslak metinleri içerir.)
3. **Support URL**: `https://ozcanr17.github.io/Timelapse/support`
   **Privacy Policy URL**: `https://ozcanr17.github.io/Timelapse/privacy`
4. **App Privacy** anketi: **"Data Not Collected"** — uygulamada hiç ağ kodu yok, beyan doğru.
   (CloudKit kullanıcının kendi iCloud'udur; Apple bunu geliştiricinin topladığı veri saymaz.)
5. **Age rating**: tüm sorulara "None" → 4+.
6. **App Review Information → Notes** (İngilizce öneri):
   > All data stays on device; no accounts or servers. Sign in with Apple is optional
   > (there is a "Continue without signing in" option). Account deletion is under
   > Settings → Hesap → Hesabı sil. Pro features can be tested with the free trial
   > or the provided sandbox account.

## 7. Build yükle ve TestFlight

1. Xcode'da hedef: **Any iOS Device (arm64)** → **Product → Archive**.
2. Organizer → **Distribute App → App Store Connect → Upload**.
   (Şifreleme sorusu sorulmaz; `ITSAppUsesNonExemptEncryption=NO` ayarlı.)
3. 10-30 dk sonra build TestFlight'ta görünür. **Internal Testing**'e kendini ekle ve
   gerçek cihazda şunları doğrula:
   - Widget'tan `flapse://capture` derin bağlantısı (ücretsiz kullanıcı limitteyken paywall açmalı)
   - Arka planda render + Dynamic Island + öne dönünce otomatik retry
   - Fotoğraf içe aktar → "Bitti" ile kapanış
   - Kırpma, Fotoğraflara kaydetme, bildirimler, 2-3 dilde arayüz
4. İstenirse **External Testing** grubu (ilk dış grup kısa bir TestFlight incelemesinden geçer).

## 8. İncelemeye gönder

1. Sürüm sayfasında build'i seç, IAP'leri iliştir.
2. **Add for Review → Submit to App Review**.
3. İnceleme genelde 24-48 saat. Ret gelirse Resolution Center'daki gerekçe tek maddelik
   olur; düzeltip yeniden göndermek hızlıdır.
4. Onay sonrası yayına alma anını kontrol etmek için "Manually release this version" seç.

## 9. Yayın sonrası

- Xcode Organizer → Crashes ve App Analytics'i izle.
- Yeni sürümde `MARKETING_VERSION`'ı artır (1.0 → 1.1); her yüklemede
  `CURRENT_PROJECT_VERSION` da artmalı.
- `CKShare.publicPermission = .readWrite` bilinçli tercih (linki olan herkes katılabilir) —
  Birlikte Çekim'i geniş duyurmadan önce bir kez daha gözden geçir.
- CI için: `.gitignore`'dan `.github/workflows/`'u çıkar, `workflow` yetkili bir git
  kimliğiyle push'la.

---

*Ayrıca bkz. `RELEASE_CHECKLIST.md` (gönderim öncesi teknik kontrol listesi).*
