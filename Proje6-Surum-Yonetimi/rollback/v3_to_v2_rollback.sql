\c kutuphane_db;
BEGIN;

DROP TABLE IF EXISTS bildirimler CASCADE;
DROP TABLE IF EXISTS etkinlik_katilim CASCADE;
DROP TABLE IF EXISTS etkinlikler CASCADE;
DROP TABLE IF EXISTS degerlendirmeler CASCADE;
DROP TABLE IF EXISTS dijital_kitaplar CASCADE;

DROP VIEW IF EXISTS v_kutuphane_istatistik;
DROP VIEW IF EXISTS v_populer_kitaplar;
DROP FUNCTION IF EXISTS fn_puan_guncelle() CASCADE;

ALTER TABLE kitaplar DROP COLUMN IF EXISTS ort_puan;
ALTER TABLE kitaplar DROP COLUMN IF EXISTS degerlendirme_sayisi;
ALTER TABLE kitaplar DROP COLUMN IF EXISTS dijital_mevcut;
ALTER TABLE uyeler DROP COLUMN IF EXISTS toplam_odunc;
ALTER TABLE uyeler DROP COLUMN IF EXISTS gecikme_sayisi;
ALTER TABLE uyeler DROP COLUMN IF EXISTS puan;

UPDATE schema_version SET durum = 'geri_alindi' WHERE version_no = '3.0.0';
INSERT INTO schema_version (version_no, aciklama, migration_dosya)
VALUES ('2.0.0-rollback', 'v3.0 geri alindi, v2.0 durumuna donuldu', 'v3_to_v2_rollback.sql');

COMMIT;
SELECT 'Rollback v3.0 -> v2.0 BASARILI!' AS bilgi;
