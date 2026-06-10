
DROP DATABASE IF EXISTS sosyal_medya_replica;
CREATE DATABASE sosyal_medya_replica WITH ENCODING = 'UTF8' TEMPLATE = template0;

\c sosyal_medya_db;

DROP PUBLICATION IF EXISTS pub_sosyal_medya;

CREATE PUBLICATION pub_sosyal_medya FOR TABLE
    kullanicilar, gonderiler, yorumlar, begeniler,
    takipler, mesajlar, bildirimler, hashtagler, gonderi_hashtag;

DO $$
BEGIN
    PERFORM pg_drop_replication_slot('sub_sosyal_medya');
EXCEPTION WHEN OTHERS THEN
END;
$$;
SELECT pg_create_logical_replication_slot('sub_sosyal_medya', 'pgoutput');

SELECT '=== PUBLICATION ===' AS bilgi;
SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete
FROM pg_publication WHERE pubname = 'pub_sosyal_medya';

SELECT '=== Yayin tablolari ===' AS bilgi;
SELECT schemaname, tablename FROM pg_publication_tables
WHERE pubname = 'pub_sosyal_medya' ORDER BY tablename;

\c sosyal_medya_replica;

CREATE TABLE kullanicilar (
    kullanici_id SERIAL PRIMARY KEY, kullanici_adi VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL, ad VARCHAR(50) NOT NULL, soyad VARCHAR(50) NOT NULL,
    sifre_hash VARCHAR(255) NOT NULL, profil_foto VARCHAR(300), biyografi TEXT,
    sehir VARCHAR(50), dogum_tarihi DATE, dogrulanmis BOOLEAN DEFAULT FALSE,
    aktif BOOLEAN DEFAULT TRUE, kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    son_giris TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE gonderiler (
    gonderi_id SERIAL PRIMARY KEY, kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    icerik TEXT NOT NULL, medya_url VARCHAR(500),
    medya_tipi VARCHAR(20) CHECK (medya_tipi IN ('resim','video','gif','yok')),
    begeni_sayisi INTEGER DEFAULT 0, yorum_sayisi INTEGER DEFAULT 0,
    paylasim_sayisi INTEGER DEFAULT 0, goruntulenme INTEGER DEFAULT 0,
    gizlilik VARCHAR(20) DEFAULT 'herkese_acik',
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    guncelleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE yorumlar (
    yorum_id SERIAL PRIMARY KEY,
    gonderi_id INTEGER NOT NULL REFERENCES gonderiler(gonderi_id) ON DELETE CASCADE,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    ust_yorum_id INTEGER REFERENCES yorumlar(yorum_id),
    icerik TEXT NOT NULL, begeni_sayisi INTEGER DEFAULT 0,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE begeniler (
    begeni_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    gonderi_id INTEGER REFERENCES gonderiler(gonderi_id) ON DELETE CASCADE,
    yorum_id INTEGER REFERENCES yorumlar(yorum_id) ON DELETE CASCADE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (gonderi_id IS NOT NULL OR yorum_id IS NOT NULL)
);

CREATE TABLE takipler (
    takip_id SERIAL PRIMARY KEY,
    takipci_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    takip_edilen_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(takipci_id, takip_edilen_id),
    CHECK (takipci_id != takip_edilen_id)
);

CREATE TABLE mesajlar (
    mesaj_id SERIAL PRIMARY KEY,
    gonderen_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    alan_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    icerik TEXT NOT NULL, okundu BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bildirimler (
    bildirim_id SERIAL PRIMARY KEY,
    kullanici_id INTEGER NOT NULL REFERENCES kullanicilar(kullanici_id),
    tip VARCHAR(30), referans_id INTEGER, mesaj VARCHAR(300),
    okundu BOOLEAN DEFAULT FALSE, tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hashtagler (
    hashtag_id SERIAL PRIMARY KEY,
    hashtag VARCHAR(100) UNIQUE NOT NULL,
    kullanim_sayisi INTEGER DEFAULT 0,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE gonderi_hashtag (
    gonderi_id INTEGER NOT NULL REFERENCES gonderiler(gonderi_id) ON DELETE CASCADE,
    hashtag_id INTEGER NOT NULL REFERENCES hashtagler(hashtag_id),
    PRIMARY KEY (gonderi_id, hashtag_id)
);

CREATE INDEX idx_rep_gonderi_tarih ON gonderiler(olusturma_tarihi DESC);
CREATE INDEX idx_rep_yorum_gonderi ON yorumlar(gonderi_id);
CREATE INDEX idx_rep_begeni_gonderi ON begeniler(gonderi_id);
CREATE INDEX idx_rep_takip_edilen ON takipler(takip_edilen_id);
CREATE INDEX idx_rep_bildirim_kul ON bildirimler(kullanici_id);

DROP SUBSCRIPTION IF EXISTS sub_sosyal_medya;

CREATE SUBSCRIPTION sub_sosyal_medya
    CONNECTION 'host=localhost dbname=sosyal_medya_db user=selimbedirhanozturk'
    PUBLICATION pub_sosyal_medya
    WITH (create_slot = false, copy_data = true, synchronous_commit = off);

SELECT '=== SUBSCRIPTION ===' AS bilgi;
SELECT subname, subenabled, subconninfo FROM pg_subscription
WHERE subname = 'sub_sosyal_medya';

SELECT 'Logical Replication kuruldu!' AS bilgi;
