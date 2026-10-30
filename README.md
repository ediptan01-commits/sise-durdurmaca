# Şişe Durdurmaca – Flutter MVP

Telefon için şişeyi çevirip dik indirme oyununun **ilk oynanabilir sürümü**.

## Özellikler
- Parmağı yukarı kaydırarak şişe fırlatma; sürükleme mesafesi ve hızına bağlı dönüş.
- Yana sürükleyerek iniş yerini kontrol etme.
- Gerçek zamanlı basit 2B yer çekimi, dönüş ve dik iniş hesabı.
- Bölüme göre daralan ve hafif yana kayan hedef platformu.
- Skor ve üst üste başarılı atış serisi.
- Tekrar dene, yeni oyun, ses aç/kapa, dokunsal geri bildirim.
- Türkçe arayüz, harici görsel veya ses dosyasına bağımlılık yok.
- GitHub Actions ile Android APK/AAB.

## Telefonda oyun nasıl oynanır?
- Parmağı ekranda **yukarı doğru sürükleyip bırak**.
- Şişenin tam bir dönüş yapıp dik inmesini hedefle.
- Daha kısa/uzun ve daha hızlı/yavaş sürükleme dönüşü değiştirir.
- Sonraki bölümlerde hedef sağa/sola kayabilir; yana doğru da hafifçe sürükle.
- Başarısız olursa **Tekrar Dene** düğmesine bas.

## GitHub'a yükleme
1. GitHub'da boş bir depo aç: `sise-durdurmaca`.
2. Bu ZIP'i açıp **içindeki** `pubspec.yaml`, `lib/`, `test/` ve `.github/` klasörlerini (gizli .github dâhil) deponun köküne yükle.
3. GitHub > Actions > **Android APK ve AAB** > **Run workflow**.
4. İşlem başarılı olunca Artifacts içindeki `sise-durdurmaca-android` dosyasını indir; `app-release.apk` telefona kurulabilir.

Not: Kodlarda Android klasörü bulunmaz. GitHub Actions `flutter create` ile Android altyapısını otomatik üretir. Çıkan AAB test amaçlıdır; Play Store yayını öncesi kalıcı imzalama anahtarı, benzersiz paket kimliği ve mağaza gerekliliklerini ayrıca ayarlamak gerekir.

## Yerel geliştirme
Flutter kurulu bir bilgisayarda:

```sh
flutter create --platforms=android --org com.teknolojix --project-name sise_durdurmaca .
rm -f test/widget_test.dart
flutter pub get
flutter test
flutter run
```

## Klasörler
- `lib/main.dart`: Arayüz, çizim, fizik animasyonu ve kontroller.
- `lib/game_logic.dart`: Test edilebilir kurallar.
- `test/game_logic_test.dart`: Temel iniş testleri.
- `.github/workflows/android.yml`: APK/AAB üretimi.

## Mevcut durum
Bu bir MVP'dir. Fizik, gerçek akışkanlar mekaniği simülasyonu değil; oynanabilirlik için sadeleştirilmiş 2B simülasyondur. En iyi puan sadece o oyun oturumunda tutulur; kalıcı kayıt ve müzik sonraki sürümlere eklenebilir.
