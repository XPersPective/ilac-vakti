# İlaç Vakti

Birden fazla kişinin kullanıcı tarafından girilmiş ilaç planlarını ve alım kayıtlarını cihazda takip eden Flutter uygulaması. Türkçe/İngilizce, açık/koyu/sistem teması, geçmiş grafikleri ve yerel hatırlatmalar içerir. Hesap, reklam, satın alma ve varsayılan bulut eşitlemesi yoktur.

## Kullanım

1. **Kişiler** bölümünde kişiyi ekleyin. İlacın adını, reçetedeki doz metnini, günlük saatlerini veya saat aralığını ve süreyi girin. Planı kendiniz doğrulamadan kaydedemezsiniz.
2. **Bugün** bölümünde zamanı gelmiş kayıtları **Aldı** veya **Atladı** olarak işaretleyin. Yanlış işareti temizleyebilirsiniz; düzeltme geçmişi korunur. İşaretsiz kayıt, ilacın alınmadığı anlamına gelmez.
3. **Ayarlar** bölümünden bildirimleri etkinleştirin. Sistem izni, pil ayarı ve gösterilen planlama kapsamını kontrol edin. Uygulamayı düzenli açın: en yakın 64 hatırlatma en fazla yedi günlük pencere içinde planlanır. Kesintisiz veya tıbbi amaçlı alarm garantisi yoktur.
4. Kamera metni düzenlenebilir, **doğrulanmamış** isim taslağı üretir. Doz ve zaman önermez. Ambalajı ve reçeteyi kendiniz kontrol edin.
5. Şifreli yedeği en az 12 karakterlik parolayla dışa aktarın ve paylaşım hedefini seçin. İçeri aktarma doğrulanır ve mevcut kayıtları değiştirmeden önce onay ister. Parola kaybolursa yedek kurtarılamaz.

## Veriler ve sınırlar

Kayıtlar AES-GCM ile şifrelenir; cihaz anahtarı Android Keystore/iOS Keychain üzerinden korunur. İki dosyalı yazma, yarım kalan son kayıttan önceki geçerli kaydı kurtarabilir. Anahtar kaybolursa uygulama boş veriyle mevcut kayıtların üzerine yazmaz. Cihaz değişimi için parola korumalı yedek gerekir. Fiziksel cihaz davranışları ayrıca sınanmalıdır.

Uygulama ilaç seçmez, dozu hesaplamaz, yan etki veya klinik tavsiye üretmez. Otomatik e-posta takibi ve cihazlar arası canlı eşitleme yoktur. Şifreli dosyanın paylaşılması alıcıya otomatik bildirim sağlandığı anlamına gelmez. Google ML Kit yerel OCR kullanır; SDK tanılama davranışı nedeniyle bütün bağımlılıklar için “ağ/veri toplama yok” iddiasında bulunulmaz.

## Geliştirme ve doğrulama

Flutter 3.47.2 / Dart 3.13.2; Android min24, target36; iOS min15.5. Bağımlılıklar pubspec.lock ile sabittir.

```sh
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
flutter test
python android/check_platform.py
flutter build apk --debug
```

İkon kontrolü: flutter test tool/make_icons.dart. Yeniden üretmek için --dart-define=WRITE_ICONS=true ekleyin. Üretim imzası ve mağaza yayını debug derlemenin kapsamında değildir.

.project-brain/ bu projenin kendi planıdır. Global store-automation skill bu klasörde başlatıldığında başka uygulamaların görevlerini buraya taşımaz.

Public GitHub deposu uygulamaya ait kaynak ve sentetik testler içerir. İsteğe bağlı iOS workflow standart public macOS runner, unsigned simulator build ve job logları kullanır; ücretli runner, cache veya artifact upload açmaz. Başarılı açılış görüntüsü tüm iOS davranışlarını doğrulamaz.

Mağaza metinleri D:/AppPublishing/README.md protokolüne göre hazırlanır. Gerçek hesap/mağaza kaydı, imza, beyanlar ve fiziksel cihaz kontrolleri tamamlanmadan üretim yayını yapılmaz. Kaynak MIT lisanslıdır; bağımlılık lisanslarına uygulama içinden erişilebilir.
