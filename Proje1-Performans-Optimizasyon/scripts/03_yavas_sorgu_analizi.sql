
\c egitim_db;

\timing on

\echo '=== SORGU 1: Sehre gore ogrenci arama (indekssiz) ==='
EXPLAIN ANALYZE
SELECT * FROM ogrenciler WHERE sehir = 'Istanbul';

\echo '=== SORGU 2: Kurs-Egitmen-Kategori JOIN (indekssiz) ==='
EXPLAIN ANALYZE
SELECT k.kurs_adi, e.ad || ' ' || e.soyad AS egitmen,
       kat.kategori_adi, k.fiyat, k.ogrenci_sayisi
FROM kurslar k
JOIN egitmenler e ON k.egitmen_id = e.egitmen_id
JOIN kategoriler kat ON k.kategori_id = kat.kategori_id
WHERE k.seviye = 'ileri' AND k.yayinda = TRUE;

\echo '=== SORGU 3: Kategori bazli gelir analizi (indekssiz) ==='
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

\echo '=== SORGU 4: En cok kazanan egitmenler (indekssiz) ==='
EXPLAIN ANALYZE
SELECT e.ad || ' ' || e.soyad AS egitmen, e.uzmanlik,
       (SELECT COUNT(*) FROM kurslar k WHERE k.egitmen_id = e.egitmen_id) AS kurs_sayisi,
       (SELECT COALESCE(SUM(o.tutar), 0) FROM odemeler o
        JOIN kurslar k ON o.kurs_id = k.kurs_id
        WHERE k.egitmen_id = e.egitmen_id AND o.durum = 'basarili') AS toplam_gelir
FROM egitmenler e
WHERE e.aktif = TRUE
ORDER BY toplam_gelir DESC
LIMIT 10;

\echo '=== SORGU 5: Son 30 gun odeme raporu (indekssiz) ==='
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

\echo '=== SORGU 6: Ders ilerleme istatistigi (indekssiz) ==='
EXPLAIN ANALYZE
SELECT o.ad || ' ' || o.soyad AS ogrenci,
       COUNT(di.ilerleme_id) AS izlenen_ders,
       SUM(di.izleme_suresi) AS toplam_sure,
       ROUND(AVG(CASE WHEN di.tamamlandi THEN 100 ELSE 0 END)::NUMERIC, 1) AS tamamlanma_yuzde
FROM ders_ilerleme di
JOIN ogrenciler o ON di.ogrenci_id = o.ogrenci_id
GROUP BY o.ogrenci_id, o.ad, o.soyad
HAVING COUNT(di.ilerleme_id) > 5
ORDER BY toplam_sure DESC
LIMIT 20;

\echo '=== SORGU 7: Kurs adi arama - LIKE (indekssiz) ==='
EXPLAIN ANALYZE
SELECT kurs_id, kurs_adi, fiyat, ort_puan
FROM kurslar
WHERE kurs_adi LIKE '%Python%' OR kurs_adi LIKE '%Java%';

\echo '=== SORGU 8: Ogrenci performans raporu (indekssiz) ==='
EXPLAIN ANALYZE
SELECT o.ogrenci_id, o.ad || ' ' || o.soyad AS ogrenci, o.sehir,
       COUNT(DISTINCT ky.kurs_id) AS alinan_kurs,
       ROUND(AVG(ky.tamamlanma_orani)::NUMERIC, 1) AS ort_ilerleme,
       COALESCE(SUM(od.tutar), 0) AS toplam_harcama,
       COUNT(DISTINCT d.degerlendirme_id) AS degerlendirme_sayisi
FROM ogrenciler o
LEFT JOIN kayitlar ky ON o.ogrenci_id = ky.ogrenci_id
LEFT JOIN odemeler od ON o.ogrenci_id = od.ogrenci_id AND od.durum = 'basarili'
LEFT JOIN degerlendirmeler d ON o.ogrenci_id = d.ogrenci_id
GROUP BY o.ogrenci_id, o.ad, o.soyad, o.sehir
ORDER BY toplam_harcama DESC
LIMIT 15;

\timing off
SELECT '=== Yavas sorgu analizi tamamlandi ===' AS bilgi;
