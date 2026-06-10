
\c egitim_db;
\timing on

\echo '=========================================='
\echo '  SORGU OPTIMIZASYONU (INDEKS SONRASI)'
\echo '=========================================='

\echo '=== SORGU 1: Sehre gore arama (INDEKSLI) ==='
EXPLAIN ANALYZE
SELECT * FROM ogrenciler WHERE sehir = 'Istanbul';

\echo '=== SORGU 2: Kurs-Egitmen-Kategori (INDEKSLI) ==='
EXPLAIN ANALYZE
SELECT k.kurs_adi, e.ad || ' ' || e.soyad AS egitmen,
       kat.kategori_adi, k.fiyat, k.ogrenci_sayisi
FROM kurslar k
JOIN egitmenler e ON k.egitmen_id = e.egitmen_id
JOIN kategoriler kat ON k.kategori_id = kat.kategori_id
WHERE k.seviye = 'ileri' AND k.yayinda = TRUE;

\echo '=== SORGU 3: Kategori bazli gelir (INDEKSLI) ==='
EXPLAIN ANALYZE
SELECT kat.kategori_adi,
       COUNT(DISTINCT k.kurs_id) AS kurs_sayisi,
       COUNT(ky.kayit_id) AS toplam_kayit,
       ROUND(AVG(ky.odenen_tutar)::NUMERIC, 2) AS ort_gelir,
       ROUND(SUM(ky.odenen_tutar)::NUMERIC, 2) AS toplam_gelir
FROM kategoriler kat
JOIN kurslar k ON kat.kategori_id = k.kategori_id
JOIN kayitlar ky ON k.kurs_id = ky.kurs_id
WHERE ky.durum = 'aktif'
GROUP BY kat.kategori_adi
ORDER BY toplam_gelir DESC;

\echo '=== SORGU 4: CTE ile en cok kazanan egitmenler (OPTIMIZE) ==='
EXPLAIN ANALYZE
WITH egitmen_gelir AS (
    SELECT k.egitmen_id,
           COUNT(DISTINCT k.kurs_id) AS kurs_sayisi,
           COALESCE(SUM(o.tutar), 0) AS toplam_gelir
    FROM kurslar k
    LEFT JOIN odemeler o ON k.kurs_id = o.kurs_id AND o.durum = 'basarili'
    GROUP BY k.egitmen_id
)
SELECT e.ad || ' ' || e.soyad AS egitmen, e.uzmanlik,
       eg.kurs_sayisi, eg.toplam_gelir
FROM egitmenler e
JOIN egitmen_gelir eg ON e.egitmen_id = eg.egitmen_id
WHERE e.aktif = TRUE
ORDER BY eg.toplam_gelir DESC
LIMIT 10;

\echo '=== SORGU 5: Tarih aralik sorgusu (INDEKSLI) ==='
EXPLAIN ANALYZE
SELECT DATE(odeme_tarihi) AS gun,
       COUNT(*) AS islem_sayisi,
       SUM(tutar) AS toplam_tutar,
       odeme_yontemi
FROM odemeler
WHERE odeme_tarihi >= CURRENT_TIMESTAMP - INTERVAL '30 days'
  AND durum = 'basarili'
GROUP BY DATE(odeme_tarihi), odeme_yontemi
ORDER BY gun DESC;

\echo '=== SORGU 6: Materialized View olusturma ==='

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_kurs_istatistik AS
SELECT k.kurs_id, k.kurs_adi, e.ad || ' ' || e.soyad AS egitmen,
       kat.kategori_adi, k.seviye, k.fiyat,
       COUNT(DISTINCT ky.kayit_id) AS kayit_sayisi,
       ROUND(AVG(d.puan)::NUMERIC, 2) AS ort_puan,
       COALESCE(SUM(CASE WHEN od.durum = 'basarili' THEN od.tutar ELSE 0 END), 0) AS toplam_gelir
FROM kurslar k
LEFT JOIN egitmenler e ON k.egitmen_id = e.egitmen_id
LEFT JOIN kategoriler kat ON k.kategori_id = kat.kategori_id
LEFT JOIN kayitlar ky ON k.kurs_id = ky.kurs_id
LEFT JOIN degerlendirmeler d ON k.kurs_id = d.kurs_id
LEFT JOIN odemeler od ON k.kurs_id = od.kurs_id
GROUP BY k.kurs_id, k.kurs_adi, e.ad, e.soyad, kat.kategori_adi, k.seviye, k.fiyat;

CREATE INDEX IF NOT EXISTS idx_mv_kurs_kategori ON mv_kurs_istatistik(kategori_adi);
CREATE INDEX IF NOT EXISTS idx_mv_kurs_gelir ON mv_kurs_istatistik(toplam_gelir DESC);

\echo '  Materialized View: Oncesi vs Sonrasi'
\echo '  ONCESI (5 JOIN sorgusu):'
EXPLAIN ANALYZE
SELECT kat.kategori_adi, COUNT(*), SUM(od.tutar)
FROM kurslar k
JOIN kategoriler kat ON k.kategori_id = kat.kategori_id
JOIN odemeler od ON k.kurs_id = od.kurs_id
WHERE od.durum = 'basarili'
GROUP BY kat.kategori_adi;

\echo '  SONRASI (Materialized View):'
EXPLAIN ANALYZE
SELECT kategori_adi, COUNT(*) AS kurs, SUM(toplam_gelir) AS gelir
FROM mv_kurs_istatistik
GROUP BY kategori_adi;

\echo '=== SORGU 7: Text arama - trgm indeksli ==='
EXPLAIN ANALYZE
SELECT kurs_id, kurs_adi, fiyat
FROM kurslar
WHERE kurs_adi LIKE '%Python%';

\echo '=== SORGU 8a: IN kullanimi ==='
EXPLAIN ANALYZE
SELECT o.ad || ' ' || o.soyad AS ogrenci
FROM ogrenciler o
WHERE o.ogrenci_id IN (
    SELECT DISTINCT ogrenci_id FROM kayitlar WHERE durum = 'tamamlandi'
)
LIMIT 20;

\echo '=== SORGU 8b: EXISTS kullanimi (genellikle daha hizli) ==='
EXPLAIN ANALYZE
SELECT o.ad || ' ' || o.soyad AS ogrenci
FROM ogrenciler o
WHERE EXISTS (
    SELECT 1 FROM kayitlar ky WHERE ky.ogrenci_id = o.ogrenci_id AND ky.durum = 'tamamlandi'
)
LIMIT 20;

\timing off
\echo '=== Sorgu optimizasyonu tamamlandi ==='
