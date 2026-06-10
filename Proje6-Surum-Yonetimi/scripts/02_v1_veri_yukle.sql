
\c kutuphane_db;

INSERT INTO kategoriler (kategori_adi, aciklama) VALUES
('Roman', 'Yerli ve yabanci romanlar'),('Bilim Kurgu', 'Bilim kurgu ve fantastik'),
('Tarih', 'Tarih kitaplari'),('Bilim', 'Populer bilim ve akademik'),
('Felsefe', 'Felsefe ve dusunce'),('Siir', 'Siir kitaplari'),
('Cocuk', 'Cocuk kitaplari'),('Psikoloji', 'Psikoloji ve kisisel gelisim'),
('Sanat', 'Sanat ve muzik'),('Teknoloji', 'Bilgisayar ve teknoloji'),
('Hukuk', 'Hukuk kitaplari'),('Ekonomi', 'Ekonomi ve isletme');

INSERT INTO yazarlar (ad, soyad, dogum_tarihi, ulke)
SELECT
    (ARRAY['Orhan','Yasar','Elif','Nazim','Sabiha','Ahmet','Halide','Oguz','Peyami',
           'Necip','Resat','Kemal','Aziz','Mehmet','Adalet','Umberto','George','Franz',
           'Albert','Victor','Fyodor','Lev','Ernest','Gabriel','Haruki','Stephen',
           'Isaac','Arthur','Jules','Mark','Jane','Charlotte','Emily','Virginia',
           'Agatha','Paulo','Milan','Italo','Chinua','Yukio'])[i],
    (ARRAY['Pamuk','Kemal','Safak','Hikmet','Sertel','Hamdi','Edib','Atay','Safa',
           'Fazil','Nuri','Tahir','Nesin','Akif','Agaoglu','Eco','Orwell','Kafka',
           'Camus','Hugo','Dostoyevski','Tolstoy','Hemingway','Marquez','Murakami','King',
           'Asimov','Clarke','Verne','Twain','Austen','Bronte','Dickinson','Woolf',
           'Christie','Coelho','Kundera','Calvino','Achebe','Mishima'])[i],
    CURRENT_DATE - (INTERVAL '1 year' * (30 + (i*2))),
    (ARRAY['Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye',
           'Italya','Ingiltere','Avusturya','Fransa','Fransa','Rusya','Rusya',
           'ABD','Kolombiya','Japonya','ABD','ABD','Ingiltere','Ingiltere','Ingiltere',
           'Ingiltere','Ingiltere','Brezilya','Cekya','Italya','Nijerya','Japonya',
           'Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye','Turkiye'])[i]
FROM generate_series(1, 40) AS s(i);

INSERT INTO kitaplar (isbn, baslik, yazar_id, kategori_id, yayin_yili, sayfa_sayisi, kopya_sayisi, mevcut_kopya)
SELECT
    '978-' || LPAD(i::TEXT, 10, '0'),
    (ARRAY['Beyaz Kale','Ince Memed','Baba ve Ogul','Kuyucakli Yusuf','Tutunamayanlar',
           'Saatleri Ayarlama Enstitusu','Huzur','Sinekli Bakkal','Cevdet Bey','Agri Dagi',
           'Simyaci','1984','Suikast','Dune','Yuzuklerin Efendisi'])[1 + (i % 15)]
    || ' - Seri ' || ((i/15)+1)::TEXT,
    1 + (i % 40), 1 + (i % 12),
    1950 + (i % 76),
    100 + (i * 7 % 600),
    1 + (i % 5),
    1 + (i % 4)
FROM generate_series(1, 200) AS s(i);

INSERT INTO uyeler (tc_kimlik, ad, soyad, email, telefon, adres)
SELECT
    LPAD((30000000000 + i)::TEXT, 11, '0'),
    (ARRAY['Ali','Ayse','Mehmet','Fatma','Hasan','Zeynep','Emre','Selin','Burak','Deniz',
           'Can','Merve','Arda','Elif','Kemal','Busra','Ozan','Pinar','Sinan','Gul'])[1 + (i % 20)],
    (ARRAY['Yilmaz','Kaya','Demir','Celik','Sahin','Ozturk','Aydin','Arslan','Dogan','Kilic',
           'Aslan','Koc','Kurt','Ozkan','Polat'])[1 + (i % 15)],
    'uye' || i || '@kutuphane.com',
    '05' || (300 + (i % 100))::TEXT || LPAD((3000+i)::TEXT, 7, '0'),
    'Mahalle Cad. No:' || (i % 100 + 1) || ' - ' ||
    (ARRAY['Ankara','Istanbul','Izmir','Bursa','Antalya'])[1 + (i % 5)]
FROM generate_series(1, 400) AS s(i);

INSERT INTO odunc_islemleri (kitap_id, uye_id, odunc_tarihi, iade_tarihi, beklenen_iade, durum)
SELECT
    1 + (i % 200),
    1 + (i % 400),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER),
    CASE WHEN i % 4 != 0 THEN
        CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 30)::INTEGER)
    ELSE NULL END,
    (CURRENT_DATE - (INTERVAL '1 day' * (random() * 300)::INTEGER) + INTERVAL '15 days')::DATE,
    CASE WHEN i % 4 = 0 THEN 'oduncte'
         WHEN i % 7 = 0 THEN 'gecikti'
         ELSE 'iade_edildi' END
FROM generate_series(1, 2000) AS s(i);

SELECT '=== KUTUPHANE DB v1.0 VERI RAPORU ===' AS bilgi;
SELECT 'Kategoriler' AS tablo, COUNT(*) AS kayit FROM kategoriler
UNION ALL SELECT 'Yazarlar', COUNT(*) FROM yazarlar
UNION ALL SELECT 'Kitaplar', COUNT(*) FROM kitaplar
UNION ALL SELECT 'Uyeler', COUNT(*) FROM uyeler
UNION ALL SELECT 'Odunc Islemleri', COUNT(*) FROM odunc_islemleri;

SELECT 'Toplam' AS bilgi,
    (SELECT COUNT(*) FROM kategoriler) + (SELECT COUNT(*) FROM yazarlar) +
    (SELECT COUNT(*) FROM kitaplar) + (SELECT COUNT(*) FROM uyeler) +
    (SELECT COUNT(*) FROM odunc_islemleri) AS kayit;
