-- ============================================================================
-- MIGRATION: v1.0 -> v2.0
-- Yeni ozellikler: ceza sistemi, yayinevleri, kitap-yazar coka-cok iliskisi,
-- rezervasyon sistemi, tam metin arama
-- ============================================================================

\c kutuphane_db;

-- Surum kontrolu
DO $$
DECLARE cur_ver TEXT;
BEGIN
    SELECT version_no INTO cur_ver FROM schema_version ORDER BY version_id DESC LIMIT 1;
    IF cur_ver != '1.0.0' THEN
        RAISE EXCEPTION 'Migration hatasi: Beklenen surum 1.0.0, mevcut: %', cur_ver;
    END IF;
    RAISE NOTICE 'Surum kontrolu basarili: % -> 2.0.0', cur_ver;
END $$;

BEGIN;

-- ============================================================================
-- 1. YENI TABLO: Yayinevleri
-- ============================================================================
CREATE TABLE yayinevleri (
    yayinevi_id SERIAL PRIMARY KEY,
    yayinevi_adi VARCHAR(200) NOT NULL,
    sehir VARCHAR(100),
    telefon VARCHAR(20),
    email VARCHAR(100),
    web_sitesi VARCHAR(200),
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. YENI TABLO: Kitap-Yazar Coka-Cok iliskisi
CREATE TABLE kitap_yazarlar (
    kitap_id INTEGER NOT NULL REFERENCES kitaplar(kitap_id) ON DELETE CASCADE,
    yazar_id INTEGER NOT NULL REFERENCES yazarlar(yazar_id),
    rol VARCHAR(30) DEFAULT 'yazar' CHECK (rol IN ('yazar', 'cevirmen', 'editor')),
    PRIMARY KEY (kitap_id, yazar_id, rol)
);

-- 3. YENI TABLO: Ceza sistemi
CREATE TABLE cezalar (
    ceza_id SERIAL PRIMARY KEY,
    islem_id INTEGER NOT NULL REFERENCES odunc_islemleri(islem_id),
    uye_id INTEGER NOT NULL REFERENCES uyeler(uye_id),
    ceza_tutari DECIMAL(10,2) NOT NULL,
    gecikme_gun INTEGER,
    odeme_durumu VARCHAR(20) DEFAULT 'odenmedi'
        CHECK (odeme_durumu IN ('odenmedi', 'odendi', 'muaf')),
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    odeme_tarihi TIMESTAMP
);

-- 4. YENI TABLO: Rezervasyon sistemi
CREATE TABLE rezervasyonlar (
    rezervasyon_id SERIAL PRIMARY KEY,
    kitap_id INTEGER NOT NULL REFERENCES kitaplar(kitap_id),
    uye_id INTEGER NOT NULL REFERENCES uyeler(uye_id),
    rezervasyon_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    bitis_tarihi TIMESTAMP,
    durum VARCHAR(20) DEFAULT 'aktif'
        CHECK (durum IN ('aktif', 'tamamlandi', 'iptal', 'suresi_doldu'))
);

-- ============================================================================
-- MEVCUT TABLOLARA KOLON EKLEME
-- ============================================================================

-- kitaplar tablosuna yayinevi, dil, aciklama kolonlari
ALTER TABLE kitaplar ADD COLUMN yayinevi_id INTEGER REFERENCES yayinevleri(yayinevi_id);
ALTER TABLE kitaplar ADD COLUMN dil VARCHAR(30) DEFAULT 'Turkce';
ALTER TABLE kitaplar ADD COLUMN aciklama TEXT;
ALTER TABLE kitaplar ADD COLUMN etiketler VARCHAR(500);

-- uyeler tablosuna uyelik tipi ve dogum tarihi
ALTER TABLE uyeler ADD COLUMN uyelik_tipi VARCHAR(20) DEFAULT 'standart'
    CHECK (uyelik_tipi IN ('standart', 'ogrenci', 'akademik', 'vip'));
ALTER TABLE uyeler ADD COLUMN dogum_tarihi DATE;
ALTER TABLE uyeler ADD COLUMN max_odunc INTEGER DEFAULT 3;

-- yazarlar tablosuna biyografi
ALTER TABLE yazarlar ADD COLUMN biyografi TEXT;

-- odunc_islemleri tablosuna notlar ve uzatma
ALTER TABLE odunc_islemleri ADD COLUMN notlar TEXT;
ALTER TABLE odunc_islemleri ADD COLUMN uzatma_sayisi INTEGER DEFAULT 0;

-- ============================================================================
-- YENI INDEKSLER
-- ============================================================================
CREATE INDEX idx_kitaplar_yayinevi ON kitaplar(yayinevi_id);
CREATE INDEX idx_kitaplar_dil ON kitaplar(dil);
CREATE INDEX idx_cezalar_uye ON cezalar(uye_id);
CREATE INDEX idx_cezalar_durum ON cezalar(odeme_durumu);
CREATE INDEX idx_rezervasyonlar_kitap ON rezervasyonlar(kitap_id);
CREATE INDEX idx_rezervasyonlar_uye ON rezervasyonlar(uye_id);
CREATE INDEX idx_kitap_yazarlar_yazar ON kitap_yazarlar(yazar_id);

-- ============================================================================
-- YENI VIEW'LAR
-- ============================================================================
CREATE OR REPLACE VIEW v_kitap_detay AS
SELECT k.kitap_id, k.isbn, k.baslik, y.ad || ' ' || y.soyad AS yazar,
       kat.kategori_adi, yev.yayinevi_adi, k.yayin_yili, k.dil,
       k.kopya_sayisi, k.mevcut_kopya,
       CASE WHEN k.mevcut_kopya > 0 THEN 'Mevcut' ELSE 'Tukendi' END AS durum
FROM kitaplar k
LEFT JOIN yazarlar y ON k.yazar_id = y.yazar_id
LEFT JOIN kategoriler kat ON k.kategori_id = kat.kategori_id
LEFT JOIN yayinevleri yev ON k.yayinevi_id = yev.yayinevi_id;

CREATE OR REPLACE VIEW v_uye_ceza_durumu AS
SELECT u.uye_id, u.ad || ' ' || u.soyad AS uye_adi, u.uyelik_tipi,
       COUNT(c.ceza_id) AS toplam_ceza,
       COALESCE(SUM(CASE WHEN c.odeme_durumu = 'odenmedi' THEN c.ceza_tutari ELSE 0 END), 0) AS odenmemis_ceza
FROM uyeler u
LEFT JOIN cezalar c ON u.uye_id = c.uye_id
GROUP BY u.uye_id, u.ad, u.soyad, u.uyelik_tipi;

-- ============================================================================
-- YENI FONKSIYON: Gecikme cezasi hesapla
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_ceza_hesapla(p_islem_id INTEGER)
RETURNS DECIMAL AS $$
DECLARE
    gecikme INTEGER;
    gunluk_ceza DECIMAL := 2.50;
BEGIN
    SELECT GREATEST(0, EXTRACT(DAY FROM CURRENT_TIMESTAMP - beklenen_iade)::INTEGER)
    INTO gecikme FROM odunc_islemleri WHERE islem_id = p_islem_id;
    RETURN gecikme * gunluk_ceza;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ORNEK VERI (yeni tablolar icin)
-- ============================================================================
INSERT INTO yayinevleri (yayinevi_adi, sehir, email) VALUES
('Iletisim Yayinlari','Istanbul','info@iletisim.com'),
('Yapi Kredi Yayinlari','Istanbul','info@ykyyayin.com'),
('Can Yayinlari','Istanbul','info@canyayinlari.com'),
('Is Bankasi Kultur Yayinlari','Istanbul','info@iskultur.com'),
('Dogan Kitap','Istanbul','info@dogankitap.com'),
('Alfa Yayinlari','Istanbul','info@alfayayin.com'),
('Everest Yayinlari','Istanbul','info@everestyayin.com'),
('Pegasus Yayinlari','Istanbul','info@pegasus.com');

-- Mevcut kitap-yazar iliskilerini coka-cok tablosuna aktar
INSERT INTO kitap_yazarlar (kitap_id, yazar_id, rol)
SELECT kitap_id, yazar_id, 'yazar' FROM kitaplar WHERE yazar_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Yayinevi ata
UPDATE kitaplar SET yayinevi_id = 1 + (kitap_id % 8);

-- Uyelik tipleri ata
UPDATE uyeler SET uyelik_tipi = (ARRAY['standart','ogrenci','akademik','vip'])[1 + (uye_id % 4)],
    max_odunc = CASE
        WHEN (ARRAY['standart','ogrenci','akademik','vip'])[1 + (uye_id % 4)] = 'vip' THEN 10
        WHEN (ARRAY['standart','ogrenci','akademik','vip'])[1 + (uye_id % 4)] = 'akademik' THEN 7
        WHEN (ARRAY['standart','ogrenci','akademik','vip'])[1 + (uye_id % 4)] = 'ogrenci' THEN 5
        ELSE 3 END;

-- Gecikme cezalari olustur
INSERT INTO cezalar (islem_id, uye_id, ceza_tutari, gecikme_gun, odeme_durumu)
SELECT islem_id, uye_id,
    ROUND((5 + random() * 50)::NUMERIC, 2),
    (3 + (random() * 30)::INTEGER),
    (ARRAY['odenmedi','odendi','odendi','muaf'])[1 + (islem_id % 4)]
FROM odunc_islemleri WHERE durum = 'gecikti' LIMIT 200;

-- Rezervasyonlar
INSERT INTO rezervasyonlar (kitap_id, uye_id, rezervasyon_tarihi, durum)
SELECT 1 + (i % 200), 1 + (i % 400),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 60)::INTEGER),
    (ARRAY['aktif','tamamlandi','iptal','suresi_doldu'])[1 + (i % 4)]
FROM generate_series(1, 300) AS s(i);

-- Surum kaydini guncelle
INSERT INTO schema_version (version_no, aciklama, migration_dosya, geri_alma_dosya)
VALUES ('2.0.0', 'Yayinevleri, ceza sistemi, rezervasyon, kitap-yazar coka-cok, uyelik tipleri',
        'v1_to_v2_migration.sql', 'v2_to_v1_rollback.sql');

COMMIT;

SELECT 'Migration v1.0 -> v2.0 BASARILI!' AS bilgi;
SELECT * FROM schema_version ORDER BY version_id;
