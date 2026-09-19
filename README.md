# CineAI - Modern Cross-Platform Movie Tracker & AI Recommendation Engine

CineAI, **Mobil (iOS/Android)** ve **Masaüstü (Windows/macOS/Linux)** platformlarında çalışan, **Clean Architecture** ve **Riverpod** ile geliştirilmiş, **SQLite** yerel veritabanı, **TMDB** API ve **Google Gemini (LLM)** destekli kişiselleştirilmiş film takip ve öneri uygulamasıdır.

---

## 🌟 Öne Çıkan Özellikler

1. **Çapraz Platform & Uyarlanabilir (Responsive) Arayüz**:
   - **Masaüstü ve Tablet**: Yan gezinme rayı (`NavigationRail`) ve geniş ekran grid yerleşimi.
   - **Mobil**: Ergonomik alt gezinme çubuğu (`NavigationBar`) ve kart odaklı görünüm.
   - **Koyu Tema Öncelikli (Dark-Mode First)**: Gece mavisi ve antrasit tonlarında sinematik görsel estetik.

2. **Gelişmiş AI Geri Bildirim Döngüsü (Conversational Feedback Loop)**:
   - **Proaktif Hatırlatma**: Bir sonraki oturumda, daha önce önerilen ancak henüz değerlendirilmemiş filmler için AI samimi bir soruyla söze başlar (*"Geçen gün sana Inception filmini önermiştim, izleme fırsatın oldu mu?"*).
   - **Zorlamasız Puanlama & Mini Soru-Cevap**: Kullanıcı yıldız vermek zorunda değildir. Kısa 1-2 samimi soruyla filmin neresini beğenip beğenmediğini anlatabilir (*"Oyunculuklar harikaydı, sonu çok iyiydi ama ortası biraz yavaştı"*).
   - **Duygu ve Özellik Çıkarımı**: AI bu doğal dilden:
     * Tahmini puan (örn: 4.2 / 5.0),
     * Sevilen öğeler (`["etkileyici oyunculuk", "ters köşe final"]`),
     * Hoşlanılmayan öğeler (`["ağır tempo"]`)
     çıkarır.

3. **Kritik Zaman Damgası Kuralı (`recommended_at` Mühürleme)**:
   - Bir film önerildiğinde geçici anı tutulur (`initial_proposed_at`).
   - Kullanıcı filmi **izlediğini onayladığı an**, orijinal öneri tarihi `recommended_at` olarak **kalıcı şekilde mühürlenir**.
   - Bu tarih onaylama tarihiyle **asla ezilmez**, böylece filmin gerçek önerilme ve izlenme referansı korunur.

4. **Nokta Atışı Gelecek Öneriler (`user_taste_profile`)**:
   - Çıkarılan sevilen/sevilmeyen özellikler kullanıcının dinamik zevk profiline işlenir.
   - Sonraki film önerisi isteklerinde yapay zeka bu zevk profili bağlamını doğrudan prompt'a ekleyerek nokta atışı film seçer.

5. **Tekrar İzleme / Yedek Öneri Mantığı (Re-Watch Fallback)**:
   - Kriterlere uygun yeni bir film bulunamadığında veya kullanıcı eski bir favori istediğinde veritabanından **en eski `recommended_at` tarihine sahip** yüksek puanlı filmler sorgulanır (`ORDER BY recommended_at ASC`).
   - Kullanıcıya nostaljik ve samimi bir hatırlatma sunulur (*"Yeni bir eşleşme bulamadık ama Interstellar'ı izleyeli uzun zaman oldu. Yeniden izlemeye ne dersin? 🍿"*).

6. **TMDB Entegrasyonu & Anahtarsız Demo Desteği**:
   - The Movie Database (TMDB) API üzerinden canlı arama, tür listesi ve afişler.
   - API anahtarı olmadan da hemen test edilebilen zengin yerleşik film kataloğu ve akıllı yerel analiz motoru.

---

## 🏗️ Proje Mimarisi (Clean Architecture)

