-- ==============================================================================
-- CineAI - Supabase Cloud PostgreSQL Schema DDL
-- Scalable Hybrid Architecture: Cached Catalog, Zero-Token Templates, & User Sync
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. Shared Catalog: cached_movies
-- Stores enriched movie metadata, posters, and 2-3 sentence Turkish overviews.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cached_movies (
    id BIGINT PRIMARY KEY,
    title TEXT NOT NULL,
    original_title TEXT,
    overview TEXT,
    poster_path TEXT,
    backdrop_path TEXT,
    release_date DATE,
    vote_average NUMERIC(3, 1) DEFAULT 7.0,
    genres TEXT, -- e.g. "Bilim Kurgu, Gerilim, Gizem"
    popularity NUMERIC(8, 2) DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_cached_movies_title ON public.cached_movies (LOWER(title));
CREATE INDEX IF NOT EXISTS idx_cached_movies_genres ON public.cached_movies (genres);

-- ------------------------------------------------------------------------------
-- 2. Shared Templates: cached_recommendations
-- Modular recommendation templates for instant zero-token offline/fallback pitches.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cached_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    movie_id BIGINT NOT NULL REFERENCES public.cached_movies(id) ON DELETE CASCADE,
    hook_genre TEXT NOT NULL,       -- e.g. "Zamanda yolculuk ve akıl almaz paradoksları seven bir sinemasever olarak"
    hook_mood TEXT NOT NULL,        -- e.g. "Nefes kesen temposu ve zihin bükücü kurgusuyla"
    core_summary TEXT NOT NULL,     -- 2-3 sentence engaging synopsis and why it fits
    target_aspects TEXT[] DEFAULT '{}', -- e.g. ["ters köşe kurgu", "zaman paradoksları"]
    suitability_tags TEXT[] DEFAULT '{}', -- e.g. ["akıl yakan", "felsefi", "yoğun tempo"]
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    CONSTRAINT unique_cached_rec_movie UNIQUE (movie_id)
);

CREATE INDEX IF NOT EXISTS idx_cached_recommendations_movie_id ON public.cached_recommendations (movie_id);

-- ------------------------------------------------------------------------------
-- 3. User Identity: user_profiles
-- Supports anonymous device identification or Supabase Auth UUIDs.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT UNIQUE,
    is_anonymous BOOLEAN DEFAULT TRUE,
    email TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    last_active_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 4. User Cloud Sync: user_watch_history
