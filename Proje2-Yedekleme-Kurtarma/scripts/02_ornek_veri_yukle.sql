
\c eticaret_db;

INSERT INTO kategoriler (kategori_adi, ust_kategori_id, aciklama) VALUES
('Elektronik', NULL, 'Elektronik ürünler ana kategori'),
('Giyim', NULL, 'Giyim ve moda ürünleri'),
('Ev & Yaşam', NULL, 'Ev dekorasyon ve yaşam ürünleri'),
('Spor & Outdoor', NULL, 'Spor malzemeleri ve outdoor ürünleri'),
('Kitap & Kırtasiye', NULL, 'Kitaplar ve kırtasiye malzemeleri');

INSERT INTO kategoriler (kategori_adi, ust_kategori_id, aciklama) VALUES
('Bilgisayar', 1, 'Dizüstü ve masaüstü bilgisayarlar'),
('Telefon', 1, 'Cep telefonları ve aksesuarları'),
('TV & Ses', 1, 'Televizyon ve ses sistemleri'),
('Erkek Giyim', 2, 'Erkek giyim ürünleri'),
('Kadın Giyim', 2, 'Kadın giyim ürünleri'),
('Çocuk Giyim', 2, 'Çocuk giyim ürünleri'),
('Mobilya', 3, 'Ev mobilyaları'),
('Mutfak', 3, 'Mutfak gereçleri'),
('Banyo', 3, 'Banyo ürünleri'),
('Fitness', 4, 'Fitness ekipmanları'),
('Kamp', 4, 'Kamp malzemeleri'),
('Roman', 5, 'Roman kitapları'),
('Ders Kitabı', 5, 'Ders ve akademik kitaplar'),
('Ofis Malzemesi', 5, 'Ofis kırtasiye malzemeleri'),
('Tablet', 1, 'Tablet bilgisayarlar');

INSERT INTO tedarikciler (firma_adi, yetkili_adi, email, telefon, adres, sehir, vergi_no) VALUES
('TeknoPlus A.Ş.', 'Ahmet Yılmaz', 'info@teknoplus.com', '0212-555-0001', 'Levent Mah. No:15', 'İstanbul', '1234567890'),
('ModaLine Ltd.', 'Zeynep Kaya', 'satis@modaline.com', '0216-555-0002', 'Kadıköy Mah. No:25', 'İstanbul', '2345678901'),
('EvDekor A.Ş.', 'Mehmet Demir', 'info@evdekor.com', '0312-555-0003', 'Kızılay Cad. No:30', 'Ankara', '3456789012'),
('SportMax Ltd.', 'Ali Çelik', 'info@sportmax.com', '0232-555-0004', 'Alsancak Mah. No:10', 'İzmir', '4567890123'),
('KitapDünyası A.Ş.', 'Fatma Öz', 'satis@kitapdunya.com', '0312-555-0005', 'Çankaya Cad. No:50', 'Ankara', '5678901234'),
('DigiTech Ltd.', 'Can Aydın', 'info@digitech.com', '0216-555-0006', 'Ataşehir Blv. No:88', 'İstanbul', '6789012345'),
('TextilPro A.Ş.', 'Elif Sarı', 'info@textilpro.com', '0224-555-0007', 'Osmangazi Mah. No:5', 'Bursa', '7890123456'),
('MobilHome Ltd.', 'Burak Tan', 'satis@mobilhome.com', '0322-555-0008', 'Seyhan Cad. No:12', 'Adana', '8901234567'),
('FitZone A.Ş.', 'Deniz Koç', 'info@fitzone.com', '0242-555-0009', 'Lara Cad. No:76', 'Antalya', '9012345678'),
('YayınEvi Ltd.', 'Gül Aksoy', 'info@yayinevi.com', '0312-555-0010', 'Kavaklıdere No:22', 'Ankara', '0123456789'),
('ElektroMarket A.Ş.', 'Hasan Kurt', 'satis@elektromarket.com', '0212-555-0011', 'Şişli Mah. No:40', 'İstanbul', '1122334455'),
('SporAlem Ltd.', 'İrem Bal', 'info@sporalem.com', '0232-555-0012', 'Bornova Cad. No:33', 'İzmir', '2233445566'),
('DekoWorld A.Ş.', 'Kaan Uzun', 'info@dekoworld.com', '0262-555-0013', 'Gebze Mah. No:18', 'Kocaeli', '3344556677'),
('TechStore Ltd.', 'Lale Güneş', 'satis@techstore.com', '0216-555-0014', 'Maltepe Blv. No:55', 'İstanbul', '4455667788'),
('KırtasiyeNet A.Ş.', 'Murat Acar', 'info@kirtasiyenet.com', '0352-555-0015', 'Melikgazi No:9', 'Kayseri', '5566778899');

