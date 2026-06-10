
\c hastane_db;

CREATE OR REPLACE FUNCTION fn_yedekleme_istatistik()
RETURNS TABLE(
    metrik VARCHAR, deger TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Toplam Yedek'::VARCHAR, COUNT(*)::TEXT FROM yedekleme_log
    UNION ALL
    SELECT 'Basarili', COUNT(*)::TEXT FROM yedekleme_log WHERE durum = 'basarili'
    UNION ALL
    SELECT 'Basarisiz', COUNT(*)::TEXT FROM yedekleme_log WHERE durum = 'basarisiz'
    UNION ALL
    SELECT 'Son Yedek Tarihi', COALESCE(TO_CHAR(MAX(yedek_tarihi), 'YYYY-MM-DD HH24:MI:SS'), 'Yok') FROM yedekleme_log WHERE durum = 'basarili'
    UNION ALL
    SELECT 'Ort. Yedek Suresi', COALESCE(ROUND(AVG(sure_saniye)::NUMERIC, 1)::TEXT || ' sn', '0 sn') FROM yedekleme_log WHERE durum = 'basarili'
    UNION ALL
    SELECT 'Toplam Yedek Boyutu', COALESCE(pg_size_pretty(SUM(dosya_boyutu)), '0') FROM yedekleme_log WHERE durum = 'basarili'
    UNION ALL
    SELECT 'Basari Orani', COALESCE(
        ROUND(COUNT(*) FILTER (WHERE durum = 'basarili') * 100.0 / NULLIF(COUNT(*), 0), 1)::TEXT || '%', '0%'
    ) FROM yedekleme_log;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_yedekleme_rapor(gun INTEGER DEFAULT 7)
RETURNS TABLE(
    tarih DATE, tip VARCHAR, dosya VARCHAR, boyut TEXT, sure TEXT, durum VARCHAR, dogrulama TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE(l.yedek_tarihi),
        l.yedek_tipi,
        l.dosya_adi,
        pg_size_pretty(l.dosya_boyutu),
        l.sure_saniye::TEXT || 'sn',
        l.durum,
        CASE WHEN l.dogrulama_durumu = TRUE THEN 'Dogrulandi'
             WHEN l.dogrulama_durumu = FALSE THEN 'Basarisiz'
             ELSE 'Bekliyor' END
    FROM yedekleme_log l
    WHERE l.yedek_tarihi >= CURRENT_TIMESTAMP - (gun || ' days')::INTERVAL
    ORDER BY l.yedek_tarihi DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_yedekleme_uyari_kontrol()
RETURNS TABLE(
    uyari_tipi VARCHAR, mesaj TEXT, oncelik VARCHAR
) AS $$
DECLARE
    son_basarili TIMESTAMP;
    basarisiz_sayisi INTEGER;
    son_boyut BIGINT;
    onceki_boyut BIGINT;
BEGIN
    SELECT MAX(yedek_tarihi) INTO son_basarili
    FROM yedekleme_log WHERE durum = 'basarili';

    IF son_basarili IS NULL THEN
        RETURN QUERY SELECT 'KRITIK'::VARCHAR, 'Hic basarili yedek bulunamadi!'::TEXT, 'YUKSEK'::VARCHAR;
    ELSIF son_basarili < CURRENT_TIMESTAMP - INTERVAL '24 hours' THEN
        RETURN QUERY SELECT 'GECIKME'::VARCHAR,
            ('Son basarili yedek: ' || TO_CHAR(son_basarili, 'YYYY-MM-DD HH24:MI'))::TEXT,
            'YUKSEK'::VARCHAR;
    END IF;

    SELECT COUNT(*) INTO basarisiz_sayisi
    FROM yedekleme_log
    WHERE durum = 'basarisiz' AND yedek_tarihi >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

    IF basarisiz_sayisi > 0 THEN
        RETURN QUERY SELECT 'BASARISIZ'::VARCHAR,
            ('Son 24 saatte ' || basarisiz_sayisi || ' basarisiz yedek var!')::TEXT,
            'YUKSEK'::VARCHAR;
    END IF;

    SELECT dosya_boyutu INTO son_boyut FROM yedekleme_log
    WHERE durum = 'basarili' ORDER BY yedek_tarihi DESC LIMIT 1;
    SELECT dosya_boyutu INTO onceki_boyut FROM yedekleme_log
    WHERE durum = 'basarili' ORDER BY yedek_tarihi DESC OFFSET 1 LIMIT 1;

    IF son_boyut IS NOT NULL AND onceki_boyut IS NOT NULL AND onceki_boyut > 0 THEN
        IF ABS(son_boyut - onceki_boyut) * 100 / onceki_boyut > 50 THEN
            RETURN QUERY SELECT 'BOYUT_ANOMALI'::VARCHAR,
                ('Yedek boyutu %' || ((son_boyut - onceki_boyut) * 100 / onceki_boyut) || ' degisti')::TEXT,
                'ORTA'::VARCHAR;
        END IF;
    END IF;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'NORMAL'::VARCHAR, 'Tum yedeklemeler normal'::TEXT, 'DUSUK'::VARCHAR;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW v_yedekleme_trend AS
SELECT
    DATE(yedek_tarihi) AS tarih,
    COUNT(*) AS toplam,
    COUNT(*) FILTER (WHERE durum = 'basarili') AS basarili,
    COUNT(*) FILTER (WHERE durum = 'basarisiz') AS basarisiz,
    ROUND(AVG(sure_saniye)::NUMERIC, 1) AS ort_sure_sn,
    pg_size_pretty(AVG(dosya_boyutu)::BIGINT) AS ort_boyut,
    pg_size_pretty(SUM(dosya_boyutu)) AS toplam_boyut
FROM yedekleme_log
WHERE yedek_tipi NOT LIKE '%anomali%'
GROUP BY DATE(yedek_tarihi)
ORDER BY tarih DESC;

SELECT '=== Denetim Sistemi Olusturuldu ===' AS bilgi;
SELECT 'fn_yedekleme_istatistik' AS fonksiyon, 'Yedekleme genel istatistikleri' AS aciklama
UNION ALL SELECT 'fn_yedekleme_rapor(N)', 'Son N gunun yedekleme raporu'
UNION ALL SELECT 'fn_yedekleme_uyari_kontrol', 'Uyari durumlarini kontrol eder'
UNION ALL SELECT 'v_yedekleme_trend', 'Gunluk yedekleme trend analizi'
UNION ALL SELECT 'v_yedekleme_ozet', 'Yedekleme ozet gorunumu';
