# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
## Detaylı Proje Raporu

---

### İçindekiler
1. [Giriş](#1-giriş)
2. [Kullanılan Teknolojiler ve Araçlar](#2-kullanılan-teknolojiler-ve-araçlar)
3. [Veritabanı Tasarımı](#3-veritabanı-tasarımı)
4. [Yedekleme Stratejileri](#4-yedekleme-stratejileri)
5. [Zamanlayıcılarla Otomatik Yedekleme](#5-zamanlayıcılarla-otomatik-yedekleme)
6. [Felaketten Kurtarma Senaryoları](#6-felaketten-kurtarma-senaryoları)
7. [Point-in-Time Recovery (PITR)](#7-point-in-time-recovery-pitr)
8. [Yedek Doğrulama ve Test](#8-yedek-doğrulama-ve-test)
9. [Sonuç ve Değerlendirme](#9-sonuç-ve-değerlendirme)
10. [Kaynakça](#10-kaynakça)

---

## 1. Giriş

### 1.1 Projenin Amacı
Bu projenin amacı, bir veritabanı yönetim sistemi üzerinde kapsamlı bir yedekleme ve felaketten kurtarma planı tasarlamak ve uygulamaktır. Veritabanı yedekleme, modern bilgi sistemlerinin en kritik bileşenlerinden biridir. Donanım arızaları, yazılım hataları, insan kaynaklı hatalar veya siber saldırılar gibi beklenmedik durumlarla karşılaşıldığında, verilerin kurtarılabilmesi büyük önem taşır.

### 1.2 Kapsam
Proje kapsamında aşağıdaki konular ele alınmıştır:
- **Tam (Full) Yedekleme:** Veritabanının tamamının farklı formatlarda yedeklenmesi
- **Fark (Differential) Yedekleme:** Şema ve tablo bazlı kısmi yedekleme
- **Artık (Incremental) Yedekleme:** WAL (Write-Ahead Logging) tabanlı sürekli yedekleme
- **Zamanlanmış Yedekleme:** Cron zamanlayıcı ile otomatik yedekleme
- **Felaketten Kurtarma:** Çeşitli felaket senaryolarında veri kurtarma
- **PITR:** Belirli bir zamana geri dönme (Point-in-Time Recovery)
- **Test ve Doğrulama:** Yedeklerin bütünlük ve doğruluk testleri

### 1.3 Veritabanı Seçimi
Projede **PostgreSQL 14** tercih edilmiştir. PostgreSQL'in seçilme nedenleri:
- Açık kaynak ve ücretsiz olması
- WAL tabanlı güçlü yedekleme altyapısı
- Point-in-Time Recovery desteği
- `pg_dump`, `pg_restore`, `pg_basebackup` gibi zengin yedekleme araçları
- Sanayi standardı güvenilirlik ve ACID uyumluluk

---

## 2. Kullanılan Teknolojiler ve Araçlar

### 2.1 PostgreSQL 14
PostgreSQL, dünya genelinde en çok kullanılan açık kaynak ilişkisel veritabanı yönetim sistemlerinden biridir. ACID (Atomicity, Consistency, Isolation, Durability) özelliklerini tam olarak destekler.

### 2.2 Yedekleme Araçları

| Araç | Türü | Açıklama |
|------|------|----------|
| `pg_dump` | Mantıksal | Veritabanını SQL komutları olarak dışa aktarır |
| `pg_restore` | Mantıksal | pg_dump çıktısından veritabanını geri yükler |
| `pg_basebackup` | Fiziksel | Veri dizininin fiziksel kopyasını alır |
| `psql` | İstemci | SQL komutlarını çalıştırır |
| WAL Arşivleme | Fiziksel | Transaction log dosyalarını arşivler |

### 2.3 Diğer Araçlar
- **Bash:** Shell scripting ile otomasyon
- **Cron:** Zamanlanmış görev yönetimi
- **gzip/bzip2:** Yedek dosyalarının sıkıştırılması

---

## 3. Veritabanı Tasarımı

### 3.1 E-Ticaret Veritabanı Şeması
Projede örnek olarak bir e-ticaret veritabanı tasarlanmıştır. Bu veritabanı gerçekçi bir senaryo sunarak yedekleme ve kurtarma işlemlerinin anlamlı veriler üzerinde test edilmesini sağlar.

### 3.2 Tablolar

| Tablo | Açıklama | Yaklaşık Kayıt Sayısı |
|-------|----------|----------------------|
| `kategoriler` | Ürün kategorileri | 20 |
| `tedarikciler` | Tedarikçi firmaları | 15 |
| `musteriler` | Müşteri bilgileri | 500 |
| `urunler` | Ürün kataloğu | 200 |
| `siparisler` | Sipariş kayıtları | 3.000 |
| `siparis_detaylari` | Sipariş kalemleri | 8.000 |
| `odemeler` | Ödeme işlemleri | 2.500 |
| `stok_hareketleri` | Stok giriş/çıkışları | 1.200+ |
| **TOPLAM** | | **15.000+** |

### 3.3 İlişkiler ve Kısıtlamalar
- Foreign Key ilişkileri ile tablo bütünlüğü sağlanmıştır
- CHECK kısıtlamalarıyla veri doğrulama yapılmıştır
- UNIQUE kısıtlama ile tekrar eden veriler önlenmiştir
- DEFAULT değerlerle veri girişi kolaylaştırılmıştır

### 3.4 İndeksler
Performansı artırmak için stratejik noktalarda indeksler oluşturulmuştur:
- E-posta aramaları için `idx_musteriler_email`
- Sipariş durumu filtreleme için `idx_siparisler_durum`
- Tarih bazlı sorgular için `idx_siparisler_tarih`
- Ve diğer 12+ indeks

### 3.5 Görünümler (Views)
- `v_siparis_ozeti`: Sipariş detaylarını bir arada gösteren özet görünüm
- `v_stok_durumu`: Ürün stok seviyelerini ve durumlarını gösteren görünüm
- `v_gunluk_satis`: Günlük satış raporlama görünümü

### 3.6 Tetikleyiciler (Triggers) ve Fonksiyonlar
- `fn_stok_guncelle()`: Sipariş eklendiğinde stoku otomatik düşüren fonksiyon
- `fn_siparis_toplam_guncelle()`: Sipariş detayı eklendiğinde toplamı güncelleyen fonksiyon

---

## 4. Yedekleme Stratejileri

### 4.1 Tam (Full) Yedekleme
Tam yedekleme, veritabanının tüm yapısını ve verilerini kapsayan yedekleme türüdür. Bu yöntemde dört farklı format kullanılmıştır:

#### 4.1.1 Custom Format (-Fc)
```bash
pg_dump -U kullanici -d eticaret_db -Fc -Z 6 --file=yedek.dump
```
- **Avantajları:** Dahili sıkıştırma, seçici geri yükleme (belirli tablo/şema), paralel restore
- **Dezavantajları:** Okunabilir değil, sadece pg_restore ile geri yüklenir
- **Kullanım:** Günlük yedeklemeler için önerilen format

#### 4.1.2 Plain SQL Format (-Fp)
```bash
pg_dump -U kullanici -d eticaret_db -Fp --create --clean --file=yedek.sql
```
- **Avantajları:** İnsan tarafından okunabilir, herhangi bir PostgreSQL sürümüne uygulanabilir
- **Dezavantajları:** Büyük dosya boyutu, sıkıştırma yok
- **Kullanım:** Sürümler arası geçiş, denetim

#### 4.1.3 Sıkıştırılmış SQL (gzip)
```bash
pg_dump -U kullanici -d eticaret_db -Fp | gzip -9 > yedek.sql.gz
```
- **Avantajları:** Plain SQL'in okunabilirliği + sıkıştırma ile alan tasarrufu
- **Dezavantajları:** Ek işlem süresi
- **Kullanım:** Uzun süreli arşivleme

#### 4.1.4 Tar Format (-Ft)
```bash
pg_dump -U kullanici -d eticaret_db -Ft --file=yedek.tar
```
- **Avantajları:** Dosya sistemi yapısında arşiv
- **Dezavantajları:** Custom format kadar verimli değil
- **Kullanım:** Taşınabilirlik gereken durumlar

### 4.2 Fark (Differential) Yedekleme
PostgreSQL'de SQL Server'daki gibi native differential backup yoktur. Ancak çeşitli tekniklerle simüle edilebilir:

#### 4.2.1 Şema/DDL Yedekleme
```bash
pg_dump -U kullanici -d eticaret_db --schema-only --file=sema_yedek.sql
```
Sadece tablo yapıları, indeksler, trigger'lar ve fonksiyonları yedekler.

#### 4.2.2 Sadece Veri Yedekleme
```bash
pg_dump -U kullanici -d eticaret_db --data-only --column-inserts --file=veri_yedek.sql
```
Sadece tablo verilerini INSERT komutları olarak yedekler.

#### 4.2.3 Tablo Bazlı Kısmi Yedekleme
```bash
pg_dump -U kullanici -d eticaret_db --table=siparisler --file=siparisler_yedek.sql
```
Sadece belirtilen tablonun yedeğini alır. Sık değişen tablolar için idealdir.

#### 4.2.4 Tarih Bazlı Koşullu Yedekleme
```sql
\COPY (SELECT * FROM siparisler WHERE siparis_tarihi >= CURRENT_TIMESTAMP - INTERVAL '7 days') TO 'son_7_gun.csv' WITH CSV HEADER
```
Son N günde eklenen/değişen verilerin CSV olarak dışa aktarımı.

### 4.3 Artık (Incremental) Yedekleme - WAL Arşivleme
PostgreSQL'in Write-Ahead Logging (WAL) altyapısı, gerçek anlamda artık yedeklemeyi mümkün kılar.

#### 4.3.1 WAL Nedir?
WAL, PostgreSQL'in tüm veritabanı değişikliklerini öncelikle log dosyalarına yazdığı bir mekanizmadır. Bu sayede:
- Veritabanı çökmelerinde veri kaybı önlenir
- Sürekli yedekleme (continuous archiving) mümkün olur
- Point-in-Time Recovery yapılabilir

#### 4.3.2 WAL Yapılandırması
```
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /path/to/wal_archive/%f'
```

#### 4.3.3 pg_basebackup ile Baz Yedekleme
```bash
pg_basebackup -U kullanici -D /path/to/backup -Ft -z -P --checkpoint=fast
```
PITR için temel teşkil eden fiziksel yedekleme. WAL arşivleriyle birlikte kullanıldığında herhangi bir zamana geri dönüş sağlar.

---

## 5. Zamanlayıcılarla Otomatik Yedekleme

### 5.1 Cron Zamanlayıcı
Unix/Linux sistemlerinde zamanlanmış görevler için cron servisi kullanılır.

### 5.2 Zamanlayıcı Planı

| Zamanlama | İşlem | Komut |
|-----------|-------|-------|
| Her gün 02:00 | Tam yedekleme | `auto_backup.sh` |
| Her Pazar 03:00 | Haftalık yedekleme | `03_tam_yedekleme.sh` |
| Hafta içi 09-18 arası (saatlik) | Fark yedekleme | `04_fark_yedekleme.sh` |

### 5.3 Cron Tanımları
```
# Cron format: dakika saat gün ay hafta_günü komut
0 2 * * * /path/to/auto_backup.sh          # Günlük 02:00
0 3 * * 0 /path/to/03_tam_yedekleme.sh     # Her Pazar 03:00
0 9-18 * * 1-5 /path/to/04_fark_yedekleme.sh  # Hafta içi saatlik
```

### 5.4 Saklama Politikası (Retention Policy)
- **Günlük yedekler:** 7 gün saklanır, sonra otomatik silinir
- **Eski loglar:** 30 gün sonra temizlenir
- `find` komutu ile otomatik temizleme:
```bash
find /backup/dir -name "*.dump" -mtime +7 -type f -delete
```

### 5.5 Hata Bildirimi
Yedekleme başarısız olduğunda log dosyasına hata kaydedilir. Script çıkış kodu kontrol edilerek başarı/başarısızlık durumu raporlanır.

---

## 6. Felaketten Kurtarma Senaryoları

### 6.1 Senaryo 1: Yanlışlıkla Tablo Silme
**Problem:** Bir kullanıcı yanlışlıkla `DROP TABLE stok_hareketleri CASCADE` komutu çalıştırdı.

**Çözüm:** pg_restore ile sadece ilgili tabloyu yedekten geri yükleme:
```bash
pg_restore -U kullanici -d eticaret_db --table=stok_hareketleri --single-transaction yedek.dump
```

**Önemli Noktalar:**
- `--table` parametresi ile sadece belirli tablo geri yüklenir
- `--single-transaction` ile atomik geri yükleme sağlanır
- CASCADE ile silinen bağımlı objeler de geri yüklenir

### 6.2 Senaryo 2: Veritabanı Tam Bozulması
**Problem:** Veritabanı dosyaları bozuldu veya sistemik bir hata oluştu.

**Çözüm:** Yeni bir veritabanı oluşturup tam restore:
```bash
createdb yeni_db
pg_restore -U kullanici -d yeni_db --clean --if-exists --single-transaction yedek.dump
```

**Doğrulama:** Orijinal ve restore edilen veritabanının kayıt sayıları karşılaştırılır.

### 6.3 Senaryo 3: Yanlış Veri Güncelleme
**Problem:** `UPDATE urunler SET birim_fiyat = 0` komutu yanlışlıkla çalıştırıldı ve tüm fiyatlar sıfırlandı.

**Çözüm:** 
1. Yedekten geçici veritabanına restore
2. Geçici veritabanından doğru verileri çekme
3. Ana veritabanındaki hatalı verileri güncelleme

### 6.4 Senaryo 4: Kitlesel Veri Silme
**Problem:** `DELETE FROM musteriler WHERE sehir = 'İstanbul'` komutu çalıştırıldı ve İstanbul'daki tüm müşteriler silindi.

**Çözüm:** Tam veritabanı restore ile tüm verileri geri yükleme:
```bash
pg_restore -U kullanici -d eticaret_db --clean --if-exists --single-transaction yedek.dump
```

---

## 7. Point-in-Time Recovery (PITR)

### 7.1 PITR Nedir?
Point-in-Time Recovery, veritabanını geçmişteki belirli bir zaman noktasına geri döndürme işlemidir. Bu, WAL arşivleme ile mümkün olur.

### 7.2 PITR Gereksinimleri
1. `wal_level = 'replica'` veya üzeri
2. `archive_mode = 'on'`
3. `archive_command` yapılandırılmış olmalı
4. Geçerli bir base backup mevcut olmalı

### 7.3 PITR Süreci
1. **Base Backup Alma:** pg_basebackup ile fiziksel yedek
2. **WAL Arşivleme:** Sürekli WAL dosyalarının arşivlenmesi
3. **Felaket Sonrası:** Base backup'tan restore + WAL replay
4. **Hedef Zaman Belirleme:** recovery_target_time ile

### 7.4 Recovery Yapılandırması (PostgreSQL 12+)
```
# postgresql.conf
recovery_target_time = '2026-04-13 12:00:00'
recovery_target_action = 'promote'
restore_command = 'cp /path/to/wal_archive/%f %p'
recovery_target_timeline = 'latest'
```

### 7.5 PITR Simülasyonu
Projede PITR sürecinin tüm adımları simüle edilmiştir:
1. Restore point oluşturuldu
2. Baz yedek alındı
3. Felaket verileri eklendi (müşteri silme, fiyat değiştirme, sahte sipariş ekleme)
4. Baz yedekten restore yapıldı
5. Kurtarma doğrulandı

---

## 8. Yedek Doğrulama ve Test

### 8.1 Test Grupları
Yedeklerin güvenilirliğini doğrulamak için 5 grup test uygulanmıştır:

#### Test Grubu 1: Yedek Oluşturma
- Custom format yedek oluşturulabilmeli
- Plain SQL yedek oluşturulabilmeli

#### Test Grubu 2: Bütünlük Kontrolleri
- pg_restore --list ile yedek içeriği doğrulanmalı
- Dosya boyutu kontrolü (sıfır olmadığından emin olma)
- SQL syntax kontrolü

#### Test Grubu 3: Geri Yükleme Testleri
- Test veritabanına restore edilmeli
- Kayıt sayıları orijinal ile eşleşmeli

#### Test Grubu 4: Veri Bütünlüğü
- Foreign key ilişkileri korunmuş olmalı
- İndeksler mevcut olmalı
- View'lar çalışır durumda olmalı
- Trigger ve fonksiyonlar sağlam olmalı
- Veri doğruluğu (toplam/ortalama kontrolleri)

#### Test Grubu 5: Performans
- Yedekleme süresi ölçümü
- Veritabanı ve yedek boyutu karşılaştırması

### 8.2 Test Sonuçları
Tüm testler başarıyla tamamlanması beklenir. Her test GEÇTI/KALDI olarak raporlanır ve detaylı sonuçlar log dosyasına yazılır.

---

## 9. Sonuç ve Değerlendirme

### 9.1 Elde Edilen Kazanımlar
Bu proje kapsamında:
- PostgreSQL yedekleme araçlarının (pg_dump, pg_restore, pg_basebackup) etkin kullanımı öğrenildi
- Farklı yedekleme formatlarının avantaj ve dezavantajları karşılaştırıldı
- WAL tabanlı sürekli yedekleme altyapısı anlaşıldı
- Cron ile zamanlayıcı görev yönetimi uygulandı
- Gerçekçi felaket senaryolarında veri kurtarma becerileri geliştirildi
- PITR kavramı ve uygulaması öğrenildi
- Shell scripting ile veritabanı otomasyon becerileri kazanıldı

### 9.2 En İyi Uygulamalar (Best Practices)
1. **3-2-1 Kuralı:** 3 kopya, 2 farklı ortam, 1 offsite yedek
2. **Düzenli Test:** Yedeklerin düzenli olarak restore testi yapılmalı
3. **Otomasyon:** Manuel yedekleme yerine otomatik yedekleme kullanılmalı
4. **İzleme:** Yedekleme işlemlerinin başarısı sürekli izlenmeli
5. **Saklama Politikası:** Eski yedeklerin otomatik temizlenmesi planlanmalı
6. **Dökümantasyon:** Kurtarma adımları belgelenmeli (RTO ve RPO)

### 9.3 RTO ve RPO Analizi
- **RPO (Recovery Point Objective):** WAL arşivleme ile neredeyse sıfır veri kaybı
- **RTO (Recovery Time Objective):** Yedek boyutuna bağlı olarak dakikalar-saatler arası

---

## 10. Kaynakça

1. PostgreSQL Official Documentation - Backup and Restore  
   https://www.postgresql.org/docs/14/backup.html

2. PostgreSQL Official Documentation - Continuous Archiving and Point-in-Time Recovery  
   https://www.postgresql.org/docs/14/continuous-archiving.html

3. PostgreSQL Official Documentation - pg_dump  
   https://www.postgresql.org/docs/14/app-pgdump.html

4. PostgreSQL Official Documentation - pg_restore  
   https://www.postgresql.org/docs/14/app-pgrestore.html

5. PostgreSQL Official Documentation - pg_basebackup  
   https://www.postgresql.org/docs/14/app-pgbasebackup.html

6. PostgreSQL Official Documentation - Write-Ahead Logging  
   https://www.postgresql.org/docs/14/wal.html

---

*Rapor Tarihi: 2026*  
*BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri*