INSERT INTO musteriler (ad, soyad, email, telefon, sifre_hash, adres_satir1, sehir, ilce, posta_kodu)
SELECT 
    (ARRAY['Ahmet','Mehmet','Ali','Mustafa','Hasan','Hüseyin','İbrahim','Ömer','Fatma','Ayşe',
           'Zeynep','Elif','Emine','Hatice','Merve','Büşra','Selin','Deniz','Can','Emre',
           'Burak','Oğuz','Kaan','Arda','Yusuf','Kemal','Serkan','Tolga','Barış','Cem',
           'Gökhan','Onur','Uğur','Sinan','Ercan','Turgut','Nuri','Volkan','Alper','Berk'])[1 + (i % 40)] AS ad,
    (ARRAY['Yılmaz','Kaya','Demir','Çelik','Şahin','Öztürk','Aydın','Özdemir','Arslan','Doğan',
           'Kılıç','Aslan','Çetin','Koç','Kurt','Özkan','Şimşek','Polat','Korkmaz','Yıldız',
           'Aktaş','Güneş','Aksoy','Yıldırım','Erdoğan','Ünal','Acar','Taş','Çakır','Bal'])[1 + (i % 30)] AS soyad,
    'musteri' || i || '@email.com',
    '05' || (300 + (i % 100))::TEXT || (1000000 + i)::TEXT,
    md5(random()::TEXT),
    'Sokak No: ' || (i % 200 + 1),
    (ARRAY['İstanbul','Ankara','İzmir','Bursa','Antalya','Adana','Konya','Gaziantep','Mersin','Kayseri',
           'Eskişehir','Trabzon','Samsun','Denizli','Malatya','Erzurum','Diyarbakır','Sakarya','Kocaeli','Muğla'])[1 + (i % 20)],
    (ARRAY['Merkez','Kadıköy','Çankaya','Osmangazi','Muratpaşa','Seyhan','Selçuklu','Şahinbey','Akdeniz','Melikgazi',
           'Odunpazarı','Ortahisar','İlkadım','Pamukkale','Battalgazi','Yakutiye','Bağlar','Adapazarı','İzmit','Bodrum'])[1 + (i % 20)],
    (10000 + (i % 80000))::TEXT
FROM generate_series(1, 500) AS s(i);

INSERT INTO urunler (urun_adi, urun_kodu, kategori_id, tedarikci_id, aciklama, birim_fiyat, stok_miktari, min_stok_seviyesi, agirlik_kg) VALUES
('Laptop Pro 15"', 'ELK-001', 6, 1, '15.6 inç, i7 işlemci, 16GB RAM, 512GB SSD', 24999.99, 150, 20, 2.1),
('Laptop Air 13"', 'ELK-002', 6, 1, '13.3 inç, i5 işlemci, 8GB RAM, 256GB SSD', 17499.99, 200, 25, 1.3),
('Gaming Laptop X', 'ELK-003', 6, 6, '17.3 inç, RTX 4060, 32GB RAM, 1TB SSD', 42999.99, 75, 10, 2.8),
('Masaüstü Bilgisayar', 'ELK-004', 6, 1, 'i9 işlemci, 64GB RAM, 2TB SSD', 35999.99, 50, 5, 12.5),
('Smartphone Pro Max', 'ELK-005', 7, 6, '6.7 inç, 256GB, 5G desteği', 34999.99, 300, 50, 0.23),
('Smartphone Lite', 'ELK-006', 7, 14, '6.1 inç, 128GB, 4G', 12999.99, 500, 100, 0.19),
('Smartphone Ultra', 'ELK-007', 7, 6, '6.9 inç, 512GB, S-Pen', 44999.99, 100, 15, 0.25),
('Tablet 10"', 'ELK-008', 20, 1, '10.1 inç, 64GB, WiFi', 8999.99, 200, 30, 0.48),
('Tablet Pro 12"', 'ELK-009', 20, 6, '12.9 inç, 256GB, WiFi+LTE', 22999.99, 80, 10, 0.68),
('Smart TV 55"', 'ELK-010', 8, 11, '55 inç 4K OLED, Smart TV', 18999.99, 120, 15, 15.0),
('Smart TV 65"', 'ELK-011', 8, 11, '65 inç 4K QLED, HDR10+', 27999.99, 60, 10, 22.0),
('Bluetooth Hoparlör', 'ELK-012', 8, 14, 'Taşınabilir, 20 saat pil', 1299.99, 500, 50, 0.35),
('Kablosuz Kulaklık Pro', 'ELK-013', 8, 6, 'ANC, 30 saat pil', 3499.99, 350, 40, 0.25),
('Monitör 27"', 'ELK-014', 6, 1, '27 inç, 4K, IPS Panel', 7999.99, 180, 20, 6.2),
('Kablosuz Mouse', 'ELK-015', 6, 14, 'Ergonomik, Bluetooth', 599.99, 800, 100, 0.12);