```text
movie_recommend_ai/
├── lib/
│   ├── main.dart                       # Masaüstü FFI başlatma & ProviderScope
│   ├── core/
│   │   ├── constants/                  # Renk paleti, API sabitleri
│   │   ├── database/                   # SQLite (sqflite + sqflite_common_ffi)
│   │   ├── theme/                      # Material 3 sinema koyu teması
│   │   └── utils/                      # ResponsiveLayout, DateFormatter
│   ├── data/
│   │   ├── models/                     # Movie, ChatMessage, UserTasteProfile
│   │   ├── services/                   # TmdbService, GeminiAiService
│   │   └── repositories/               # MovieRepository, UserTasteRepository, ChatRepository
│   ├── domain/
│   │   └── enums/                      # MovieStatus (none, watchlist, recommended, watched)
│   └── presentation/
│       ├── providers/                  # Riverpod Notifiers (Chat, Library, Tmdb, Settings)
│       ├── screens/                    # ShellScreen, ChatScreen, DiscoverScreen, LibraryScreen, SettingsScreen
│       └── widgets/                    # MovieCard, MovieDetailModal, RatingDialog
└── test/
    ├── database_test.dart              # SQLite ve recommended_at mühürleme testleri
    ├── sentiment_extraction_test.dart  # Doğal dilden puan ve özellik çıkarımı testleri
    └── rewatch_fallback_test.dart      # Eski favoriler re-watch sorgu testleri
```

---

## 🗄️ Veritabanı Şeması (SQLite)

### Tablo: `movies`
```sql
CREATE TABLE movies (
    id INTEGER PRIMARY KEY,                 -- TMDB ID
    title TEXT NOT NULL,
    overview TEXT,
    poster_path TEXT,
    backdrop_path TEXT,
    release_date TEXT,
    vote_average REAL,
    genres TEXT,
    status TEXT NOT NULL,                   -- 'none', 'watchlist', 'recommended', 'watched'
    initial_proposed_at TEXT,               -- İlk önerildiği geçici tarih
    recommended_at TEXT,                    -- İzlendiği an mühürlenen orijinal öneri tarihi
    user_rating REAL,                       -- Puan (1.0 - 5.0)
    rating_source TEXT,                     -- 'manual' veya 'ai_inferred'
    liked_aspects TEXT,                     -- JSON: ["ters köşe kurgu", "müzikler"]
    disliked_aspects TEXT,                  -- JSON: ["ağır orta tempo"]
    user_review TEXT,                       -- Kullanıcının söylediği sözler
    reviewed INTEGER NOT NULL DEFAULT 0     -- 0 = Bekliyor, 1 = Değerlendirildi
);
```

### Tablo: `user_taste_profile`
```sql
CREATE TABLE user_taste_profile (
    id INTEGER PRIMARY KEY DEFAULT 1,
    liked_themes TEXT,                      -- JSON: Sevilen temalar listesi
    disliked_themes TEXT,                   -- JSON: Sevilemeyen temalar listesi
    preferred_genres TEXT,                  -- JSON: Tercih edilen türler
    last_updated TEXT
);
```

### Tablo: `chat_messages`
```sql
CREATE TABLE chat_messages (
    id TEXT PRIMARY KEY,
    sender TEXT NOT NULL,                   -- 'user', 'assistant', 'system'
    content TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    related_movie_id INTEGER,               -- Önerilen veya incelenen film ID'si
    message_type TEXT,                      -- 'normal', 'review_nudge', 'sentiment_interview', 'recommendation_card'
    options TEXT,                           -- JSON: Hızlı cevap butonları
    FOREIGN KEY(related_movie_id) REFERENCES movies(id)
);
```

---

## 🚀 Adım Adım Kurulum ve Çalıştırma

### 1. Gereksinimler
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.2.0)
- Masaüstü geliştirme için:
  * **Windows**: Visual Studio 2022 ("Desktop development with C++" bileşeni ile)
  * **macOS**: Xcode
  * **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`

### 2. Bağımlılıkları Yükleme
Proje dizininde terminali açın:
```bash
flutter pub get
```

### 3. Testleri Çalıştırma
Tüm birim ve entegrasyon testlerini koşturun:
```bash
flutter test
```

### 4. Uygulamayı Başlatma

**Windows Masaüstü:**
```bash
flutter run -d windows
```

**macOS Masaüstü:**
```bash
flutter run -d macos
```

**Linux Masaüstü:**
```bash
flutter run -d linux
```

**Android / iOS:**
```bash
flutter run -d android
# veya
flutter run -d ios
```

**Web Tarayıcısı:**
```bash
flutter run -d chrome
```

---

## 🔑 API Anahtarları (İsteğe Bağlı)
Uygulama açıldıktan sonra **Ayarlar** sekmesine giderek:
- **TMDB API Key**: Film arama ve güncel trendler için.
- **Gemini API Key**: [Google AI Studio](https://aistudio.google.com/) üzerinden alacağınız API anahtarı.
- *Anahtar girmeseniz dahi "Örnek Test Verilerini Yükle (Seed Demo Data)" butonuna basarak tüm akışı anında deneyimleyebilirsiniz.*
