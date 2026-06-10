
\c sosyal_medya_db;

INSERT INTO kullanicilar (kullanici_adi, email, ad, soyad, sifre_hash, biyografi, sehir, dogum_tarihi, dogrulanmis, son_giris)
SELECT
    'user_' || i,
    'user' || i || '@sosyal.com',
    (ARRAY['Ali','Ayse','Mehmet','Fatma','Hasan','Zeynep','Emre','Selin','Burak','Deniz',
           'Can','Merve','Arda','Elif','Kemal','Busra','Ozan','Pinar','Sinan','Gul'])[1+(i%20)],
    (ARRAY['Yilmaz','Kaya','Demir','Celik','Sahin','Ozturk','Aydin','Arslan','Dogan','Kilic',
           'Aslan','Koc','Kurt','Ozkan','Polat'])[1+(i%15)],
    md5('sifre' || i),
    'Merhaba! Ben sosyal medya kullanicisi #' || i,
    (ARRAY['Istanbul','Ankara','Izmir','Bursa','Antalya','Adana','Konya','Trabzon','Eskisehir','Mersin'])[1+(i%10)],
    CURRENT_DATE - (INTERVAL '1 year' * (18+(i%30))),
    i % 5 = 0,
    CURRENT_TIMESTAMP - (INTERVAL '1 hour' * (random()*720)::INTEGER)
FROM generate_series(1, 2000) AS s(i);

INSERT INTO gonderiler (kullanici_id, icerik, medya_tipi, begeni_sayisi, yorum_sayisi, goruntulenme, gizlilik, olusturma_tarihi)
SELECT
    1+(i%2000),
    (ARRAY['Bugun harika bir gun! ☀️','Yeni projemiz basliyor 🚀','Kahve zamani ☕','Manzara muhtesem 🌄',
           'Kod yaziyorum 💻','Yeni kitap okuyorum 📚','Spor zamani 🏃','Muzik dinliyorum 🎵',
           'Aksamüstu yürüyüsü 🌅','Izmir''de guzel bir gun'])[1+(i%10)] || ' #gonderi' || i,
    (ARRAY['resim','video','gif','yok','resim','resim','yok','resim','video','yok'])[1+(i%10)],
    (random()*500)::INTEGER,
    (random()*50)::INTEGER,
    (random()*10000)::INTEGER,
    (ARRAY['herkese_acik','herkese_acik','herkese_acik','arkadaslar','gizli'])[1+(i%5)],
    CURRENT_TIMESTAMP - (INTERVAL '1 minute' * (random()*525600)::INTEGER)
FROM generate_series(1, 10000) AS s(i);

INSERT INTO yorumlar (gonderi_id, kullanici_id, icerik, begeni_sayisi, olusturma_tarihi)
SELECT
    1+(i%10000), 1+(i%2000),
    (ARRAY['Harika!','Cok guzel','Katiliyorum','Tesekkurler','Super','Bravo','😍','👏','🔥','Muhtesem'])[1+(i%10)],
    (random()*20)::INTEGER,
    CURRENT_TIMESTAMP - (INTERVAL '1 minute' * (random()*300000)::INTEGER)
FROM generate_series(1, 15000) AS s(i);

INSERT INTO begeniler (kullanici_id, gonderi_id, tarih)
SELECT
    1+(i%2000), 1+(i%10000),
    CURRENT_TIMESTAMP - (INTERVAL '1 minute' * (random()*400000)::INTEGER)
FROM generate_series(1, 20000) AS s(i);

INSERT INTO takipler (takipci_id, takip_edilen_id, tarih)
SELECT DISTINCT ON (a, b) a, b,
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random()*365)::INTEGER)
FROM (
    SELECT 1+((i*7)%2000) AS a, 1+((i*13+3)%2000) AS b
    FROM generate_series(1, 10000) AS s(i)
) t WHERE a != b
LIMIT 8000;

INSERT INTO mesajlar (gonderen_id, alan_id, icerik, okundu, tarih)
SELECT
    1+(i%2000),
    1+((i*3+1)%2000),
    'Mesaj icerik ' || i || ' - selam nasılsın?',
    i % 3 = 0,
    CURRENT_TIMESTAMP - (INTERVAL '1 hour' * (random()*2000)::INTEGER)
FROM generate_series(1, 5000) AS s(i)
WHERE 1+(i%2000) != 1+((i*3+1)%2000);

INSERT INTO bildirimler (kullanici_id, tip, referans_id, mesaj, okundu, tarih)
SELECT
    1+(i%2000),
    (ARRAY['begeni','yorum','takip','mesaj','paylasim','sistem'])[1+(i%6)],
    i,
    (ARRAY['Gonderiniz begenildi','Yeni yorum','Yeni takipci','Yeni mesaj','Paylasim','Sistem'])[1+(i%6)],
    i % 4 = 0,
    CURRENT_TIMESTAMP - (INTERVAL '1 hour' * (random()*1000)::INTEGER)
FROM generate_series(1, 10000) AS s(i);

INSERT INTO hashtagler (hashtag, kullanim_sayisi)
SELECT
    '#' || (ARRAY['teknoloji','spor','muzik','sanat','yemek','seyahat','moda','film','kitap','oyun',
                  'python','javascript','flutter','react','devops','ai','data','cloud','linux','docker',
                  'istanbul','ankara','izmir','turkiye','dunya','kahve','futbol','basketbol','yuzme','kosu',
                  'gunaydin','iyigeceler','motivasyon','basari','hedef'])[1+(i%35)] || '_' || ((i/35)+1),
    (random() * 5000)::INTEGER
FROM generate_series(1, 200) AS s(i);

INSERT INTO gonderi_hashtag (gonderi_id, hashtag_id)
SELECT DISTINCT 1+(i%10000), 1+(i%200)
FROM generate_series(1, 15000) AS s(i)
LIMIT 12000;

ANALYZE;

SELECT '=== SOSYAL MEDYA DB VERI RAPORU ===' AS bilgi;
SELECT 'Kullanicilar' AS tablo, COUNT(*) AS kayit FROM kullanicilar
UNION ALL SELECT 'Gonderiler', COUNT(*) FROM gonderiler
UNION ALL SELECT 'Yorumlar', COUNT(*) FROM yorumlar
UNION ALL SELECT 'Begeniler', COUNT(*) FROM begeniler
UNION ALL SELECT 'Takipler', COUNT(*) FROM takipler
UNION ALL SELECT 'Mesajlar', COUNT(*) FROM mesajlar
UNION ALL SELECT 'Bildirimler', COUNT(*) FROM bildirimler
UNION ALL SELECT 'Hashtagler', COUNT(*) FROM hashtagler
UNION ALL SELECT 'Gonderi-Hashtag', COUNT(*) FROM gonderi_hashtag
ORDER BY kayit DESC;
