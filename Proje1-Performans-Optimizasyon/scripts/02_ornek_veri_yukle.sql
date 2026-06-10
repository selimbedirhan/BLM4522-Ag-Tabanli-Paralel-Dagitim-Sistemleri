
\c egitim_db;

INSERT INTO kategoriler (kategori_adi, ust_kategori_id, aciklama) VALUES
('Yazilim Gelistirme', NULL, 'Programlama ve yazilim'),
('Veri Bilimi', NULL, 'Veri analizi ve yapay zeka'),
('Tasarim', NULL, 'Grafik ve web tasarim'),
('Is Dunyasi', NULL, 'Isletme ve yonetim'),
('Kisisel Gelisim', NULL, 'Motivasyon ve gelisim'),
('Python', 1, 'Python programlama'), ('Java', 1, 'Java programlama'),
('JavaScript', 1, 'Web programlama'), ('SQL', 1, 'Veritabani'),
('Machine Learning', 2, 'Makine ogrenmesi'), ('Deep Learning', 2, 'Derin ogrenme'),
('Power BI', 2, 'Veri gorsellestirme'), ('UI/UX', 3, 'Kullanici deneyimi'),
('Grafik', 3, 'Grafik tasarim'), ('Pazarlama', 4, 'Dijital pazarlama'),
('Finans', 4, 'Finansal yonetim'), ('Liderlik', 5, 'Liderlik becerileri'),
('Uretkenlik', 5, 'Zaman yonetimi'), ('DevOps', 1, 'CI/CD ve sunucu'),
('Siber Guvenlik', 1, 'Guvenlik');

INSERT INTO egitmenler (ad, soyad, email, uzmanlik, biyografi, puan)
SELECT
    (ARRAY['Ahmet','Mehmet','Ali','Mustafa','Hasan','Fatma','Ayse','Zeynep','Elif','Deniz',
           'Burak','Can','Emre','Arda','Yusuf','Selin','Merve','Busra','Gokhan','Onur',
           'Sinan','Berk','Kaan','Cem','Ozan','Derya','Pinar','Hulya','Tugba','Esra',
           'Kemal','Nuri','Tolga','Serkan','Ilker','Gamze','Ebru','Banu','Hakan','Volkan'])[1 + (i % 40)],
    (ARRAY['Yilmaz','Kaya','Demir','Celik','Sahin','Ozturk','Aydin','Ozdemir','Arslan','Dogan',
           'Kilic','Aslan','Cetin','Koc','Kurt','Ozkan','Simsek','Polat','Korkmaz','Yildiz'])[1 + (i % 20)],
    'egitmen' || i || '@platform.com',
    (ARRAY['Python','Java','JavaScript','SQL','Machine Learning','Deep Learning','UI/UX',
           'Grafik Tasarim','Pazarlama','Finans','DevOps','Siber Guvenlik','React','Node.js',
           'Flutter','Swift','Kotlin','Go','Rust','C++'])[1 + (i % 20)],
    'Uzman egitmen - ' || i || ' yillik deneyim',
    ROUND((3.0 + random() * 2)::NUMERIC, 2)
FROM generate_series(1, 80) AS s(i);

INSERT INTO kurslar (kurs_adi, egitmen_id, kategori_id, seviye, fiyat, indirimli_fiyat, dil, sure_saat, ders_sayisi, aciklama)
SELECT
    (ARRAY['Sifirdan ','Ileri ','Profesyonel ','Uygulamali ','Kapsamli '])[1 + (i % 5)] ||
    (ARRAY['Python','Java','JavaScript','React','Node.js','SQL','Machine Learning',
           'Deep Learning','Docker','Kubernetes','Flutter','Swift','UI/UX',
           'Grafik Tasarim','Dijital Pazarlama','Excel','Power BI','Git','Linux','AWS'])[1 + (i % 20)] ||
    ' Egitimi - ' || ((i/20)+1)::TEXT,
    1 + (i % 80), 1 + (i % 20),
    (ARRAY['baslangic','orta','ileri','uzman'])[1 + (i % 4)],
    ROUND((49.99 + random() * 450)::NUMERIC, 2),
    ROUND((29.99 + random() * 200)::NUMERIC, 2),
    CASE WHEN i % 10 = 0 THEN 'Ingilizce' ELSE 'Turkce' END,
    ROUND((2 + random() * 58)::NUMERIC, 1),
    (10 + (random() * 200)::INTEGER),
    'Bu kurs ile konuyu detayli ogreneceksiniz. Proje tabanli egitim.'
FROM generate_series(1, 500) AS s(i);

