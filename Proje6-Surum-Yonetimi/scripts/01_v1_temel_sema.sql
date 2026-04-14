-- ============================================================================
-- BLM4522 - Proje 6: Veritabani Yukseltme ve Surum Yonetimi
-- Dosya: 01_v1_temel_sema.sql
-- Aciklama: Kutuphane Yonetim Sistemi v1.0 - Temel Sema
-- ============================================================================

-- Mevcut DB varsa sil
DROP DATABASE IF EXISTS kutuphane_db;
CREATE DATABASE kutuphane_db WITH ENCODING = 'UTF8' TEMPLATE = template0;

\c kutuphane_db;

-- ============================================================================
-- SURUM YONETIM TABLOSU (Migration Tracking)
-- Bu tablo tum surumlerde kalir, migration gecmisini tutar
-- ============================================================================
CREATE TABLE schema_version (
    version_id SERIAL PRIMARY KEY,
    version_no VARCHAR(20) NOT NULL,
    aciklama TEXT,
    migration_dosya VARCHAR(200),
    uygulama_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uygulayan VARCHAR(100) DEFAULT CURRENT_USER,
    sure_ms INTEGER,
    durum VARCHAR(20) DEFAULT 'basarili'
        CHECK (durum IN ('basarili', 'basarisiz', 'geri_alindi')),
    kontrol_toplami VARCHAR(64),
    geri_alma_dosya VARCHAR(200)
);

CREATE INDEX idx_schema_version_no ON schema_version(version_no);
COMMENT ON TABLE schema_version IS 'Veritabani sema surum gecmisi';

-- ============================================================================
-- V1.0 TABLOLAR - Temel Kutuphane Sistemi
-- ============================================================================

-- 1. Yazarlar
CREATE TABLE yazarlar (
    yazar_id SERIAL PRIMARY KEY,
    ad VARCHAR(100) NOT NULL,
    soyad VARCHAR(100) NOT NULL,
    dogum_tarihi DATE,
    ulke VARCHAR(50),
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Kategoriler
CREATE TABLE kategoriler (
    kategori_id SERIAL PRIMARY KEY,
    kategori_adi VARCHAR(100) NOT NULL UNIQUE,
    aciklama TEXT,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Kitaplar
CREATE TABLE kitaplar (
    kitap_id SERIAL PRIMARY KEY,
    isbn VARCHAR(20) UNIQUE NOT NULL,
    baslik VARCHAR(300) NOT NULL,
    yazar_id INTEGER REFERENCES yazarlar(yazar_id),
    kategori_id INTEGER REFERENCES kategoriler(kategori_id),
    yayin_yili INTEGER,
    sayfa_sayisi INTEGER,
    kopya_sayisi INTEGER DEFAULT 1,
    mevcut_kopya INTEGER DEFAULT 1,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Uyeler
CREATE TABLE uyeler (
    uye_id SERIAL PRIMARY KEY,
    tc_kimlik VARCHAR(11) UNIQUE NOT NULL,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    telefon VARCHAR(20),
    adres TEXT,
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aktif BOOLEAN DEFAULT TRUE
);

-- 5. Odunc Islemleri
CREATE TABLE odunc_islemleri (
    islem_id SERIAL PRIMARY KEY,
    kitap_id INTEGER NOT NULL REFERENCES kitaplar(kitap_id),
    uye_id INTEGER NOT NULL REFERENCES uyeler(uye_id),
    odunc_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    iade_tarihi TIMESTAMP,
    beklenen_iade DATE NOT NULL,
    durum VARCHAR(20) DEFAULT 'oduncte'
        CHECK (durum IN ('oduncte', 'iade_edildi', 'gecikti'))
);

-- V1.0 Indeksler
CREATE INDEX idx_kitaplar_isbn ON kitaplar(isbn);
CREATE INDEX idx_kitaplar_yazar ON kitaplar(yazar_id);
CREATE INDEX idx_kitaplar_kategori ON kitaplar(kategori_id);
CREATE INDEX idx_uyeler_tc ON uyeler(tc_kimlik);
CREATE INDEX idx_odunc_kitap ON odunc_islemleri(kitap_id);
CREATE INDEX idx_odunc_uye ON odunc_islemleri(uye_id);
CREATE INDEX idx_odunc_durum ON odunc_islemleri(durum);

-- V1.0 Surum kaydini ekle
INSERT INTO schema_version (version_no, aciklama, migration_dosya)
VALUES ('1.0.0', 'Temel kutuphane semasi: yazarlar, kategoriler, kitaplar, uyeler, odunc_islemleri', '01_v1_temel_sema.sql');

SELECT 'Kutuphane DB v1.0 olusturuldu!' AS bilgi;
SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;
