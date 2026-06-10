
\c egitim_db;
\timing on

\echo '=========================================='
\echo '  INDEKSLEME STRATEJILERI'
\echo '=========================================='

\echo '--- 1. B-Tree Indeksler ---'

CREATE INDEX IF NOT EXISTS idx_ogrenci_sehir ON ogrenciler(sehir);
CREATE INDEX IF NOT EXISTS idx_ogrenci_uyelik ON ogrenciler(uyelik_tipi);
CREATE INDEX IF NOT EXISTS idx_ogrenci_kayit_tarihi ON ogrenciler(kayit_tarihi);

CREATE INDEX IF NOT EXISTS idx_kurs_seviye ON kurslar(seviye);
CREATE INDEX IF NOT EXISTS idx_kurs_yayinda ON kurslar(yayinda);
CREATE INDEX IF NOT EXISTS idx_kurs_fiyat ON kurslar(fiyat);
CREATE INDEX IF NOT EXISTS idx_kurs_kategori ON kurslar(kategori_id);
CREATE INDEX IF NOT EXISTS idx_kurs_egitmen ON kurslar(egitmen_id);

CREATE INDEX IF NOT EXISTS idx_kayit_ogrenci ON kayitlar(ogrenci_id);
CREATE INDEX IF NOT EXISTS idx_kayit_kurs ON kayitlar(kurs_id);
CREATE INDEX IF NOT EXISTS idx_kayit_durum ON kayitlar(durum);
CREATE INDEX IF NOT EXISTS idx_kayit_tarih ON kayitlar(kayit_tarihi);

CREATE INDEX IF NOT EXISTS idx_ilerleme_ogrenci ON ders_ilerleme(ogrenci_id);
CREATE INDEX IF NOT EXISTS idx_ilerleme_ders ON ders_ilerleme(ders_id);

CREATE INDEX IF NOT EXISTS idx_ders_kurs ON dersler(kurs_id);

CREATE INDEX IF NOT EXISTS idx_odeme_ogrenci ON odemeler(ogrenci_id);
CREATE INDEX IF NOT EXISTS idx_odeme_kurs ON odemeler(kurs_id);
CREATE INDEX IF NOT EXISTS idx_odeme_tarih ON odemeler(odeme_tarihi);
CREATE INDEX IF NOT EXISTS idx_odeme_durum ON odemeler(durum);

CREATE INDEX IF NOT EXISTS idx_deger_kurs ON degerlendirmeler(kurs_id);
CREATE INDEX IF NOT EXISTS idx_deger_ogrenci ON degerlendirmeler(ogrenci_id);

\echo '  B-Tree indeksler olusturuldu'

\echo '--- 2. Composite Indeksler ---'

CREATE INDEX IF NOT EXISTS idx_kayit_ogrenci_durum ON kayitlar(ogrenci_id, durum);
CREATE INDEX IF NOT EXISTS idx_odeme_tarih_durum ON odemeler(odeme_tarihi, durum);
CREATE INDEX IF NOT EXISTS idx_kurs_kategori_seviye ON kurslar(kategori_id, seviye);
CREATE INDEX IF NOT EXISTS idx_ilerleme_ogrenci_tamamlandi ON ders_ilerleme(ogrenci_id, tamamlandi);

\echo '  Composite indeksler olusturuldu'

\echo '--- 3. Partial Indeksler ---'

CREATE INDEX IF NOT EXISTS idx_ogrenci_aktif ON ogrenciler(ogrenci_id) WHERE aktif = TRUE;
CREATE INDEX IF NOT EXISTS idx_kurs_yayinda_aktif ON kurslar(kurs_id) WHERE yayinda = TRUE;
CREATE INDEX IF NOT EXISTS idx_kayit_aktif ON kayitlar(kurs_id) WHERE durum = 'aktif';
CREATE INDEX IF NOT EXISTS idx_odeme_basarili ON odemeler(ogrenci_id, tutar) WHERE durum = 'basarili';

\echo '  Partial indeksler olusturuldu'

\echo '--- 4. Covering Indeksler ---'

CREATE INDEX IF NOT EXISTS idx_kurs_cover_liste ON kurslar(kategori_id, seviye) INCLUDE (kurs_adi, fiyat, ort_puan);
CREATE INDEX IF NOT EXISTS idx_odeme_cover_rapor ON odemeler(odeme_tarihi, durum) INCLUDE (tutar, odeme_yontemi);

\echo '  Covering indeksler olusturuldu'

\echo '--- 5. Text Arama Indeksi ---'

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_kurs_adi_trgm ON kurslar USING gin(kurs_adi gin_trgm_ops);

\echo '  Text arama indeksi olusturuldu'

ANALYZE;

\echo '--- Indeks Ozeti ---'
SELECT schemaname, tablename, indexname, 
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS boyut
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexname::regclass) DESC;

SELECT 'Toplam indeks sayisi: ' || COUNT(*)::TEXT AS bilgi
FROM pg_indexes WHERE schemaname = 'public';

SELECT 'Toplam indeks boyutu: ' || pg_size_pretty(SUM(pg_relation_size(indexname::regclass)))
FROM pg_indexes WHERE schemaname = 'public';

\timing off
\echo '=== Indeksleme tamamlandi ==='
