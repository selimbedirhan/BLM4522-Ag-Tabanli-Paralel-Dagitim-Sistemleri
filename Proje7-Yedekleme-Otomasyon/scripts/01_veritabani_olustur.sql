
DROP DATABASE IF EXISTS hastane_db;
CREATE DATABASE hastane_db
    WITH ENCODING = 'UTF8' TEMPLATE = template0;

\c hastane_db;

CREATE TABLE bolumler (
    bolum_id SERIAL PRIMARY KEY,
    bolum_adi VARCHAR(100) NOT NULL,
    kat_no INTEGER,
    telefon VARCHAR(20),
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE doktorlar (
    doktor_id SERIAL PRIMARY KEY,
    tc_kimlik VARCHAR(11) UNIQUE NOT NULL,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    uzmanlik VARCHAR(100) NOT NULL,
    bolum_id INTEGER REFERENCES bolumler(bolum_id),
    telefon VARCHAR(20),
    email VARCHAR(100),
    ise_baslama_tarihi DATE,
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hastalar (
    hasta_id SERIAL PRIMARY KEY,
    tc_kimlik VARCHAR(11) UNIQUE NOT NULL,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    dogum_tarihi DATE,
    cinsiyet CHAR(1) CHECK (cinsiyet IN ('E', 'K')),
    kan_grubu VARCHAR(5),
    telefon VARCHAR(20),
    email VARCHAR(100),
    adres TEXT,
    sehir VARCHAR(50),
    acil_kisi_adi VARCHAR(100),
    acil_kisi_tel VARCHAR(20),
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aktif BOOLEAN DEFAULT TRUE
);

CREATE TABLE randevular (
    randevu_id SERIAL PRIMARY KEY,
    hasta_id INTEGER NOT NULL REFERENCES hastalar(hasta_id),
    doktor_id INTEGER NOT NULL REFERENCES doktorlar(doktor_id),
    randevu_tarihi TIMESTAMP NOT NULL,
    durum VARCHAR(20) DEFAULT 'beklemede'
        CHECK (durum IN ('beklemede', 'onaylandi', 'tamamlandi', 'iptal')),
    notlar TEXT,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE muayeneler (
    muayene_id SERIAL PRIMARY KEY,
    randevu_id INTEGER REFERENCES randevular(randevu_id),
    hasta_id INTEGER NOT NULL REFERENCES hastalar(hasta_id),
    doktor_id INTEGER NOT NULL REFERENCES doktorlar(doktor_id),
    muayene_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sikayet TEXT,
    tani TEXT,
    tedavi TEXT,
    recete TEXT,
    kontrol_tarihi DATE,
    ucret DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE yatislar (
    yatis_id SERIAL PRIMARY KEY,
    hasta_id INTEGER NOT NULL REFERENCES hastalar(hasta_id),
    doktor_id INTEGER NOT NULL REFERENCES doktorlar(doktor_id),
    bolum_id INTEGER NOT NULL REFERENCES bolumler(bolum_id),
    oda_no VARCHAR(10),
    yatak_no VARCHAR(10),
    giris_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cikis_tarihi TIMESTAMP,
    tani TEXT,
    durum VARCHAR(20) DEFAULT 'yatili'
        CHECK (durum IN ('yatili', 'taburcu', 'sevk')),
    gunluk_ucret DECIMAL(10, 2) DEFAULT 500
);

CREATE TABLE ilaclar (
    ilac_id SERIAL PRIMARY KEY,
    ilac_adi VARCHAR(200) NOT NULL,
    etken_madde VARCHAR(200),
    ilac_formu VARCHAR(50),
    dozaj VARCHAR(100),
    uretici VARCHAR(150),
    fiyat DECIMAL(10, 2),
    stok_miktari INTEGER DEFAULT 0,
    min_stok INTEGER DEFAULT 20,
    aktif BOOLEAN DEFAULT TRUE
);

CREATE TABLE receteler (
    recete_id SERIAL PRIMARY KEY,
    muayene_id INTEGER REFERENCES muayeneler(muayene_id),
    hasta_id INTEGER NOT NULL REFERENCES hastalar(hasta_id),
    doktor_id INTEGER NOT NULL REFERENCES doktorlar(doktor_id),
    ilac_id INTEGER NOT NULL REFERENCES ilaclar(ilac_id),
    miktar INTEGER DEFAULT 1,
    kullanim_sekli VARCHAR(200),
    gun_sayisi INTEGER DEFAULT 7,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE faturalar (
    fatura_id SERIAL PRIMARY KEY,
    hasta_id INTEGER NOT NULL REFERENCES hastalar(hasta_id),
    fatura_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    toplam_tutar DECIMAL(12, 2) NOT NULL,
    odeme_durumu VARCHAR(20) DEFAULT 'beklemede'
        CHECK (odeme_durumu IN ('beklemede', 'odendi', 'kismi_odendi', 'iptal')),
    odeme_yontemi VARCHAR(30),
    aciklama TEXT
);

CREATE TABLE yedekleme_log (
    log_id SERIAL PRIMARY KEY,
    yedek_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    yedek_tipi VARCHAR(30) NOT NULL,
    dosya_adi VARCHAR(500),
    dosya_boyutu BIGINT,
    sure_saniye INTEGER,
    durum VARCHAR(20) DEFAULT 'basarili'
        CHECK (durum IN ('basarili', 'basarisiz', 'dogrulandi', 'uyari')),
    hata_mesaji TEXT,
    dogrulama_durumu BOOLEAN,
    dogrulama_tarihi TIMESTAMP,
    sunucu_adi VARCHAR(100) DEFAULT 'localhost',
    veritabani_boyutu BIGINT,
    aciklama TEXT
);

COMMENT ON TABLE yedekleme_log IS 'Yedekleme islemlerinin denetim kayitlari';

CREATE INDEX idx_doktorlar_bolum ON doktorlar(bolum_id);
CREATE INDEX idx_hastalar_tc ON hastalar(tc_kimlik);
CREATE INDEX idx_hastalar_sehir ON hastalar(sehir);
CREATE INDEX idx_randevular_hasta ON randevular(hasta_id);
CREATE INDEX idx_randevular_doktor ON randevular(doktor_id);
CREATE INDEX idx_randevular_tarih ON randevular(randevu_tarihi);
CREATE INDEX idx_muayeneler_hasta ON muayeneler(hasta_id);
CREATE INDEX idx_muayeneler_doktor ON muayeneler(doktor_id);
CREATE INDEX idx_yatislar_hasta ON yatislar(hasta_id);
CREATE INDEX idx_receteler_hasta ON receteler(hasta_id);
CREATE INDEX idx_faturalar_hasta ON faturalar(hasta_id);
CREATE INDEX idx_yedekleme_log_tarih ON yedekleme_log(yedek_tarihi);
CREATE INDEX idx_yedekleme_log_durum ON yedekleme_log(durum);

CREATE OR REPLACE VIEW v_randevu_detay AS
SELECT
    r.randevu_id, h.ad || ' ' || h.soyad AS hasta_adi,
    d.ad || ' ' || d.soyad AS doktor_adi, d.uzmanlik,
    b.bolum_adi, r.randevu_tarihi, r.durum
FROM randevular r
JOIN hastalar h ON r.hasta_id = h.hasta_id
JOIN doktorlar d ON r.doktor_id = d.doktor_id
LEFT JOIN bolumler b ON d.bolum_id = b.bolum_id;

CREATE OR REPLACE VIEW v_yedekleme_ozet AS
SELECT
    DATE(yedek_tarihi) AS tarih,
    COUNT(*) AS toplam_yedek,
    COUNT(*) FILTER (WHERE durum = 'basarili') AS basarili,
    COUNT(*) FILTER (WHERE durum = 'basarisiz') AS basarisiz,
    ROUND(AVG(sure_saniye)::NUMERIC, 1) AS ort_sure,
    pg_size_pretty(SUM(dosya_boyutu)) AS toplam_boyut
FROM yedekleme_log
GROUP BY DATE(yedek_tarihi)
ORDER BY tarih DESC;

SELECT 'Hastane DB semasi olusturuldu!' AS bilgi;
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;
