
\c hastane_db;

INSERT INTO bolumler (bolum_adi, kat_no, telefon) VALUES
('Dahiliye', 1, '0312-555-1001'), ('Kardiyoloji', 2, '0312-555-1002'),
('Ortopedi', 3, '0312-555-1003'), ('Noroloji', 2, '0312-555-1004'),
('Genel Cerrahi', 4, '0312-555-1005'), ('Goz Hastaliklari', 1, '0312-555-1006'),
('KBB', 1, '0312-555-1007'), ('Uroloji', 3, '0312-555-1008'),
('Dermatoloji', 1, '0312-555-1009'), ('Pediatri', 2, '0312-555-1010'),
('Gogus Hastaliklari', 3, '0312-555-1011'), ('Psikiyatri', 4, '0312-555-1012'),
('Fizik Tedavi', 1, '0312-555-1013'), ('Acil Servis', 0, '0312-555-1014'),
('Yogun Bakim', 4, '0312-555-1015');

INSERT INTO doktorlar (tc_kimlik, ad, soyad, uzmanlik, bolum_id, telefon, email, ise_baslama_tarihi)
SELECT
    LPAD((10000000000 + i)::TEXT, 11, '0'),
    (ARRAY['Ahmet','Mehmet','Ali','Mustafa','Hasan','Fatma','Ayse','Zeynep','Elif','Deniz',
           'Burak','Can','Emre','Serkan','Tolga','Selin','Merve','Gul','Kemal','Nuri'])[1 + (i % 20)],
    (ARRAY['Yilmaz','Kaya','Demir','Celik','Sahin','Ozturk','Aydin','Ozdemir','Arslan','Dogan',
           'Kilic','Aslan','Cetin','Koc','Kurt'])[1 + (i % 15)],
    (ARRAY['Dahiliye Uzmani','Kardiyolog','Ortopedist','Norolog','Genel Cerrah',
           'Goz Uzmani','KBB Uzmani','Urolog','Dermatolog','Pediatrist',
           'Gogus Uzmani','Psikiyatrist','Fizik Tedavi Uzmani','Acil Tip Uzmani','Anestezist'])[1 + (i % 15)],
    1 + (i % 15),
    '05' || (300 + (i % 100))::TEXT || LPAD((1000 + i)::TEXT, 7, '0'),
    'dr' || i || '@hastane.com',
    CURRENT_DATE - (INTERVAL '1 year' * (1 + (i % 20)))
FROM generate_series(1, 50) AS s(i);

INSERT INTO hastalar (tc_kimlik, ad, soyad, dogum_tarihi, cinsiyet, kan_grubu, telefon, email, adres, sehir, acil_kisi_adi, acil_kisi_tel)
SELECT
    LPAD((20000000000 + i)::TEXT, 11, '0'),
    (ARRAY['Ahmet','Mehmet','Ali','Veli','Hasan','Fatma','Ayse','Zeynep','Elif','Deniz',
           'Burak','Can','Emre','Arda','Yusuf','Selin','Merve','Busra','Gokhan','Onur',
           'Sinan','Berk','Kaan','Cem','Ozan','Derya','Pinar','Hulya','Tugba','Esra'])[1 + (i % 30)],
    (ARRAY['Yilmaz','Kaya','Demir','Celik','Sahin','Ozturk','Aydin','Ozdemir','Arslan','Dogan',
           'Kilic','Aslan','Cetin','Koc','Kurt','Ozkan','Simsek','Polat','Korkmaz','Yildiz'])[1 + (i % 20)],
    CURRENT_DATE - (INTERVAL '1 year' * (1 + (i % 80))),
    CASE WHEN i % 2 = 0 THEN 'E' ELSE 'K' END,
    (ARRAY['A+','A-','B+','B-','AB+','AB-','0+','0-'])[1 + (i % 8)],
    '05' || (300 + (i % 100))::TEXT || LPAD((2000 + i)::TEXT, 7, '0'),
    'hasta' || i || '@email.com',
    'Mahalle Cad. No:' || (i % 200 + 1),
    (ARRAY['Istanbul','Ankara','Izmir','Bursa','Antalya','Adana','Konya','Gaziantep','Mersin','Kayseri',
           'Eskisehir','Trabzon','Samsun','Denizli','Sakarya'])[1 + (i % 15)],
    'Yakin ' || i,
    '05' || (300 + (i % 50))::TEXT || LPAD((9000 + i)::TEXT, 7, '0')
FROM generate_series(1, 600) AS s(i);

INSERT INTO ilaclar (ilac_adi, etken_madde, ilac_formu, dozaj, uretici, fiyat, stok_miktari, min_stok)
SELECT
    (ARRAY['Aspirin','Parol','Majezik','Augmentin','Cipro','Voltaren','Nexium','Coraspin',
           'Lansor','Prednol','Xanax','Prozac','Amoklavin','Dikloron','Arveles',
           'Nurofen','Tylol','Vermidon','Aferin','Gripin'])[1 + (i % 20)] || '-' || ((i/20)+1)::TEXT,
    (ARRAY['Asetilsalisilik Asit','Parasetamol','Flurbiprofen','Amoksisilin','Siprofloksasin',
           'Diklofenak','Esomeprazol','ASA','Lansoprazol','Metilprednizolon'])[1 + (i % 10)],
    (ARRAY['Tablet','Kapsul','Surup','Ampul','Krem','Damla','Sprey','Supozituvar'])[1 + (i % 8)],
    (ARRAY['500mg','250mg','100mg','50mg','20mg','10mg','5mg','1000mg'])[1 + (i % 8)],
    (ARRAY['Bayer','Eczacibasi','Abdi Ibrahim','Pfizer','Novartis','Roche','GSK','Sanofi','Deva','Bilim'])[1 + (i % 10)],
    ROUND((5 + random() * 200)::NUMERIC, 2),
    (50 + (random() * 500)::INTEGER),
    (10 + (random() * 40)::INTEGER)
