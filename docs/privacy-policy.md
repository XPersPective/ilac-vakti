# İlaç Vakti — gizlilik politikası taslağı

Güncelleme: 11 Ekim 2026. Bu belge mevcut davranışı açıklar; mağazaya gönderilmiş/onaylanmış beyan değildir. Yayıncı iletişimi ve mağaza hesabı yayın öncesi doğrulanmalıdır.

Kişi isimleri, ilaç isimleri, kullanıcı tarafından yazılan doz/zaman planları ve alım işaretleri cihazın uygulamaya özel alanında şifreli tutulur. Uygulamanın bu kayıtları gönderen bir sunucusu, hesabı, reklam veya satın alma entegrasyonu yoktur. Bildirimlerde kişi/ilaç/doz gösterilmez. Cihaz anahtarının kaybı kayıtları erişilemez yapabilir; önceden alınmış parola korumalı yedek ayrı saklanmalıdır.

Kamera isteğe bağlıdır. Görüntü Google ML Kit Latin metin tanıma ile cihazda işlenir. Sonuç kullanıcının düzenleyip onayladığı isim taslağıdır. Uygulamanın kendi geçici görüntüsü işlemden sonra kaldırılır; başka yerdeki orijinal görüntü silinmez. ML Kit SDK tanılama kapsamında cihaz/uygulama bilgileri, kurulum kimliği, performans ve API yapılandırma/girdi-çıktı boyutları gibi veriler işleyebilir. Yerel OCR bütün SDK'nın ağ bağlantısı yapmadığı anlamına gelmez. Son paket ve SDK sürümleri mağaza beyanında ayrıca incelenir.

Kullanıcı parola ile şifreli yedek oluşturup sistem paylaşım menüsünden hedefini seçebilir. Parola uygulamanın sunucusuna gönderilmez. Alıcının uygulaması veya paylaşım servisi dosyayı kendi koşullarına göre işler. Parolayı ayrı güvenli kanaldan iletmek kullanıcının sorumluluğudur. Paylaşım otomatik eşitleme, teslim veya alarm garantisi sağlamaz. İçeri aktarma mevcut kayıtları onayla değiştirir; dışarıdaki yedekler silinmez.

Uygulama tıbbi karar veya doz önerisi sağlamaz. Bildirim izinleri ve işletim sistemi sınırlamaları nedeniyle önemli ilaç takibinin tek güvence aracı olarak kullanılmamalıdır. Kayıtlar değiştirilebilir/arşivlenebilir; arşiv geçmişi korur. Cihaz kaydını kalıcı kaldırmak için işletim sisteminin uygulama verilerini silme/kaldırma işlemi kullanılabilir; paylaşılan kopyalar etkilenmez.

SDK kaynakları: [Android ML Kit disclosure](https://developers.google.com/ml-kit/android-data-disclosure), [iOS ML Kit disclosure](https://developers.google.com/ml-kit/ios-data-disclosure). Sağlık ve gizlilik beyanları son imzalı paket, gerçek yayıncı bilgisi ve yürürlükteki kurallarla yeniden doğrulanmalıdır.