INSERT INTO urunler (urun_adi, urun_kodu, kategori_id, tedarikci_id, aciklama, birim_fiyat, stok_miktari, min_stok_seviyesi, agirlik_kg) VALUES
('Erkek Klasik Gömlek', 'GYM-001', 9, 2, '%100 Pamuk, Slim Fit', 349.99, 400, 50, 0.25),
('Erkek Kot Pantolon', 'GYM-002', 9, 7, 'Straight Fit, İndigo', 449.99, 350, 40, 0.65),
('Erkek Kışlık Mont', 'GYM-003', 9, 2, 'Su geçirmez, Kapüşonlu', 1299.99, 200, 25, 1.2),
('Erkek Spor Ayakkabı', 'GYM-004', 9, 7, 'Hafif, Nefes alır taban', 899.99, 300, 40, 0.75),
('Erkek T-Shirt', 'GYM-005', 9, 2, 'Basic, %100 Pamuk', 149.99, 600, 80, 0.18),
('Kadın Elbise', 'GYM-006', 10, 2, 'Yazlık, Çiçek desenli', 599.99, 250, 30, 0.30),
('Kadın Bluz', 'GYM-007', 10, 7, 'Şifon, Kısa kollu', 299.99, 400, 50, 0.15),
('Kadın Jean', 'GYM-008', 10, 2, 'Yüksek bel, Skinny', 499.99, 300, 40, 0.60),
('Kadın Topuklu Ayakkabı', 'GYM-009', 10, 7, '8cm topuk, Deri', 799.99, 200, 25, 0.55),
('Kadın Kışlık Kaban', 'GYM-010', 10, 2, 'Yün karışımlı, Uzun', 1799.99, 150, 20, 1.5),
('Çocuk Eşofman Takımı', 'GYM-011', 11, 7, '6-12 yaş, Pamuklu', 349.99, 300, 40, 0.35),
('Çocuk Tişört', 'GYM-012', 11, 2, 'Baskılı, Renkli', 99.99, 500, 60, 0.12),
('Çocuk Bot', 'GYM-013', 11, 7, 'Su geçirmez, Kışlık', 499.99, 200, 30, 0.45),
('Erkek Takım Elbise', 'GYM-014', 9, 2, 'İtalyan kesim, Slim Fit', 3499.99, 100, 10, 1.8),
('Kadın Spor Ayakkabı', 'GYM-015', 10, 7, 'Yürüyüş, Memory Foam', 749.99, 350, 40, 0.65);

