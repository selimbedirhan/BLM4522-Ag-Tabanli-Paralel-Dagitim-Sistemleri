-- ============================================================================
-- BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- Dosya: 01_veritabani_olustur.sql
-- Açıklama: E-Ticaret veritabanı şeması oluşturma
-- Veritabanı: PostgreSQL 14
-- ============================================================================

-- Mevcut veritabanını temizle (varsa)
DROP DATABASE IF EXISTS eticaret_db;

-- Yeni veritabanı oluştur
CREATE DATABASE eticaret_db
    WITH 
    ENCODING = 'UTF8'
    TEMPLATE = template0;

-- Veritabanına bağlan
\c eticaret_db;

-- ============================================================================
-- TABLO OLUŞTURMA
-- ============================================================================

-- 1. Kategoriler Tablosu
CREATE TABLE kategoriler (
    kategori_id SERIAL PRIMARY KEY,
    kategori_adi VARCHAR(100) NOT NULL,
    ust_kategori_id INTEGER REFERENCES kategoriler(kategori_id),
    aciklama TEXT,
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    guncelleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE kategoriler IS 'Ürün kategorilerini tutan tablo';

-- 2. Musteriler Tablosu
CREATE TABLE musteriler (
    musteri_id SERIAL PRIMARY KEY,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefon VARCHAR(20),
    sifre_hash VARCHAR(255) NOT NULL,
    adres_satir1 VARCHAR(200),
    adres_satir2 VARCHAR(200),
    sehir VARCHAR(100),
    ilce VARCHAR(100),
    posta_kodu VARCHAR(10),
    ulke VARCHAR(50) DEFAULT 'Türkiye',
    kayit_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    son_giris_tarihi TIMESTAMP,
    aktif BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE musteriler IS 'Müşteri bilgilerini tutan tablo';

-- 3. Tedarikçiler Tablosu
CREATE TABLE tedarikciler (
    tedarikci_id SERIAL PRIMARY KEY,
    firma_adi VARCHAR(150) NOT NULL,
    yetkili_adi VARCHAR(100),
    email VARCHAR(100),
    telefon VARCHAR(20),
    adres TEXT,
    sehir VARCHAR(100),
    ulke VARCHAR(50) DEFAULT 'Türkiye',
    vergi_no VARCHAR(20),
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE tedarikciler IS 'Tedarikçi firmalarını tutan tablo';

-- 4. Ürünler Tablosu
CREATE TABLE urunler (
    urun_id SERIAL PRIMARY KEY,
    urun_adi VARCHAR(200) NOT NULL,
    urun_kodu VARCHAR(50) UNIQUE NOT NULL,
    kategori_id INTEGER REFERENCES kategoriler(kategori_id),
    tedarikci_id INTEGER REFERENCES tedarikciler(tedarikci_id),
    aciklama TEXT,
    birim_fiyat DECIMAL(10, 2) NOT NULL CHECK (birim_fiyat >= 0),
    stok_miktari INTEGER DEFAULT 0 CHECK (stok_miktari >= 0),
    min_stok_seviyesi INTEGER DEFAULT 10,
    agirlik_kg DECIMAL(6, 2),
    aktif BOOLEAN DEFAULT TRUE,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    guncelleme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE urunler IS 'Ürün bilgilerini tutan tablo';

-- 5. Siparişler Tablosu
CREATE TABLE siparisler (
    siparis_id SERIAL PRIMARY KEY,
    musteri_id INTEGER NOT NULL REFERENCES musteriler(musteri_id),
    siparis_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    teslim_tarihi TIMESTAMP,
    durum VARCHAR(30) DEFAULT 'beklemede' 
        CHECK (durum IN ('beklemede', 'onaylandi', 'hazirlaniyor', 'kargoda', 'teslim_edildi', 'iptal')),
    toplam_tutar DECIMAL(12, 2) DEFAULT 0,
    kargo_ucreti DECIMAL(8, 2) DEFAULT 0,
    indirim_tutari DECIMAL(8, 2) DEFAULT 0,
    odeme_yontemi VARCHAR(30) CHECK (odeme_yontemi IN ('kredi_karti', 'havale', 'kapida_odeme')),
    kargo_adresi TEXT,
    notlar TEXT,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE siparisler IS 'Sipariş bilgilerini tutan tablo';

-- 6. Sipariş Detayları Tablosu
CREATE TABLE siparis_detaylari (
    detay_id SERIAL PRIMARY KEY,
    siparis_id INTEGER NOT NULL REFERENCES siparisler(siparis_id) ON DELETE CASCADE,
    urun_id INTEGER NOT NULL REFERENCES urunler(urun_id),
    miktar INTEGER NOT NULL CHECK (miktar > 0),
    birim_fiyat DECIMAL(10, 2) NOT NULL,
    indirim_orani DECIMAL(5, 2) DEFAULT 0,
    toplam_fiyat DECIMAL(12, 2) NOT NULL,
    olusturma_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE siparis_detaylari IS 'Sipariş kalemlerini tutan tablo';

-- 7. Ödemeler Tablosu
CREATE TABLE odemeler (
    odeme_id SERIAL PRIMARY KEY,
    siparis_id INTEGER NOT NULL REFERENCES siparisler(siparis_id),
    odeme_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tutar DECIMAL(12, 2) NOT NULL,
    odeme_yontemi VARCHAR(30) NOT NULL,
    odeme_durumu VARCHAR(20) DEFAULT 'beklemede'
        CHECK (odeme_durumu IN ('beklemede', 'onaylandi', 'reddedildi', 'iade')),
    islem_referansi VARCHAR(100),
    notlar TEXT
);

COMMENT ON TABLE odemeler IS 'Ödeme işlemlerini tutan tablo';

-- 8. Stok Hareketleri Tablosu
CREATE TABLE stok_hareketleri (
    hareket_id SERIAL PRIMARY KEY,
    urun_id INTEGER NOT NULL REFERENCES urunler(urun_id),
    hareket_tipi VARCHAR(20) NOT NULL 
        CHECK (hareket_tipi IN ('giris', 'cikis', 'iade', 'sayim_farki', 'fire')),
    miktar INTEGER NOT NULL,
    onceki_stok INTEGER,
    sonraki_stok INTEGER,
    referans_no VARCHAR(50),
    aciklama TEXT,
    islem_tarihi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    kullanici_adi VARCHAR(50)
);

COMMENT ON TABLE stok_hareketleri IS 'Stok giriş/çıkış hareketlerini tutan tablo';

-- ============================================================================
-- İNDEKSLER
-- ============================================================================

-- Müşteri indeksleri
CREATE INDEX idx_musteriler_email ON musteriler(email);
CREATE INDEX idx_musteriler_sehir ON musteriler(sehir);
CREATE INDEX idx_musteriler_kayit_tarihi ON musteriler(kayit_tarihi);

-- Ürün indeksleri
CREATE INDEX idx_urunler_kategori ON urunler(kategori_id);
CREATE INDEX idx_urunler_tedarikci ON urunler(tedarikci_id);
CREATE INDEX idx_urunler_urun_kodu ON urunler(urun_kodu);
CREATE INDEX idx_urunler_fiyat ON urunler(birim_fiyat);

-- Sipariş indeksleri
CREATE INDEX idx_siparisler_musteri ON siparisler(musteri_id);
CREATE INDEX idx_siparisler_tarih ON siparisler(siparis_tarihi);
CREATE INDEX idx_siparisler_durum ON siparisler(durum);

-- Sipariş detay indeksleri
CREATE INDEX idx_siparis_detaylari_siparis ON siparis_detaylari(siparis_id);
CREATE INDEX idx_siparis_detaylari_urun ON siparis_detaylari(urun_id);

-- Ödeme indeksleri
CREATE INDEX idx_odemeler_siparis ON odemeler(siparis_id);
CREATE INDEX idx_odemeler_tarih ON odemeler(odeme_tarihi);

-- Stok hareket indeksleri
CREATE INDEX idx_stok_hareketleri_urun ON stok_hareketleri(urun_id);
CREATE INDEX idx_stok_hareketleri_tarih ON stok_hareketleri(islem_tarihi);

-- ============================================================================
-- GÖRÜNÜMLER (VIEWS)
-- ============================================================================

-- Sipariş Özeti Görünümü
CREATE OR REPLACE VIEW v_siparis_ozeti AS
SELECT 
    s.siparis_id,
    m.ad || ' ' || m.soyad AS musteri_adi,
    m.email,
    s.siparis_tarihi,
    s.durum,
    s.toplam_tutar,
    s.kargo_ucreti,
    s.indirim_tutari,
    (s.toplam_tutar + s.kargo_ucreti - s.indirim_tutari) AS genel_toplam,
    COUNT(sd.detay_id) AS urun_cesidi,
    SUM(sd.miktar) AS toplam_adet
FROM siparisler s
JOIN musteriler m ON s.musteri_id = m.musteri_id
LEFT JOIN siparis_detaylari sd ON s.siparis_id = sd.siparis_id
GROUP BY s.siparis_id, m.ad, m.soyad, m.email, s.siparis_tarihi, 
         s.durum, s.toplam_tutar, s.kargo_ucreti, s.indirim_tutari;

-- Stok Durumu Görünümü
CREATE OR REPLACE VIEW v_stok_durumu AS
SELECT 
    u.urun_id,
    u.urun_kodu,
    u.urun_adi,
    k.kategori_adi,
    t.firma_adi AS tedarikci,
    u.stok_miktari,
    u.min_stok_seviyesi,
    CASE 
        WHEN u.stok_miktari <= 0 THEN 'TÜKENDİ'
        WHEN u.stok_miktari <= u.min_stok_seviyesi THEN 'KRİTİK'
        ELSE 'YETERLI'
    END AS stok_durumu,
    u.birim_fiyat,
    (u.stok_miktari * u.birim_fiyat) AS stok_degeri
FROM urunler u
LEFT JOIN kategoriler k ON u.kategori_id = k.kategori_id
LEFT JOIN tedarikciler t ON u.tedarikci_id = t.tedarikci_id
WHERE u.aktif = TRUE;

-- Günlük Satış Raporu Görünümü
CREATE OR REPLACE VIEW v_gunluk_satis AS
SELECT 
    DATE(s.siparis_tarihi) AS tarih,
    COUNT(DISTINCT s.siparis_id) AS siparis_sayisi,
    SUM(s.toplam_tutar) AS toplam_ciro,
    AVG(s.toplam_tutar) AS ortalama_siparis_tutari,
    COUNT(DISTINCT s.musteri_id) AS benzersiz_musteri
FROM siparisler s
WHERE s.durum NOT IN ('iptal')
GROUP BY DATE(s.siparis_tarihi)
ORDER BY tarih DESC;

-- ============================================================================
-- FONKSİYONLAR
-- ============================================================================

-- Stok güncelleme fonksiyonu
CREATE OR REPLACE FUNCTION fn_stok_guncelle()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE urunler 
        SET stok_miktari = stok_miktari - NEW.miktar,
            guncelleme_tarihi = CURRENT_TIMESTAMP
        WHERE urun_id = NEW.urun_id;
        
        INSERT INTO stok_hareketleri (urun_id, hareket_tipi, miktar, referans_no, aciklama)
        VALUES (NEW.urun_id, 'cikis', NEW.miktar, 
                'SIP-' || NEW.siparis_id, 
                'Sipariş ile stok düşüldü');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Sipariş detayı eklendiğinde stoku otomatik düş
CREATE TRIGGER trg_stok_dusur
    AFTER INSERT ON siparis_detaylari
    FOR EACH ROW
    EXECUTE FUNCTION fn_stok_guncelle();

-- Sipariş toplam tutarını güncelleme fonksiyonu
CREATE OR REPLACE FUNCTION fn_siparis_toplam_guncelle()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE siparisler 
    SET toplam_tutar = (
        SELECT COALESCE(SUM(toplam_fiyat), 0) 
        FROM siparis_detaylari 
        WHERE siparis_id = NEW.siparis_id
    )
    WHERE siparis_id = NEW.siparis_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_siparis_toplam
    AFTER INSERT OR UPDATE ON siparis_detaylari
    FOR EACH ROW
    EXECUTE FUNCTION fn_siparis_toplam_guncelle();

-- ============================================================================
-- Veritabanı oluşturma tamamlandı
-- ============================================================================
SELECT 'Veritabanı şeması başarıyla oluşturuldu!' AS bilgi;

-- Tabloları listele
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
