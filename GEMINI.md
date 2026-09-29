# CineAI - Proje Kuralları (GEMINI.md)

Bu kurallar, Antigravity bünyesinde bu proje altında açılan tüm konuşmalar için her zaman geçerlidir.

---

## 1. Asla APK Derleme
* Proje masaüstü tarayıcısında (Chrome) test edilmektedir.
* Hiçbir koşulda `flutter build apk` komutu ÇALIŞTIRILMAYACAKTIR.
* Değişiklikler tamamlandığında her zaman `flutter build web --release` komutuyla web sürümü güncellenir ve `http://localhost:8080` üzerinde sunulur.

---

## 2. Test Bütünlüğü
* Her kod değişikliğinden sonra mutlaka `flutter test` çalıştırılmalıdır.
* Tüm testlerin (mevcut 24 birim ve widget testi) eksiksiz yeşil geçtiği doğrulanmalıdır.
* Testleri bozan hiçbir değişiklik onaylanamaz ve kalıcı yapılamaz.

---

## 3. Önceden Anlatıp Onay Alma
* Kod üzerinde herhangi bir değişiklik uygulamadan önce ne yapılacağı kullanıcıya açık, net ve adım adım anlatılmalıdır.
* Kullanıcıdan açık onay alınmadan doğrudan kod dosyaları değiştirilmeyecektir.

---

## 4. Arama ve Doğal Dil Esnekliği (Katı Filtre ve Kelime Sınırı Yok)
* Arama ve öneri özelliklerinde katı kelime sınırları, yapay anahtar kelime eşleştirmeleri veya kısıtlayıcı sözcük filtreleri **uygulanmayacaktır**.
* Kullanıcının aynı anlama gelen farklı tabirler, eş anlamlılar veya serbest doğal dil cümleleri kullanabileceği göz önünde bulundurulmalıdır.
* Doğallık esastır; kullanıcıyı belirli kelime kalıplarına zorlayan yapay kurallar yerine, anlamsal (semantik) anlayışı ve doğal dili temel alan esnek bir yaklaşım korunacaktır.

---

## 5. Responsive ve Esnek UI Tasarımı (Sabit Boyutlardan Kaçınma)
* Kartlar, listeler, diyaloglar ve tüm UI bileşenleri tasarlanırken veya eklenirken mümkün olduğunca responsive (esnek ve ekrana duyarlı) yapılar kullanılmalıdır.
* Farklı ekran boyutlarında, tarayıcı pencerelerinde veya çözünürlüklerde taşma (`RenderFlex overflow`), bozulma veya görsel bug'lar yaşanmaması için sabit (hardcoded) genişlik/yükseklik yerine esnek yapılar (`LayoutBuilder`, `Flexible`, `Expanded`, `ConstrainedBox`, `MediaQuery` vb.) tercih edilmelidir.
* Bileşenlerin hem geniş masaüstü ekranlarında hem de dar pencere/ekranlarda akıcı ve hatasız ölçeklenmesi garanti altına alınmalıdır.