INSERT INTO urunler (urun_adi, urun_kodu, kategori_id, tedarikci_id, aciklama, birim_fiyat, stok_miktari, min_stok_seviyesi, agirlik_kg) VALUES
('Köşe Koltuk Takımı', 'EVY-001', 12, 3, 'L koltuk, Kumaş döşeme', 12999.99, 30, 5, 85.0),
('Yemek Masası Seti', 'EVY-002', 12, 8, '6 kişilik, Ahşap', 5999.99, 40, 8, 45.0),
('Yatak Başlığı', 'EVY-003', 12, 3, 'Kapitone, Gri kadife', 2499.99, 60, 10, 15.0),
('TV Ünitesi', 'EVY-004', 12, 8, 'Modern, 180cm, Ceviz', 3499.99, 50, 10, 35.0),
('Kitaplık', 'EVY-005', 12, 13, '5 raflı, Meşe renk', 1999.99, 70, 12, 25.0),
('Tencere Seti', 'EVY-006', 13, 3, '8 parça, Granit', 1799.99, 200, 30, 8.5),
('Bıçak Seti', 'EVY-007', 13, 13, '6 parça, Paslanmaz çelik', 899.99, 300, 40, 2.0),
('Kahve Makinesi', 'EVY-008', 13, 11, 'Otomatik, 15 bar', 4999.99, 120, 15, 5.5),
('Blender', 'EVY-009', 13, 3, '1000W, 1.5L', 1299.99, 250, 30, 3.2),
('Banyo Dolabı', 'EVY-010', 14, 8, 'Aynalı, 80cm', 2299.99, 80, 10, 18.0),
('Havlu Seti', 'EVY-011', 14, 13, '6 parça, %100 Pamuk', 449.99, 400, 50, 2.5),
('Battaniye', 'EVY-012', 3, 3, 'Polar, Çift kişilik', 349.99, 300, 40, 1.8),
('Yastık Seti', 'EVY-013', 3, 8, '2li, Visco, Ortopedik', 599.99, 250, 30, 2.0),
('Halı 200x300', 'EVY-014', 3, 13, 'El dokuma, Yün', 4999.99, 40, 5, 12.0),
('Aydınlatma Seti', 'EVY-015', 3, 3, 'LED, Sarkıt, 3lü', 899.99, 150, 20, 3.5);

INSERT INTO urunler (urun_adi, urun_kodu, kategori_id, tedarikci_id, aciklama, birim_fiyat, stok_miktari, min_stok_seviyesi, agirlik_kg) VALUES
('Koşu Bandı', 'SPR-001', 15, 9, 'Katlanır, 18km/h, Eğim ayarlı', 8999.99, 40, 5, 65.0),
('Yoga Matı', 'SPR-002', 15, 12, 'TPE, 183x61cm, 6mm', 249.99, 500, 60, 1.2),
('Dambıl Seti', 'SPR-003', 15, 9, '2x10kg, Kauçuk kaplı', 999.99, 200, 25, 20.0),
('Eliptik Bisiklet', 'SPR-004', 15, 12, 'Manyetik, 16 seviye', 5999.99, 30, 5, 45.0),
('Spor Çantası', 'SPR-005', 15, 4, '40L, Su geçirmez', 349.99, 300, 40, 0.8),
('Kamp Çadırı', 'SPR-006', 16, 4, '4 kişilik, Su geçirmez', 1999.99, 100, 15, 4.5),
('Uyku Tulumu', 'SPR-007', 16, 12, '-10°C, Tüylü', 899.99, 150, 20, 1.8),
('Kamp Sandalyesi', 'SPR-008', 16, 4, 'Katlanır, Alüminyum', 299.99, 250, 30, 2.5),
('Termos', 'SPR-009', 16, 9, '1L, Çelik, 24 saat sıcak', 249.99, 400, 50, 0.65),
('Trekking Ayakkabı', 'SPR-010', 4, 4, 'Gore-Tex, Su geçirmez', 1499.99, 180, 20, 1.1),
('Bisiklet', 'SPR-011', 4, 12, 'Dağ bisikleti, 27.5"', 6999.99, 50, 8, 14.0),
('Futbol Topu', 'SPR-012', 4, 4, 'FIFA onaylı, Size 5', 499.99, 300, 40, 0.43),
('Tenis Raketi', 'SPR-013', 4, 9, 'Karbon, 300g', 1299.99, 120, 15, 0.30),
('Yüzme Gözlüğü', 'SPR-014', 4, 12, 'Anti-fog, UV koruma', 149.99, 400, 50, 0.08),
('Pilates Topu', 'SPR-015', 15, 9, '65cm, Anti-burst', 199.99, 350, 40, 1.0);

