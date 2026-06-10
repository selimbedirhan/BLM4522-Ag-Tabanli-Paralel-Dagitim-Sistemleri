# Proje 7: Veritabani Yedekleme ve Otomasyon Calismasi

**BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri**

## Proje Hakkinda

Bu proje, PostgreSQL veritabani yonetim sistemi kullanilarak yedekleme islemlerinin **otomatiklestirilmesi**, **denetim ve raporlama** mekanizmalarinin kurulmasi ve basarisizlik durumunda **uyari sistemi** olusturulmasini kapsar.

### Proje Gereksinimleri ve PostgreSQL Karsiliklari

| Gereksinim (MSSQL) | PostgreSQL Karsiligi |
|-----|-----|
| SQL Server Agent | Cron + Bash Scripting |
| PowerShell/T-SQL Scripting | Bash + psql Scripting |
| Otomatik Yedekleme Uyarilari | macOS Notification + Log Sistemi |

## Kullanilan Teknolojiler

| Teknoloji | Aciklama |
|-----------|----------|
| PostgreSQL 14 | Veritabani yonetim sistemi |
| pg_dump / pg_restore | Yedekleme ve geri yukleme |
| Bash 5.x | Shell scripting & otomasyon |
| Cron | Zamanlayici (SQL Server Agent yerine) |
| psql | SQL istemcisi & raporlama |
| macOS Notifications | Uyari bildirimleri |

## Proje Yapisi

```
Proje7-Yedekleme-Otomasyon/
├── README.md
├── .gitignore
├── rapor/
│   └── rapor.md                           # Detayli proje raporu
├── scripts/
│   ├── 01_veritabani_olustur.sql          # Hastane DB semasi
│   ├── 02_ornek_veri_yukle.sql            # 10.000+ ornek veri
│   ├── 03_otomasyon_altyapi.sh            # Otomasyon altyapi kurulumu
│   ├── 04_otomatik_yedekleme.sh           # Ana yedekleme scripti (cron)
│   ├── 05_yedekleme_denetim.sql           # Denetim tablolari & sorgulari
│   ├── 06_yedekleme_raporlama.sh          # Raporlama (Bash+psql)
│   ├── 07_basarisizlik_uyari.sh           # Uyari sistemi
│   ├── 08_yedek_rotasyon.sh              # Yedek rotasyonu
│   ├── 09_yedek_dogrulama.sh             # Otomatik dogrulama
│   └── 10_tam_otomasyon_demo.sh          # Tam demo
├── config/
│   ├── yedekleme_ayar.conf               # Merkezi ayar dosyasi
│   └── crontab_jobs.txt                  # Cron tanimlari
├── backups/                               # Yedek dosyalari
├── logs/                                  # Log dosyalari
└── reports/                               # Raporlar
```

## Kurulum ve Calistirma

### 1. PostgreSQL Baslat
```bash
brew services start postgresql@14
pg_isready
```

### 2. Veritabanini Olustur
```bash
export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"
psql -U $(whoami) -d postgres -f scripts/01_veritabani_olustur.sql
psql -U $(whoami) -d postgres -f scripts/02_ornek_veri_yukle.sql
psql -U $(whoami) -d hastane_db -f scripts/05_yedekleme_denetim.sql
```

### 3. Scriptleri Calistir
```bash
chmod +x scripts/*.sh

# Tek tek calistirma
bash scripts/03_otomasyon_altyapi.sh    # Altyapi kontrolu
bash scripts/04_otomatik_yedekleme.sh   # Yedekleme
bash scripts/06_yedekleme_raporlama.sh  # Raporlama
bash scripts/07_basarisizlik_uyari.sh   # Uyari kontrolu
bash scripts/08_yedek_rotasyon.sh       # Rotasyon
bash scripts/09_yedek_dogrulama.sh      # Dogrulama

# veya tamamini bir seferde
bash scripts/10_tam_otomasyon_demo.sh   # Tam demo
```

### 4. Cron Zamanlayici Kur
```bash
crontab config/crontab_jobs.txt
crontab -l   # Dogrulama
```

## Otomasyon Modulleri

| Modul | Aciklama |
|-------|----------|
| Altyapi | Ayar yukleyici, DB baglanti kontrolu, ortak fonksiyonlar |
| Otomatik Yedek | Gun/hafta/ay bazli yedekleme, cron entegrasyonu |
| Denetim | Yedekleme kayitlarinin DB'de saklanmasi, istatistik fonksiyonlari |
| Raporlama | Terminal + HTML raporlar, Bash+psql scripting |
| Uyari | Basarisizlik, gecikme, boyut anomalisi ve disk kontrolu |
| Rotasyon | Saklama politikasi, eski yedek temizligi |
| Dogrulama | Butunluk, restore, veri karsilastirma testleri |
| Zamanlayici | Cron tanimlari, macOS launchd destegi |

## Yazar

- **Ders:** BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri
- **Platform:** PostgreSQL 14 (macOS)
- **Tarih:** 2026
