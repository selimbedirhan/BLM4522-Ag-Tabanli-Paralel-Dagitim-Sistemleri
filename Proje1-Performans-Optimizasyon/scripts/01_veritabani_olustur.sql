
DROP DATABASE IF EXISTS egitim_db;
CREATE DATABASE egitim_db WITH ENCODING = 'UTF8' TEMPLATE = template0;

\c egitim_db;

CREATE TABLE egitmenler (
    egitmen_id SERIAL PRIMARY KEY,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    uzmanlik VARCHAR(100),
    biyografi TEXT,
    puan DECIMAL(3,2) DEFAULT 0,
    aktif BOOLEAN DEFAULT TRUE,
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kategoriler (
    kategori_id SERIAL PRIMARY KEY,
    kategori_adi VARCHAR(100) NOT NULL,
    ust_kategori_id INTEGER REFERENCES kategoriler(kategori_id),
    aciklama TEXT
);

CREATE TABLE kurslar (
    kurs_id SERIAL PRIMARY KEY,
    kurs_adi VARCHAR(300) NOT NULL,
    egitmen_id INTEGER NOT NULL REFERENCES egitmenler(egitmen_id),
    kategori_id INTEGER REFERENCES kategoriler(kategori_id),
    seviye VARCHAR(20) CHECK (seviye IN ('baslangic','orta','ileri','uzman')),
    fiyat DECIMAL(10,2) DEFAULT 0,
    indirimli_fiyat DECIMAL(10,2),
    dil VARCHAR(30) DEFAULT 'Turkce',
    sure_saat DECIMAL(5,1),
    ders_sayisi INTEGER DEFAULT 0,
    ort_puan DECIMAL(3,2) DEFAULT 0,
    ogrenci_sayisi INTEGER DEFAULT 0,
    aciklama TEXT,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    guncelleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    yayinda BOOLEAN DEFAULT TRUE
);

CREATE TABLE ogrenciler (
    ogrenci_id SERIAL PRIMARY KEY,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    sehir VARCHAR(50),
    ulke VARCHAR(50) DEFAULT 'Turkiye',
    dogum_tarihi DATE,
    uyelik_tipi VARCHAR(20) DEFAULT 'ucretsiz'
        CHECK (uyelik_tipi IN ('ucretsiz','baslangic','pro','enterprise')),
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    son_giris TIMESTAMP,
    aktif BOOLEAN DEFAULT TRUE
);

CREATE TABLE kayitlar (
    kayit_id SERIAL PRIMARY KEY,
    ogrenci_id INTEGER NOT NULL REFERENCES ogrenciler(ogrenci_id),
    kurs_id INTEGER NOT NULL REFERENCES kurslar(kurs_id),
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tamamlanma_orani DECIMAL(5,2) DEFAULT 0,
    sertifika_durumu BOOLEAN DEFAULT FALSE,
    odenen_tutar DECIMAL(10,2),
    odeme_yontemi VARCHAR(30),
    durum VARCHAR(20) DEFAULT 'aktif'
        CHECK (durum IN ('aktif','tamamlandi','iptal','askida'))
);

CREATE TABLE dersler (
    ders_id SERIAL PRIMARY KEY,
    kurs_id INTEGER NOT NULL REFERENCES kurslar(kurs_id),
    ders_adi VARCHAR(300) NOT NULL,
    sira_no INTEGER,
    sure_dakika INTEGER,
    video_url VARCHAR(500),
    icerik_tipi VARCHAR(20) DEFAULT 'video'
        CHECK (icerik_tipi IN ('video','makale','quiz','odev','canli')),
    ucretsiz_onizleme BOOLEAN DEFAULT FALSE
);

CREATE TABLE ders_ilerleme (
    ilerleme_id SERIAL PRIMARY KEY,
    ogrenci_id INTEGER NOT NULL REFERENCES ogrenciler(ogrenci_id),
    ders_id INTEGER NOT NULL REFERENCES dersler(ders_id),
    izleme_suresi INTEGER DEFAULT 0,
    tamamlandi BOOLEAN DEFAULT FALSE,
    izleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE degerlendirmeler (
    degerlendirme_id SERIAL PRIMARY KEY,
    kurs_id INTEGER NOT NULL REFERENCES kurslar(kurs_id),
    ogrenci_id INTEGER NOT NULL REFERENCES ogrenciler(ogrenci_id),
    puan INTEGER NOT NULL CHECK (puan BETWEEN 1 AND 5),
    yorum TEXT,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE odemeler (
    odeme_id SERIAL PRIMARY KEY,
    ogrenci_id INTEGER NOT NULL REFERENCES ogrenciler(ogrenci_id),
    kurs_id INTEGER REFERENCES kurslar(kurs_id),
    tutar DECIMAL(10,2) NOT NULL,
    odeme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    odeme_yontemi VARCHAR(30),
    durum VARCHAR(20) DEFAULT 'basarili'
        CHECK (durum IN ('basarili','basarisiz','iade','beklemede')),
    islem_no VARCHAR(50)
);

CREATE TABLE performans_log (
    log_id SERIAL PRIMARY KEY,
    sorgu_adi VARCHAR(200),
    calisma_suresi_ms DECIMAL(10,2),
    satir_sayisi INTEGER,
    indeks_kullanimi BOOLEAN,
    plan_tipi VARCHAR(50),
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notlar TEXT
);

SELECT 'Egitim DB olusturuldu!' AS bilgi;
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;