INSERT INTO urunler (urun_adi, urun_kodu, kategori_id, tedarikci_id, aciklama, birim_fiyat, stok_miktari, min_stok_seviyesi, agirlik_kg) VALUES
('Suç ve Ceza', 'KTB-001', 17, 5, 'Dostoyevski, Türkçe çeviri', 59.99, 500, 60, 0.45),
('1984', 'KTB-002', 17, 10, 'George Orwell, Türkçe', 49.99, 600, 80, 0.32),
('Sefiller', 'KTB-003', 17, 5, 'Victor Hugo, 2 Cilt', 89.99, 300, 40, 0.85),
('Küçük Prens', 'KTB-004', 17, 10, 'Saint-Exupéry, Resimli', 39.99, 800, 100, 0.20),
('Simyacı', 'KTB-005', 17, 5, 'Paulo Coelho', 44.99, 700, 80, 0.28),
('Veri Yapıları', 'KTB-006', 18, 10, 'Algoritma ve Veri Yapıları', 149.99, 200, 25, 0.75),
('Veritabanı Sistemleri', 'KTB-007', 18, 5, 'İlişkisel DB Temelleri', 179.99, 150, 20, 0.82),
('Ağ Programlama', 'KTB-008', 18, 10, 'TCP/IP ve Soket Prog.', 169.99, 120, 15, 0.70),
('Yapay Zeka', 'KTB-009', 18, 5, 'Makine Öğrenmesi Temelleri', 199.99, 180, 20, 0.90),
('İşletim Sistemleri', 'KTB-010', 18, 10, 'Modern İşletim Sistemleri', 159.99, 160, 20, 0.78),
('A4 Kağıt Paketi', 'KTB-011', 19, 15, '500 yaprak, 80gr', 89.99, 1000, 200, 2.5),
('Tükenmez Kalem 12li', 'KTB-012', 19, 15, 'Mavi/Siyah/Kırmızı', 49.99, 800, 100, 0.15),
('Defter A4', 'KTB-013', 19, 15, 'Spiralli, 200 sayfa', 29.99, 600, 80, 0.35),
('Silgi-Kalemtıraş Set', 'KTB-014', 19, 15, '5 parça set', 19.99, 500, 60, 0.10),
('Dosya Klasör', 'KTB-015', 19, 15, 'Geniş, Sırt etiketli', 24.99, 700, 80, 0.30);

INSERT INTO urunler (urun_adi, urun_kodu, kategori_id, tedarikci_id, aciklama, birim_fiyat, stok_miktari, min_stok_seviyesi, agirlik_kg)
SELECT 
    'Ürün-' || (ARRAY['Alfa','Beta','Gama','Delta','Epsilon','Zeta','Eta','Theta','Iota','Kappa'])[1 + (i % 10)] || '-' || i,
    'URN-' || LPAD(i::TEXT, 4, '0'),
    (ARRAY[6,7,8,9,10,11,12,13,14,15,16,17,18,19,20])[1 + (i % 15)],
    1 + (i % 15),
    'Otomatik oluşturulmuş ürün açıklaması #' || i,
    ROUND((50 + random() * 5000)::NUMERIC, 2),
    (20 + (random() * 500)::INTEGER),
    (5 + (random() * 50)::INTEGER),
    ROUND((0.1 + random() * 15)::NUMERIC, 2)
FROM generate_series(1, 125) AS s(i);

INSERT INTO siparisler (musteri_id, siparis_tarihi, durum, odeme_yontemi, kargo_adresi, kargo_ucreti)
SELECT
    1 + (i % 500),
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER) - (INTERVAL '1 hour' * (random() * 24)::INTEGER),
    (ARRAY['beklemede','onaylandi','hazirlaniyor','kargoda','teslim_edildi','teslim_edildi','teslim_edildi','iptal'])[1 + (i % 8)],
    (ARRAY['kredi_karti','havale','kapida_odeme','kredi_karti','kredi_karti'])[1 + (i % 5)],
    'Teslimat Adresi #' || i,
    CASE WHEN random() > 0.3 THEN ROUND((15 + random() * 35)::NUMERIC, 2) ELSE 0 END
FROM generate_series(1, 3000) AS s(i);

ALTER TABLE siparis_detaylari DISABLE TRIGGER trg_stok_dusur;
ALTER TABLE siparis_detaylari DISABLE TRIGGER trg_siparis_toplam;

INSERT INTO siparis_detaylari (siparis_id, urun_id, miktar, birim_fiyat, indirim_orani, toplam_fiyat)
SELECT
    1 + (i % 3000) AS siparis_id,
    1 + (i % 200) AS urun_id,
    1 + (i % 5) AS miktar,
    u.birim_fiyat,
    CASE WHEN random() > 0.7 THEN ROUND((random() * 20)::NUMERIC, 2) ELSE 0 END AS indirim_orani,
    ROUND((u.birim_fiyat * (1 + (i % 5)) * (1 - CASE WHEN random() > 0.7 THEN (random() * 0.2) ELSE 0 END))::NUMERIC, 2) AS toplam_fiyat
