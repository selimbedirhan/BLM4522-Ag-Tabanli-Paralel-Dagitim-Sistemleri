
DROP DATABASE IF EXISTS sosyal_medya_db;
CREATE DATABASE sosyal_medya_db WITH ENCODING = 'UTF8' TEMPLATE = template0;

\c sosyal_medya_db;

CREATE TABLE kullanicilar (
    kullanici_id SERIAL PRIMARY KEY,
    kullanici_adi VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    sifre_hash VARCHAR(255) NOT NULL,
    profil_foto VARCHAR(300),
    biyografi TEXT,
    sehir VARCHAR(50),
    dogum_tarihi DATE,
    dogrulanmis BOOLEAN DEFAULT FALSE,
    aktif BOOLEAN DEFAULT TRUE,
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    son_giris TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE gonderiler (
    gonderi_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    icerik TEXT NOT NULL,
    medya_url VARCHAR(500),
    medya_tipi VARCHAR(20) CHECK (medya_tipi IN ('resim','video','gif','yok')),
    begeni_sayisi INTEGER DEFAULT 0,
    yorum_sayisi INTEGER DEFAULT 0,
    paylasim_sayisi INTEGER DEFAULT 0,
    goruntulenme INTEGER DEFAULT 0,
    gizlilik VARCHAR(20) DEFAULT 'herkese_acik'
        CHECK (gizlilik IN ('herkese_acik','arkadaslar','gizli')),
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    guncelleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE yorumlar (
    yorum_id SERIAL PRIMARY KEY,
    gonderi_id INTEGER NOT NULL REFERENCES gonderiler(gonderi_id) ON DELETE CASCADE,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    ust_yorum_id INTEGER REFERENCES yorumlar(yorum_id),
    icerik TEXT NOT NULL,
    begeni_sayisi INTEGER DEFAULT 0,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE begeniler (
    begeni_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    gonderi_id INTEGER REFERENCES gonderiler(gonderi_id) ON DELETE CASCADE,
    yorum_id INTEGER REFERENCES yorumlar(yorum_id) ON DELETE CASCADE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (gonderi_id IS NOT NULL OR yorum_id IS NOT NULL)
);

CREATE TABLE takipler (
    takip_id SERIAL PRIMARY KEY,
    takipci_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    takip_edilen_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(takipci_id, takip_edilen_id),
    CHECK (takipci_id != takip_edilen_id)
);

CREATE TABLE mesajlar (
    mesaj_id SERIAL PRIMARY KEY,
    gonderen_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    alan_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    icerik TEXT NOT NULL,
    okundu BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bildirimler (
    bildirim_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    tip VARCHAR(30) CHECK (tip IN ('begeni','yorum','takip','mesaj','paylasim','sistem')),
    referans_id INTEGER,
    mesaj VARCHAR(300),
    okundu BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hashtagler (
    hashtag_id SERIAL PRIMARY KEY,
    hashtag VARCHAR(100) UNIQUE NOT NULL,
    kullanim_sayisi INTEGER DEFAULT 0,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE gonderi_hashtag (
    gonderi_id INTEGER NOT NULL REFERENCES gonderiler(gonderi_id) ON DELETE CASCADE,
    hashtag_id INTEGER NOT NULL REFERENCES hashtagler(hashtag_id),
    PRIMARY KEY (gonderi_id, hashtag_id)
);

CREATE TABLE replikasyon_log (
    log_id SERIAL PRIMARY KEY,
    islem_tipi VARCHAR(30) NOT NULL,
    kaynak_db VARCHAR(50),
    hedef_db VARCHAR(50),
    tablo_adi VARCHAR(100),
    kayit_sayisi INTEGER,
    gecikme_ms DECIMAL(10,2),
    durum VARCHAR(20) DEFAULT 'basarili',
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detay TEXT
);

CREATE INDEX idx_gonderi_kullanici ON gonderiler(kullanici_id);
CREATE INDEX idx_gonderi_tarih ON gonderiler(olusturma_tarihi DESC);
CREATE INDEX idx_yorum_gonderi ON yorumlar(gonderi_id);
CREATE INDEX idx_begeni_gonderi ON begeniler(gonderi_id);
CREATE INDEX idx_begeni_kullanici ON begeniler(kullanici_id);
CREATE INDEX idx_takip_takipci ON takipler(takipci_id);
CREATE INDEX idx_takip_edilen ON takipler(takip_edilen_id);
CREATE INDEX idx_mesaj_alan ON mesajlar(alan_id);
CREATE INDEX idx_bildirim_kullanici ON bildirimler(kullanici_id);

SELECT 'Sosyal Medya DB olusturuldu!' AS bilgi;
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;
