# BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri
# Proje 6: Veritabani Yukseltme ve Surum Yonetimi
## Detayli Proje Raporu

---

### Icindekiler
1. [Giris](#1-giris)
2. [Kullanilan Teknolojiler](#2-kullanilan-teknolojiler)
3. [Veritabani Tasarimi ve Surumler](#3-veritabani-tasarimi)
4. [Schema Migration Sistemi](#4-schema-migration)
5. [Yukseltme Oncesi Kontroller](#5-yukseltme-oncesi)
6. [Migration Yonetimi](#6-migration-yonetimi)
7. [Yukseltme Sonrasi Uyumluluk Testleri](#7-uyumluluk-testleri)
8. [Rollback Stratejisi](#8-rollback)
9. [Surum Karsilastirmasi](#9-surum-karsilastirmasi)
10. [Sonuc](#10-sonuc)
11. [Kaynakca](#11-kaynakca)

---

## 1. Giris

### 1.1 Projenin Amaci
Bu proje, veritabani surum yukseltme planlamasi ve uygulamasini, uyumluluk testlerini, gecis stratejilerini ve geri alma mekanizmalarini kapsamli bir sekilde gostermektedir.

### 1.2 Senaryo
Bir **Kutuphane Yonetim Sistemi** uzerinde 3 surum (v1.0 → v2.0 → v3.0) gecisi uygulanmistir. Her surum yeni ozellikler eklerken, mevcut verilerin korunmasi ve geri uyumluluk saglanmistir.

### 1.3 Anahtar Kavramlar
- **Schema Migration:** Veritabani semasinin kontollu evrimi
- **Version Tracking:** Surum gecmisinin veritabaninda saklanmasi
- **Pre/Post Upgrade Checks:** Yukseltme oncesi ve sonrasi kontroller
- **Rollback:** Basarisiz gecis durumunda geri alma
- **Uyumluluk Testi:** Yeni surumun tum bilesenlerinin dogrulanmasi

---

## 2. Kullanilan Teknolojiler

| Teknoloji | Aciklama |
|-----------|----------|
| PostgreSQL 14 | Veritabani yonetim sistemi |
| psql | Interaktif SQL istemcisi |
| Bash Scripting | Otomasyon ve test scriptleri |
| pg_dump | Yukseltme oncesi yedekleme |
| Transaction (BEGIN/COMMIT) | Atomik migration islemleri |

---

## 3. Veritabani Tasarimi ve Surumler

### 3.1 v1.0 - Temel Sistem
Kutuphane yonetiminin en temel fonksiyonlari:

| Tablo | Aciklama | Kayit |
|-------|----------|-------|
| schema_version | Surum takip tablosu | 1 |
| yazarlar | Yazar bilgileri | 40 |
| kategoriler | Kitap kategorileri | 12 |
| kitaplar | Kitap katalogu | 200 |
| uyeler | Uye kayitlari | 400 |
| odunc_islemleri | Odunc alma islemleri | 2.000 |
| **Toplam** | | **2.652** |

Indeksler: 7 adet (ISBN, yazar, kategori, TC, odunc islemleri)

### 3.2 v2.0 - Genisletilmis Sistem
v1.0 uzerine eklenen ozellikler:

**Yeni Tablolar:**
| Tablo | Aciklama | Kayit |
|-------|----------|-------|
| yayinevleri | Yayinevi bilgileri | 8 |
| kitap_yazarlar | Coka-cok iliski (yazar-kitap) | 200 |
| cezalar | Gecikme ceza sistemi | ~200 |
| rezervasyonlar | Kitap rezervasyonu | 300 |

**Kolon Degisiklikleri:**
- kitaplar: +yayinevi_id, +dil, +aciklama, +etiketler
- uyeler: +uyelik_tipi, +dogum_tarihi, +max_odunc
- yazarlar: +biyografi
- odunc_islemleri: +notlar, +uzatma_sayisi

**Yeni Objeler:**
- 2 View: v_kitap_detay, v_uye_ceza_durumu
- 1 Fonksiyon: fn_ceza_hesapla()
- 7 Indeks

### 3.3 v3.0 - Tam Ozellikli Sistem
v2.0 uzerine eklenen gelismis ozellikler:

**Yeni Tablolar:**
| Tablo | Aciklama | Kayit |
|-------|----------|-------|
| dijital_kitaplar | E-kitap/sesli kitap | 80 |
| etkinlikler | Kutuphane etkinlikleri | 20 |
| etkinlik_katilim | Etkinlik katilim kayitlari | - |
| degerlendirmeler | Kitap puanlama/yorum | ~400 |
| bildirimler | Uye bildirimleri | 600 |

**Kolon Degisiklikleri:**
- kitaplar: +ort_puan, +degerlendirme_sayisi, +dijital_mevcut
- uyeler: +toplam_odunc, +gecikme_sayisi, +puan

**Yeni Objeler:**
- 2 View: v_kutuphane_istatistik, v_populer_kitaplar
- 1 Trigger: trg_puan_guncelle (degerlendirme sonrasi otomatik)
- 6 Indeks (kismil indeks dahil)

---

## 4. Schema Migration Sistemi

### 4.1 schema_version Tablosu
Her migration isleminin kaydi tutulur:

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| version_id | SERIAL | Benzersiz kimlik |
| version_no | VARCHAR | Surum numarasi (1.0.0, 2.0.0, 3.0.0) |
| aciklama | TEXT | Degisiklik ozeti |
| migration_dosya | VARCHAR | Migration SQL dosyasi |
| uygulama_tarihi | TIMESTAMP | Uygulama zamani |
| sure_ms | INTEGER | Islem suresi (ms) |
| durum | VARCHAR | basarili / basarisiz / geri_alindi |
| geri_alma_dosya | VARCHAR | Rollback dosya adi |

### 4.2 Migration Dosya Yapisi
Her migration dosyasi su adimlari izler:
1. **Surum kontrolu:** Mevcut surumun beklenen olup olmadigini dogrular
2. **Transaction baslat:** BEGIN ile atomik islem
3. **Degisiklikleri uygula:** CREATE TABLE, ALTER TABLE, CREATE INDEX
4. **Veri migrasyonu:** Mevcut verilerin yeni yapiya uyarlanmasi
5. **Surum kaydini guncelle:** schema_version'a yeni kayit
6. **Transaction bitir:** COMMIT

---

## 5. Yukseltme Oncesi Kontroller

7 farkli kontrol yapilir:

| # | Kontrol | Aciklama |
|---|---------|----------|
| 1 | Baglanti | PostgreSQL ve DB erisimi |
| 2 | Surum bilgisi | Mevcut surum ve gecmis |
| 3 | DB durumu | Tablo, indeks, view, fonksiyon sayilari |
| 4 | Veri butunlugu | FK ihlali, null, duplicate kontrol |
| 5 | Aktif islemler | Uzun calisan sorgu kontrolu |
| 6 | Disk alani | Yeterli alan kontrolu |
| 7 | Yedek | Yukseltme oncesi otomatik yedek |

---

## 6. Migration Yonetimi

### 6.1 Otomatik Surum Tespiti
Migration yonetici scripti mevcut surumu otomatik tespit ederek siradaki migration'i uygular:
- v1.0 ise → v1→v2 calistirir, sonra v2→v3
- v2.0 ise → sadece v2→v3 calistirir
- v3.0 ise → zaten guncel

### 6.2 Atomik Migration
Her migration `BEGIN...COMMIT` transaction blogu icinde calisir. Herhangi bir hata durumunda tum degisiklikler otomatik geri alinir (PostgreSQL DDL transaction destegi).

---

## 7. Yukseltme Sonrasi Uyumluluk Testleri

5 test grubu ile kapsamli dogrulama:

### Test Sonuclari (v3.0):
| Test | Adet | Sonuc |
|------|------|-------|
| Tablo varlik (v1+v2+v3) | 15 | 15/15 GECTI |
| Kolon kontrolu | 7 | 7/7 GECTI |
| Veri butunlugu | 3 | 3/3 GECTI |
| View/Fonksiyon | 3 | 3/3 GECTI |
| Performans | 1 | 1/1 GECTI |
| **TOPLAM** | **28** | **28/28 BASARILI** |

---

## 8. Rollback Stratejisi

### 8.1 Rollback Dosyalari
Her migration icin karsilik gelen rollback dosyasi bulunur:

| Migration | Rollback |
|-----------|----------|
| v1_to_v2_migration.sql | v2_to_v1_rollback.sql |
| v2_to_v3_migration.sql | v3_to_v2_rollback.sql |

### 8.2 Rollback Sureci
1. Yeni eklenen tablolar `DROP TABLE CASCADE` ile silinir
2. Eklenen kolonlar `ALTER TABLE DROP COLUMN` ile kaldirilir
3. Yeni view ve fonksiyonlar silinir
4. schema_version tablosunda durum 'geri_alindi' olarak guncellenir
5. Rollback kaydi eklenir

### 8.3 Demo Senaryosu
Tam demo scriptinde gosterilen senaryo:
```
v1.0 kur → v2.0 yuksel → v3.0 yuksel → v3.0 geri al (v2.0'a don)
→ v3.0 tekrar yuksel
```

Bu, rollback mekanizmasinin calistigini ve tekrar yukseltme yapilabildini kanitlar.

---

## 9. Surum Karsilastirmasi

| Ozellik | v1.0 | v2.0 | v3.0 |
|---------|------|------|------|
| Tablo | 6 | 10 | 15 |
| Kolon | ~35 | ~55 | ~70 |
| Indeks | 7 | 14 | 20 |
| View | 0 | 2 | 4 |
| Fonksiyon | 0 | 1 | 2 |
| Trigger | 0 | 0 | 1 |
| FK | 5 | 12 | 17 |
| Toplam Kayit | ~2.650 | ~3.350 | ~4.460 |
| DB Boyutu | ~9MB | ~10MB | ~11MB |

---

## 10. Sonuc

### 10.1 Kazanimlar
- Schema migration kavraminin PostgreSQL ile uygulanmasi
- Transaction-tabanli atomik gecis mekanizmasi
- Otomatik surum tespiti ve zincirli migration
- Kapsamli pre/post upgrade kontrolleri (28 test)
- Calisan rollback mekanizmasi
- Veri butunlugu korunarak surum yukseltme

### 10.2 Best Practices
1. Her migration icin rollback dosyasi hazirlanmali
2. Yukseltme oncesi mutlaka yedek alinmali
3. Migration islemleri transaction icinde yapilmali
4. Surum gecmisi veritabaninda saklanmali
5. Yukseltme sonrasi uyumluluk testleri yapilmali
6. Mevcut veriler yeni yapiya uyarlanmali

---

## 11. Kaynakca

1. PostgreSQL Documentation - ALTER TABLE
   https://www.postgresql.org/docs/14/sql-altertable.html

2. PostgreSQL Documentation - Transactional DDL
   https://wiki.postgresql.org/wiki/Transactional_DDL_in_PostgreSQL

3. PostgreSQL Documentation - CREATE TABLE
   https://www.postgresql.org/docs/14/sql-createtable.html

4. Database Migration Best Practices
   https://www.postgresql.org/docs/14/upgrading.html

---

*Rapor Tarihi: 2026*
*BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri*