FROM generate_series(1, 8000) AS s(i)
JOIN urunler u ON u.urun_id = 1 + (i % 200);

ALTER TABLE siparis_detaylari ENABLE TRIGGER trg_stok_dusur;
ALTER TABLE siparis_detaylari ENABLE TRIGGER trg_siparis_toplam;

UPDATE siparisler s
SET toplam_tutar = (
    SELECT COALESCE(SUM(sd.toplam_fiyat), 0) 
    FROM siparis_detaylari sd 
    WHERE sd.siparis_id = s.siparis_id
);

INSERT INTO odemeler (siparis_id, odeme_tarihi, tutar, odeme_yontemi, odeme_durumu, islem_referansi)
SELECT 
    s.siparis_id,
    s.siparis_tarihi + INTERVAL '30 minutes',
    s.toplam_tutar + s.kargo_ucreti - s.indirim_tutari,
    s.odeme_yontemi,
    CASE 
        WHEN s.durum = 'iptal' THEN 'iade'
        WHEN s.durum = 'beklemede' THEN 'beklemede'
        ELSE 'onaylandi'
    END,
    'REF-' || LPAD(s.siparis_id::TEXT, 8, '0')
FROM siparisler s
WHERE s.toplam_tutar > 0
LIMIT 2500;

INSERT INTO stok_hareketleri (urun_id, hareket_tipi, miktar, onceki_stok, sonraki_stok, referans_no, aciklama, islem_tarihi, kullanici_adi)
SELECT 
    1 + (i % 200),
    (ARRAY['giris','cikis','iade','sayim_farki','giris','giris','cikis','giris'])[1 + (i % 8)],
    1 + (i % 50),
    100 + (i % 500),
    CASE 
        WHEN (ARRAY['giris','cikis','iade','sayim_farki','giris','giris','cikis','giris'])[1 + (i % 8)] IN ('giris', 'iade')
        THEN 100 + (i % 500) + 1 + (i % 50)
        ELSE GREATEST(0, 100 + (i % 500) - 1 - (i % 50))
    END,
    'STK-' || LPAD(i::TEXT, 6, '0'),
    CASE 
        WHEN (ARRAY['giris','cikis','iade','sayim_farki','giris','giris','cikis','giris'])[1 + (i % 8)] = 'giris' THEN 'Tedarikçiden mal girişi'
        WHEN (ARRAY['giris','cikis','iade','sayim_farki','giris','giris','cikis','giris'])[1 + (i % 8)] = 'cikis' THEN 'Sipariş ile stok çıkışı'
        WHEN (ARRAY['giris','cikis','iade','sayim_farki','giris','giris','cikis','giris'])[1 + (i % 8)] = 'iade' THEN 'Müşteri iadesi'
        ELSE 'Sayım farkı düzeltme'
    END,
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (random() * 365)::INTEGER),
    (ARRAY['admin','depocu1','depocu2','yonetici','sistem'])[1 + (i % 5)]
FROM generate_series(1, 1200) AS s(i);

SELECT '=== VERİ YÜKLEME RAPORU ===' AS bilgi;

SELECT 'Kategoriler' AS tablo, COUNT(*) AS kayit_sayisi FROM kategoriler
UNION ALL
SELECT 'Tedarikçiler', COUNT(*) FROM tedarikciler
UNION ALL
SELECT 'Müşteriler', COUNT(*) FROM musteriler
UNION ALL
SELECT 'Ürünler', COUNT(*) FROM urunler
UNION ALL
SELECT 'Siparişler', COUNT(*) FROM siparisler
UNION ALL
SELECT 'Sipariş Detayları', COUNT(*) FROM siparis_detaylari
UNION ALL
SELECT 'Ödemeler', COUNT(*) FROM odemeler
UNION ALL
SELECT 'Stok Hareketleri', COUNT(*) FROM stok_hareketleri;

SELECT 'Toplam Kayıt Sayısı' AS bilgi, 
    (SELECT COUNT(*) FROM kategoriler) +
    (SELECT COUNT(*) FROM tedarikciler) +
    (SELECT COUNT(*) FROM musteriler) +
    (SELECT COUNT(*) FROM urunler) +
    (SELECT COUNT(*) FROM siparisler) +
    (SELECT COUNT(*) FROM siparis_detaylari) +
    (SELECT COUNT(*) FROM odemeler) +
    (SELECT COUNT(*) FROM stok_hareketleri) AS toplam;
