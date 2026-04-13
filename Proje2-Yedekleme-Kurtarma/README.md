# 🗄️ Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı

**BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri**

## 📋 Proje Hakkında

Bu proje, PostgreSQL veritabanı yönetim sistemi kullanılarak kapsamlı bir **yedekleme (backup)** ve **felaketten kurtarma (disaster recovery)** planının tasarlanması ve uygulanmasını içerir.

Proje kapsamında aşağıdaki konular işlenmiştir:
- ✅ Tam (Full), Fark (Differential) ve Artık (Incremental) yedekleme stratejileri
- ✅ Zamanlayıcılarla (Cron) otomatik yedekleme
- ✅ Felaketten kurtarma senaryoları (tablo silme, veri bozulma, yanlış güncelleme)
- ✅ Point-in-Time Recovery (PITR) ile belirli bir zamana geri dönme
- ✅ Yedeklerin doğruluğunu test etme ve raporlama

## 🛠️ Kullanılan Teknolojiler

| Teknoloji | Sürüm | Açıklama |
|-----------|-------|----------|
| PostgreSQL | 14.x | Veritabanı yönetim sistemi |
| pg_dump / pg_restore | - | Mantıksal yedekleme araçları |
| pg_basebackup | - | Fiziksel yedekleme aracı |
| Bash | 5.x | Shell scripting |
| Cron | - | Zamanlayıcı servisi |
| macOS | - | İşletim sistemi |

## 📁 Proje Yapısı

```
Proje2-Yedekleme-Kurtarma/
├── README.md                              # Bu dosya
├── .gitignore                             # Git hariç tutma kuralları
├── rapor/
│   └── rapor.md                           # Detaylı proje raporu
├── scripts/
│   ├── 01_veritabani_olustur.sql          # E-Ticaret DB şeması
│   ├── 02_ornek_veri_yukle.sql            # 10.000+ örnek veri
│   ├── 03_tam_yedekleme.sh               # Tam (Full) yedekleme
│   ├── 04_fark_yedekleme.sh              # Fark (Differential) yedekleme
│   ├── 05_artik_yedekleme.sh             # Artık (WAL) yedekleme
│   ├── 06_zamanlanmis_yedekleme.sh       # Cron zamanlayıcı kurulum
│   ├── 07_felaket_kurtarma.sh            # Felaketten kurtarma senaryoları
│   ├── 08_point_in_time_recovery.sh      # PITR kurtarma
│   ├── 09_yedek_test.sh                  # Yedek doğrulama testleri
│   └── 10_yedekleme_rapor.sh             # Yedekleme raporlama
├── config/
│   ├── postgresql.conf.backup             # PostgreSQL yedekleme ayarları
│   ├── pg_hba.conf.backup                # Erişim ayarları
│   ├── crontab_yedekleme.txt             # Cron zamanlayıcı tanımları
│   └── pitr_recovery_example.conf        # PITR yapılandırma örneği
├── backups/                               # Yedek dosyaları (git'te yok)
└── logs/                                  # Log dosyaları (git'te yok)
```

## 🚀 Kurulum ve Çalıştırma

### Ön Gereksinimler
- macOS veya Linux
- PostgreSQL 14+ kurulu ve çalışır durumda
- Homebrew (macOS için)

### 1. PostgreSQL'i Başlat
```bash
# macOS (Homebrew)
brew services start postgresql@14

# Bağlantı kontrolü
pg_isready
```

### 2. Veritabanını Oluştur
```bash
export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"

# Şema oluştur
psql -U $(whoami) -d postgres -f scripts/01_veritabani_olustur.sql

# Örnek verileri yükle
psql -U $(whoami) -d postgres -f scripts/02_ornek_veri_yukle.sql
```

### 3. Scriptlere Çalıştırma İzni Ver
```bash
chmod +x scripts/*.sh
```

### 4. Scriptleri Sırayla Çalıştır
```bash
# Tam yedekleme
./scripts/03_tam_yedekleme.sh

# Fark yedekleme
./scripts/04_fark_yedekleme.sh

# Artık yedekleme (WAL)
./scripts/05_artik_yedekleme.sh

# Zamanlanmış yedekleme kurulumu
./scripts/06_zamanlanmis_yedekleme.sh

# Felaketten kurtarma senaryoları
./scripts/07_felaket_kurtarma.sh

# Point-in-Time Recovery
./scripts/08_point_in_time_recovery.sh

# Yedek doğrulama testleri
./scripts/09_yedek_test.sh

# Yedekleme raporu
./scripts/10_yedekleme_rapor.sh
```

## 📊 Yedekleme Stratejisi

### Yedekleme Türleri

| Yedekleme Türü | Araç | Sıklık | Açıklama |
|---------------|------|--------|----------|
| Tam (Full) | pg_dump -Fc | Günlük | Tüm veritabanının yedeği |
| Fark (Differential) | pg_dump (tablo bazlı) | Saatlik | Değişen tabloların yedeği |
| Artık (Incremental) | WAL arşivleme | Sürekli | WAL dosyalarının arşivlenmesi |

### Saklama Politikası (Retention)
- Günlük yedekler: 7 gün
- Haftalık yedekler: 4 hafta
- Aylık yedekler: 12 ay

## 🔧 Felaketten Kurtarma Senaryoları

1. **Yanlışlıkla Tablo Silme** → pg_restore ile seçici geri yükleme
2. **Veritabanı Bozulması** → Tam yedekten restore
3. **Yanlış Veri Güncelleme** → Yedekten veri karşılaştırma ve düzeltme
4. **Yanlışlıkla Veri Silme** → Tam restore
5. **PITR** → Belirli bir zamana geri dönme

## 📝 Yazar

- **Ders:** BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
- **Platform:** PostgreSQL 14 (macOS)
- **Tarih:** 2026