FROM generate_series(1, 100) AS s(i);

INSERT INTO randevular (hasta_id, doktor_id, randevu_tarihi, durum)
SELECT
    1 + (i % 600),
    1 + (i % 50),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER)
        + (INTERVAL '1 hour' * (8 + (i % 10))),
    (ARRAY['beklemede','onaylandi','tamamlandi','tamamlandi','tamamlandi','iptal'])[1 + (i % 6)]
FROM generate_series(1, 3000) AS s(i);

INSERT INTO muayeneler (randevu_id, hasta_id, doktor_id, muayene_tarihi, sikayet, tani, tedavi, ucret)
SELECT
    i,
    r.hasta_id,
    r.doktor_id,
    r.randevu_tarihi + INTERVAL '15 minutes',
    (ARRAY['Bas agrisi','Karin agrisi','Ates','Oksuruk','Halsizlik','Sirt agrisi',
           'Gorme bozuklugu','Kulak agrisi','Cilt dokuntusu','Nefes darligi'])[1 + (i % 10)],
    (ARRAY['Migren','Gastrit','Ust solunum yolu enfeksiyonu','Bronist','Anemi',
           'Disk hernisi','Miyopi','Otit','Dermatit','Astim'])[1 + (i % 10)],
    (ARRAY['Ilac tedavisi','Fizik tedavi','Cerrahi','Takip','Diyet'])[1 + (i % 5)],
    ROUND((50 + random() * 500)::NUMERIC, 2)
FROM generate_series(1, 2000) AS s(i)
JOIN randevular r ON r.randevu_id = i
WHERE r.durum = 'tamamlandi';

INSERT INTO yatislar (hasta_id, doktor_id, bolum_id, oda_no, yatak_no, giris_tarihi, cikis_tarihi, tani, durum, gunluk_ucret)
SELECT
    1 + (i % 600),
    1 + (i % 50),
    1 + (i % 15),
    (100 + (i % 50))::TEXT,
    (ARRAY['A','B','C','D'])[1 + (i % 4)] || (1 + (i % 3))::TEXT,
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (10 + (random() * 355)::INTEGER)),
    CASE WHEN i % 4 != 0 THEN
        CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 10)::INTEGER)
    ELSE NULL END,
    (ARRAY['Ameliyat sonrasi','Yogun bakim','Gozlem altinda','Tedavi sureci'])[1 + (i % 4)],
    CASE WHEN i % 4 != 0 THEN 'taburcu' ELSE 'yatili' END,
    ROUND((300 + random() * 700)::NUMERIC, 2)
FROM generate_series(1, 300) AS s(i);

INSERT INTO receteler (muayene_id, hasta_id, doktor_id, ilac_id, miktar, kullanim_sekli, gun_sayisi)
SELECT
    CASE WHEN i <= (SELECT COUNT(*) FROM muayeneler) THEN i ELSE 1 + (i % (SELECT COUNT(*) FROM muayeneler)) END,
    1 + (i % 600),
    1 + (i % 50),
    1 + (i % 100),
    1 + (i % 3),
    (ARRAY['Gunde 3x1','Gunde 2x1','Gunde 1x1','Gunde 3x2','Sabah-aksam'])[1 + (i % 5)],
    (ARRAY[5,7,10,14,21,30])[1 + (i % 6)]
FROM generate_series(1, 3000) AS s(i);

INSERT INTO faturalar (hasta_id, fatura_tarihi, toplam_tutar, odeme_durumu, odeme_yontemi, aciklama)
SELECT
    1 + (i % 600),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER),
    ROUND((100 + random() * 5000)::NUMERIC, 2),
    (ARRAY['odendi','odendi','odendi','beklemede','kismi_odendi'])[1 + (i % 5)],
    (ARRAY['nakit','kredi_karti','sigorta','havale'])[1 + (i % 4)],
    'Muayene ve tedavi ucreti'
FROM generate_series(1, 1500) AS s(i);

SELECT '=== HASTANE DB VERI YUKLEME RAPORU ===' AS bilgi;
SELECT 'Bolumler' AS tablo, COUNT(*) AS kayit FROM bolumler
UNION ALL SELECT 'Doktorlar', COUNT(*) FROM doktorlar
UNION ALL SELECT 'Hastalar', COUNT(*) FROM hastalar
UNION ALL SELECT 'Ilaclar', COUNT(*) FROM ilaclar
UNION ALL SELECT 'Randevular', COUNT(*) FROM randevular
UNION ALL SELECT 'Muayeneler', COUNT(*) FROM muayeneler
UNION ALL SELECT 'Yatislar', COUNT(*) FROM yatislar
UNION ALL SELECT 'Receteler', COUNT(*) FROM receteler
UNION ALL SELECT 'Faturalar', COUNT(*) FROM faturalar;

SELECT 'Toplam' AS bilgi,
    (SELECT COUNT(*) FROM bolumler) + (SELECT COUNT(*) FROM doktorlar) +
    (SELECT COUNT(*) FROM hastalar) + (SELECT COUNT(*) FROM ilaclar) +
    (SELECT COUNT(*) FROM randevular) + (SELECT COUNT(*) FROM muayeneler) +
    (SELECT COUNT(*) FROM yatislar) + (SELECT COUNT(*) FROM receteler) +
    (SELECT COUNT(*) FROM faturalar) AS toplam_kayit;