INSERT INTO ogrenciler (ad, soyad, email, sehir, ulke, dogum_tarihi, uyelik_tipi, son_giris)
SELECT
    (ARRAY['Ali','Ayse','Mehmet','Fatma','Hasan','Zeynep','Emre','Selin','Burak','Deniz',
           'Can','Merve','Arda','Elif','Kemal','Busra','Ozan','Pinar','Sinan','Gul',
           'Berk','Kaan','Cem','Derya','Yusuf','Tugba','Tolga','Gamze','Ilker','Ebru'])[1 + (i % 30)],
    (ARRAY['Yilmaz','Kaya','Demir','Celik','Sahin','Ozturk','Aydin','Ozdemir','Arslan','Dogan',
           'Kilic','Aslan','Cetin','Koc','Kurt','Ozkan','Simsek','Polat','Korkmaz','Yildiz'])[1 + (i % 20)],
    'ogrenci' || i || '@email.com',
    (ARRAY['Istanbul','Ankara','Izmir','Bursa','Antalya','Adana','Konya','Gaziantep','Mersin',
           'Kayseri','Eskisehir','Trabzon','Samsun','Denizli','Sakarya','Diyarbakir',
           'Malatya','Erzurum','Van','Elazig'])[1 + (i % 20)],
    'Turkiye',
    CURRENT_DATE - (INTERVAL '1 year' * (18 + (i % 40))),
    (ARRAY['ucretsiz','baslangic','pro','enterprise','ucretsiz','baslangic','pro','ucretsiz'])[1 + (i % 8)],
    CURRENT_TIMESTAMP - (INTERVAL '1 hour' * (random() * 720)::INTEGER)
FROM generate_series(1, 5000) AS s(i);

INSERT INTO kayitlar (ogrenci_id, kurs_id, kayit_tarihi, tamamlanma_orani, sertifika_durumu, odenen_tutar, odeme_yontemi, durum)
SELECT
    1 + (i % 5000), 1 + (i % 500),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER),
    ROUND((random() * 100)::NUMERIC, 2),
    random() > 0.7,
    ROUND((29.99 + random() * 300)::NUMERIC, 2),
    (ARRAY['kredi_karti','havale','paypal','inapp','kupon'])[1 + (i % 5)],
    (ARRAY['aktif','tamamlandi','aktif','aktif','iptal','askida'])[1 + (i % 6)]
FROM generate_series(1, 20000) AS s(i);

INSERT INTO dersler (kurs_id, ders_adi, sira_no, sure_dakika, icerik_tipi, ucretsiz_onizleme)
SELECT
    1 + (i % 500),
    'Ders ' || ((i % 10) + 1)::TEXT || ': ' ||
    (ARRAY['Giris','Temel Kavramlar','Kurulum','Ilk Uygulama','Degiskenler',
           'Fonksiyonlar','Siniflar','Proje 1','Ileri Konular','Final Projesi'])[1 + (i % 10)],
    (i % 10) + 1,
    (5 + (random() * 55)::INTEGER),
    (ARRAY['video','video','video','makale','quiz','video','video','odev','video','canli'])[1 + (i % 10)],
    (i % 10) = 0
FROM generate_series(1, 5000) AS s(i);

INSERT INTO ders_ilerleme (ogrenci_id, ders_id, izleme_suresi, tamamlandi, izleme_tarihi)
SELECT
    1 + (i % 5000), 1 + (i % 5000),
    (random() * 60)::INTEGER,
    random() > 0.4,
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 180)::INTEGER)
FROM generate_series(1, 30000) AS s(i);

INSERT INTO degerlendirmeler (kurs_id, ogrenci_id, puan, yorum, tarih)
SELECT
    1 + (i % 500), 1 + (i % 5000),
    1 + (random() * 4)::INTEGER,
    (ARRAY['Harika kurs!','Cok faydali','Tavsiye ederim','Orta seviye','Beklentimi karsilamadi',
           'Mukemmel anlatim','Projeler cok iyi','Detayli ve kapsamli','Tekrar izleyecegim',
           'Egitmen cok iyi'])[1 + (i % 10)],
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 300)::INTEGER)
FROM generate_series(1, 8000) AS s(i);

INSERT INTO odemeler (ogrenci_id, kurs_id, tutar, odeme_tarihi, odeme_yontemi, durum, islem_no)
SELECT
    1 + (i % 5000), 1 + (i % 500),
    ROUND((29.99 + random() * 400)::NUMERIC, 2),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER),
    (ARRAY['kredi_karti','havale','paypal','inapp','kupon'])[1 + (i % 5)],
    (ARRAY['basarili','basarili','basarili','basarili','basarisiz','iade','beklemede'])[1 + (i % 7)],
    'TXN-' || LPAD(i::TEXT, 8, '0')
FROM generate_series(1, 15000) AS s(i);

ANALYZE;

SELECT '=== EGITIM DB VERI RAPORU ===' AS bilgi;
SELECT 'Egitmenler' AS tablo, COUNT(*) AS kayit FROM egitmenler
UNION ALL SELECT 'Kategoriler', COUNT(*) FROM kategoriler
UNION ALL SELECT 'Kurslar', COUNT(*) FROM kurslar
UNION ALL SELECT 'Ogrenciler', COUNT(*) FROM ogrenciler
UNION ALL SELECT 'Kayitlar', COUNT(*) FROM kayitlar
UNION ALL SELECT 'Dersler', COUNT(*) FROM dersler
UNION ALL SELECT 'Ders Ilerleme', COUNT(*) FROM ders_ilerleme
UNION ALL SELECT 'Degerlendirmeler', COUNT(*) FROM degerlendirmeler
UNION ALL SELECT 'Odemeler', COUNT(*) FROM odemeler
ORDER BY kayit DESC;