-- Synchronized user watch history, ratings (1.0-10.0 scale), and reviews.
-- STRICT RULE: initial_proposed_at and recommended_at are strictly preserved!
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_watch_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    movie_id BIGINT NOT NULL,
    movie_title TEXT NOT NULL,
    poster_path TEXT,
    genres TEXT,
    status TEXT NOT NULL CHECK (status IN ('none', 'recommended', 'watchlist', 'watched')),
    user_rating NUMERIC(3, 1) CHECK (user_rating >= 0.0 AND user_rating <= 10.0),
    rating_source TEXT CHECK (rating_source IN ('manual', 'ai_inferred', 'unspecified')),
    liked_aspects TEXT[] DEFAULT '{}',
    disliked_aspects TEXT[] DEFAULT '{}',
    user_review TEXT,
    reviewed BOOLEAN DEFAULT FALSE,
    initial_proposed_at TIMESTAMPTZ,
    recommended_at TIMESTAMPTZ, -- STRICT: Preserves original proposal/watch date
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    sync_version INT DEFAULT 1,
    CONSTRAINT unique_user_movie UNIQUE (user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_user_watch_history_user ON public.user_watch_history (user_id);
CREATE INDEX IF NOT EXISTS idx_user_watch_history_status ON public.user_watch_history (user_id, status);

-- ------------------------------------------------------------------------------
-- 5. Row Level Security (RLS) Policies
-- ------------------------------------------------------------------------------
ALTER TABLE public.cached_movies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cached_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_watch_history ENABLE ROW LEVEL SECURITY;

-- Shared catalogs: Public read-only
DROP POLICY IF EXISTS "Public read access on cached_movies" ON public.cached_movies;
CREATE POLICY "Public read access on cached_movies" ON public.cached_movies FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read access on cached_recommendations" ON public.cached_recommendations;
CREATE POLICY "Public read access on cached_recommendations" ON public.cached_recommendations FOR SELECT USING (true);

-- User profiles: Read and update for matching user
DROP POLICY IF EXISTS "Users can view and manage their own profile" ON public.user_profiles;
CREATE POLICY "Users can view and manage their own profile" ON public.user_profiles FOR ALL USING (true);

-- User watch history: CRUD based on user_id
DROP POLICY IF EXISTS "Users can manage their own watch history" ON public.user_watch_history;
CREATE POLICY "Users can manage their own watch history" ON public.user_watch_history FOR ALL USING (true);

-- ------------------------------------------------------------------------------
-- 6. Initial Seed Data for Zero-Token Out-Of-The-Box Recommendations
-- ------------------------------------------------------------------------------
INSERT INTO public.cached_movies (id, title, overview, poster_path, backdrop_path, release_date, vote_average, genres, popularity)
VALUES
(27205, 'Inception (Başlangıç)', 'Dom Cobb, zihnin en savunmasız olduğu rüya anında insanların bilinçaltından en derin sırları çalma konusunda uzmanlaşmış yetenekli bir hırsızdır. Cobb''a hayatını geri kazanması için imkansız bir görev teklif edilir: fikir çalmak yerine zihne yeni bir fikir yerleştirmek. Tehlikeli bir ekiple zihnin katmanlarına daldıkça geçmişinin hayaletleriyle yüzleşmek zorunda kalır.', '/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg', '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg', '2010-07-15', 8.4, 'Bilim Kurgu, Aksiyon, Macera', 120.5),
(157336, 'Interstellar (Yıldızlararası)', 'Dünya üzerindeki yaşam kaynakları tükenirken, insanlığın hayatta kalabilmesi için bir grup kaşif solucan deliğinden geçerek uzayın derinliklerine doğru tehlikeli bir yolculuğa çıkar. Eski NASA pilotu Cooper, geride bıraktığı ailesiyle insanlığın geleceği arasında zorlu bir seçim yapmak zorundadır. Zamanın göreceli aktığı bu destansı yolculuk, sevginin ve bilimin sınırlarını sorgulatır.', '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg', '/xJHokMbljvjADYdit5fK5VQsXEG.jpg', '2014-11-05', 8.4, 'Macera, Dram, Bilim Kurgu', 145.2),
(206487, 'Predestination (Zamanın Ötesinde)', 'Zamanda yolculuk yaparak gelecekte işlenecek suçları önlemekle görevli bir Zamansal Ajan, kariyerinin en karmaşık ve zihin bükücü son görevine çıkar. New York''ta binlerce kişinin ölümüne yol açan Fiyasko Bombacısı''nı yakalamaya çalışırken geçmişin derinliklerindeki gizemli bir yabancıyla karşılaşır. Kimlik, kader ve zaman paradokslarını son ana kadar soluksuz işleyen akıl yakan bir kurgu sunar.', '/sE0lF00g4UaA88o7NqK24W2rC27.jpg', '/7c93UnRwN446U17B57bBkl562pL.jpg', '2014-08-28', 7.5, 'Bilim Kurgu, Gerilim, Gizem', 85.0),
(329865, 'Arrival (Geliş)', 'Dünyaya inen gizemli uzay gemileriyle iletişim kurması için görevlendirilen uzman dilbilimci Dr. Louise Banks, insanlığın kaderini ve zaman algısını değiştirecek bir keşif yapar. Küresel bir nükleer kriz eşiğindeyken uzaylı varlıkların diliyle düşünmeyi öğrenen Louise, geleceğini ve geçmişini aynı anda görmeye başlar. Zamansal algı ve dil felsefesini birleştiren duygusal bir bilim kurgu başyapıtıdır.', '/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg', '/h3jYanWMEwK61qHDq8x0Yt1rWvA.jpg', '2016-11-10', 7.9, 'Bilim Kurgu, Gizem, Dram', 95.4)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cached_recommendations (movie_id, hook_genre, hook_mood, core_summary, target_aspects, suitability_tags)
VALUES
(27205, 'Rüya katmanları, akıl oyunları ve ters köşe kurguları seven bir sinemasever olarak', 'Zihnini son saniyesine kadar diri tutacak nefes kesici bir kurgu arıyorsan', 'Christopher Nolan imzalı **Inception**, bilinçaltının derinliklerine inen olağanüstü görsel dili ve zekice tasarlanmış paradokslarıyla tam sana göre.', ARRAY['ters köşe kurgu', 'akıl oyunları', 'derin atmosfer'], ARRAY['akıl yakan', 'ters köşe', 'gerilim']),
(157336, 'Derin uzay felsefesi, zaman genişlemesi ve duygusal bilim kurguları seven biri olarak', 'Görkemli müzikleri ve sarsıcı görsel diliyle unutulmaz bir sinema gecesi yaşamak istiyorsan', 'Hans Zimmer''ın eşsiz besteleriyle devleşen **Interstellar**, uzayın ıssızlığında bir babanın evladına verdiği sözü ve insanlığın kurtuluş mücadelesini anlatıyor.', ARRAY['etkileyici müzikler', 'felsefi derinlik', 'zamansal algı'], ARRAY['uzay', 'bilim kurgu', 'duygusal']),
(206487, 'Zamansal döngüler, paradokslar ve kimlik bilmecelerine tutkulu bir sinemasever olarak', 'Tahmin edilmesi imkansız şok edici bir finalle sarsılmak istiyorsan', '**Predestination**, zamanda yolculuk türünün en cesur ve kusursuz işlenmiş yapımlarından biri olarak seni soluksuz bırakacak.', ARRAY['zaman paradoksları', 'ters köşe final', 'derin gizem'], ARRAY['paradoks', 'zaman yolculuğu', 'ters köşe']),
(329865, 'Felsefi bilim kurgu, dilbilimsel derinlik ve dingin atmosferlerden hoşlanan bir izleyici olarak', 'İnsan doğasını ve zamanın doğrusallığını sorgulatan entelektüel bir başyapıt arıyorsan', 'Denis Villeneuve''ün yönettiği **Arrival**, uzaylı temasına getirdiği benzersiz felsefi bakış açısıyla aklından uzun süre çıkmayacak.', ARRAY['felsefi derinlik', 'etkileyici atmosfer', 'zamansal algı'], ARRAY['felsefi', 'uzay', 'derin'])
ON CONFLICT (movie_id) DO NOTHING;
