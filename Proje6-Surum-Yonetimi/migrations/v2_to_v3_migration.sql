-- ============================================================================
-- MIGRATION: v2.0 -> v3.0
-- Yeni: etkinlik sistemi, dijital kitap destegi, okuma gecmisi istatistik,
-- gelismis arama, performans optimizasyonlari
-- ============================================================================

\c kutuphane_db;

DO $$
DECLARE cur_ver TEXT;
BEGIN
    SELECT version_no INTO cur_ver FROM schema_version
    WHERE durum = 'basarili' ORDER BY version_id DESC LIMIT 1;
    IF cur_ver != '2.0.0' THEN
        RAISE EXCEPTION 'Migration hatasi: Beklenen 2.0.0, mevcut: %', cur_ver;
    END IF;
END $$;

BEGIN;

-- ============================================================================
-- 1. YENI TABLO: Dijital Kitaplar (e-kitap/sesli kitap)
-- ============================================================================
CREATE TABLE dijital_kitaplar (
    dijital_id SERIAL PRIMARY KEY,
    kitap_id INTEGER REFERENCES kitaplar(kitap_id),
    format VARCHAR(20) NOT NULL CHECK (format IN ('epub', 'pdf', 'ses', 'interaktif')),
    dosya_boyutu_mb DECIMAL(10,2),
    indirme_sayisi INTEGER DEFAULT 0,
    erisim_linki VARCHAR(500),
    aktif BOOLEAN DEFAULT TRUE,
    ekleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. YENI TABLO: Etkinlikler
CREATE TABLE etkinlikler (
    etkinlik_id SERIAL PRIMARY KEY,
    etkinlik_adi VARCHAR(200) NOT NULL,
    aciklama TEXT,
    etkinlik_tarihi TIMESTAMP NOT NULL,
    bitis_tarihi TIMESTAMP,
    mekan VARCHAR(200),
    kontenjan INTEGER DEFAULT 50,
    kayitli_kisi INTEGER DEFAULT 0,
    etkinlik_tipi VARCHAR(30) CHECK (etkinlik_tipi IN ('yazar_soylesi','okuma_kulubu','atölye','sergi','soylesi')),
    durum VARCHAR(20) DEFAULT 'planlanmis'
        CHECK (durum IN ('planlanmis', 'aktif', 'tamamlandi', 'iptal')),
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. YENI TABLO: Etkinlik Katilim
CREATE TABLE etkinlik_katilim (
    katilim_id SERIAL PRIMARY KEY,
    etkinlik_id INTEGER NOT NULL REFERENCES etkinlikler(etkinlik_id),
    uye_id INTEGER NOT NULL REFERENCES uyeler(uye_id),
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    katilim_durumu VARCHAR(20) DEFAULT 'kayitli'
        CHECK (katilim_durumu IN ('kayitli', 'katildi', 'katilmadi', 'iptal')),
    UNIQUE(etkinlik_id, uye_id)
);

-- 4. YENI TABLO: Kitap Degerlendirmeleri
CREATE TABLE degerlendirmeler (
    degerlendirme_id SERIAL PRIMARY KEY,
    kitap_id INTEGER NOT NULL REFERENCES kitaplar(kitap_id),
    uye_id INTEGER NOT NULL REFERENCES uyeler(uye_id),
    puan INTEGER NOT NULL CHECK (puan BETWEEN 1 AND 5),
    yorum TEXT,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(kitap_id, uye_id)
);

-- 5. YENI TABLO: Bildirimler
CREATE TABLE bildirimler (
    bildirim_id SERIAL PRIMARY KEY,
    uye_id INTEGER NOT NULL REFERENCES uyeler(uye_id),
    baslik VARCHAR(200) NOT NULL,
    mesaj TEXT,
    bildirim_tipi VARCHAR(30) CHECK (bildirim_tipi IN ('iade_hatirlatma','ceza','rezervasyon','etkinlik','genel')),
    okundu BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- MEVCUT TABLOLARI GUNCELLE
-- ============================================================================
ALTER TABLE kitaplar ADD COLUMN ort_puan DECIMAL(3,2) DEFAULT 0;
ALTER TABLE kitaplar ADD COLUMN degerlendirme_sayisi INTEGER DEFAULT 0;
ALTER TABLE kitaplar ADD COLUMN dijital_mevcut BOOLEAN DEFAULT FALSE;

ALTER TABLE uyeler ADD COLUMN toplam_odunc INTEGER DEFAULT 0;
ALTER TABLE uyeler ADD COLUMN gecikme_sayisi INTEGER DEFAULT 0;
ALTER TABLE uyeler ADD COLUMN puan INTEGER DEFAULT 0;

-- ============================================================================
-- YENI INDEKSLER VE PERFORMANS
-- ============================================================================
CREATE INDEX idx_dijital_kitap ON dijital_kitaplar(kitap_id);
CREATE INDEX idx_etkinlik_tarih ON etkinlikler(etkinlik_tarihi);
CREATE INDEX idx_degerlendirme_kitap ON degerlendirmeler(kitap_id);
CREATE INDEX idx_degerlendirme_puan ON degerlendirmeler(puan);
CREATE INDEX idx_bildirim_uye ON bildirimler(uye_id);
CREATE INDEX idx_bildirim_okunmamis ON bildirimler(uye_id) WHERE okundu = FALSE;

-- Partitioning icin odunc_islemleri uzerinde tarih indeksi
CREATE INDEX idx_odunc_tarih ON odunc_islemleri(odunc_tarihi);

-- ============================================================================
-- GELISMIS GORUNUMLER
-- ============================================================================
CREATE OR REPLACE VIEW v_kutuphane_istatistik AS
SELECT
    (SELECT COUNT(*) FROM kitaplar) AS toplam_kitap,
    (SELECT COUNT(*) FROM uyeler WHERE aktif = TRUE) AS aktif_uye,
    (SELECT COUNT(*) FROM odunc_islemleri WHERE durum = 'oduncte') AS oduncte_kitap,
    (SELECT COUNT(*) FROM odunc_islemleri WHERE durum = 'gecikti') AS geciken,
    (SELECT COUNT(*) FROM rezervasyonlar WHERE durum = 'aktif') AS aktif_rezervasyon,
    (SELECT COALESCE(SUM(ceza_tutari), 0) FROM cezalar WHERE odeme_durumu = 'odenmedi') AS odenmemis_ceza,
    (SELECT COUNT(*) FROM dijital_kitaplar WHERE aktif = TRUE) AS dijital_kitap,
    (SELECT COUNT(*) FROM etkinlikler WHERE durum = 'planlanmis') AS planlanan_etkinlik;

CREATE OR REPLACE VIEW v_populer_kitaplar AS
SELECT k.kitap_id, k.baslik, y.ad||' '||y.soyad AS yazar,
       k.ort_puan, k.degerlendirme_sayisi,
       COUNT(oi.islem_id) AS odunc_sayisi
FROM kitaplar k
LEFT JOIN yazarlar y ON k.yazar_id = y.yazar_id
LEFT JOIN odunc_islemleri oi ON k.kitap_id = oi.kitap_id
GROUP BY k.kitap_id, k.baslik, y.ad, y.soyad, k.ort_puan, k.degerlendirme_sayisi
ORDER BY odunc_sayisi DESC;

-- ============================================================================
-- TRIGGER: Degerlendirme eklenince ortalama guncelle
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_puan_guncelle()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE kitaplar SET
        ort_puan = (SELECT ROUND(AVG(puan)::NUMERIC, 2) FROM degerlendirmeler WHERE kitap_id = NEW.kitap_id),
        degerlendirme_sayisi = (SELECT COUNT(*) FROM degerlendirmeler WHERE kitap_id = NEW.kitap_id)
    WHERE kitap_id = NEW.kitap_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_puan_guncelle
    AFTER INSERT OR UPDATE ON degerlendirmeler
    FOR EACH ROW EXECUTE FUNCTION fn_puan_guncelle();

-- ============================================================================
-- ORNEK VERI
-- ============================================================================
-- Dijital kitaplar
INSERT INTO dijital_kitaplar (kitap_id, format, dosya_boyutu_mb, indirme_sayisi)
SELECT kitap_id,
    (ARRAY['epub','pdf','ses','interaktif'])[1 + (kitap_id % 4)],
    ROUND((1 + random() * 100)::NUMERIC, 2),
    (random() * 500)::INTEGER
FROM kitaplar WHERE kitap_id <= 80;

UPDATE kitaplar SET dijital_mevcut = TRUE WHERE kitap_id <= 80;

-- Etkinlikler
INSERT INTO etkinlikler (etkinlik_adi, aciklama, etkinlik_tarihi, mekan, kontenjan, etkinlik_tipi, durum)
SELECT
    (ARRAY['Yazar Soylesi','Kitap Tanitimi','Okuma Kulubu','Siir Dinletisi','Cocuk Atolyesi'])[1 + (i % 5)]
    || ' #' || i,
    'Etkinlik aciklamasi ' || i,
    CURRENT_TIMESTAMP + (INTERVAL '1 day' * (i * 3 - 30)),
    (ARRAY['Ana Salon','Konferans Odasi','Cocuk Bolumu','Bahce','Cafe Alani'])[1 + (i % 5)],
    20 + (i * 5 % 80),
    (ARRAY['yazar_soylesi','okuma_kulubu','atölye','sergi','soylesi'])[1 + (i % 5)],
    (ARRAY['planlanmis','aktif','tamamlandi'])[1 + (i % 3)]
FROM generate_series(1, 20) AS s(i);

-- Degerlendirmeler
INSERT INTO degerlendirmeler (kitap_id, uye_id, puan, yorum)
SELECT 1 + (i % 200), 1 + (i % 400),
    1 + (i % 5),
    (ARRAY['Harika bir kitap!','Tavsiye ederim','Orta seviye','Begendim','Beklentimi karsilamadi'])[1 + (i % 5)]
FROM generate_series(1, 500) AS s(i)
ON CONFLICT (kitap_id, uye_id) DO NOTHING;

-- Bildirimler
INSERT INTO bildirimler (uye_id, baslik, mesaj, bildirim_tipi, okundu)
SELECT 1 + (i % 400),
    (ARRAY['Iade Hatirlatma','Ceza Bildirimi','Rezervasyon Onay','Etkinlik Davet','Duyuru'])[1 + (i % 5)],
    'Bildirim mesaji icerik ' || i,
    (ARRAY['iade_hatirlatma','ceza','rezervasyon','etkinlik','genel'])[1 + (i % 5)],
    i % 3 = 0
FROM generate_series(1, 600) AS s(i);

-- Uye istatistiklerini guncelle
UPDATE uyeler u SET
    toplam_odunc = (SELECT COUNT(*) FROM odunc_islemleri WHERE uye_id = u.uye_id),
    gecikme_sayisi = (SELECT COUNT(*) FROM odunc_islemleri WHERE uye_id = u.uye_id AND durum = 'gecikti');

-- Surum kaydi
INSERT INTO schema_version (version_no, aciklama, migration_dosya, geri_alma_dosya)
VALUES ('3.0.0', 'Dijital kitaplar, etkinlikler, degerlendirmeler, bildirimler, istatistik view',
        'v2_to_v3_migration.sql', 'v3_to_v2_rollback.sql');

COMMIT;

SELECT 'Migration v2.0 -> v3.0 BASARILI!' AS bilgi;
SELECT * FROM schema_version ORDER BY version_id;
