-- ============================================================================
-- ROLLBACK: v2.0 -> v1.0
-- v2.0 da eklenen degisiklikleri geri alir
-- ============================================================================

\c kutuphane_db;

BEGIN;

-- Yeni tablolari sil
DROP TABLE IF EXISTS rezervasyonlar CASCADE;
DROP TABLE IF EXISTS cezalar CASCADE;
DROP TABLE IF EXISTS kitap_yazarlar CASCADE;
DROP TABLE IF EXISTS yayinevleri CASCADE;

-- Eklenen kolonlari kaldir
ALTER TABLE kitaplar DROP COLUMN IF EXISTS yayinevi_id;
ALTER TABLE kitaplar DROP COLUMN IF EXISTS dil;
ALTER TABLE kitaplar DROP COLUMN IF EXISTS aciklama;
ALTER TABLE kitaplar DROP COLUMN IF EXISTS etiketler;
ALTER TABLE uyeler DROP COLUMN IF EXISTS uyelik_tipi;
ALTER TABLE uyeler DROP COLUMN IF EXISTS dogum_tarihi;
ALTER TABLE uyeler DROP COLUMN IF EXISTS max_odunc;
ALTER TABLE yazarlar DROP COLUMN IF EXISTS biyografi;
ALTER TABLE odunc_islemleri DROP COLUMN IF EXISTS notlar;
ALTER TABLE odunc_islemleri DROP COLUMN IF EXISTS uzatma_sayisi;

-- View'lari sil
DROP VIEW IF EXISTS v_kitap_detay;
DROP VIEW IF EXISTS v_uye_ceza_durumu;

-- Fonksiyonu sil
DROP FUNCTION IF EXISTS fn_ceza_hesapla(INTEGER);

-- Rollback kaydini ekle
UPDATE schema_version SET durum = 'geri_alindi' WHERE version_no = '2.0.0';
INSERT INTO schema_version (version_no, aciklama, migration_dosya)
VALUES ('1.0.0-rollback', 'v2.0 geri alindi, v1.0 durumuna donuldu', 'v2_to_v1_rollback.sql');

COMMIT;
SELECT 'Rollback v2.0 -> v1.0 BASARILI!' AS bilgi;
