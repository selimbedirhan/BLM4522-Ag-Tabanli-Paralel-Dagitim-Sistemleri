# Proje 6: Veritabani Yukseltme ve Surum Yonetimi

**BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri**

## Proje Hakkinda

PostgreSQL kullanarak veritabani surum yukseltme planlamasi, schema migration, uyumluluk testleri, gecis stratejileri ve rollback mekanizmalarini gosteren kapsamli bir proje.

## Senaryo: Kutuphane Yonetim Sistemi

Bir kutuphane veritabaninin 3 surumlu evrimini yonetir:

| Surum | Ozellikler |
|-------|-----------|
| **v1.0** | Temel: yazarlar, kategoriler, kitaplar, uyeler, odunc islemleri |
| **v2.0** | + Yayinevleri, ceza sistemi, rezervasyon, kitap-yazar M2M, uyelik tipleri |
| **v3.0** | + Dijital kitaplar, etkinlikler, degerlendirmeler, bildirimler, trigger |

## Proje Yapisi

```
Proje6-Surum-Yonetimi/
├── scripts/
│   ├── 01_v1_temel_sema.sql              # v1.0 temel sema
│   ├── 02_v1_veri_yukle.sql              # v1.0 ornek veriler
│   ├── 03_yukseltme_oncesi_kontrol.sh    # Pre-upgrade checks
│   ├── 04_migration_yonetici.sh          # Migration manager
│   ├── 05_yukseltme_sonrasi_kontrol.sh   # Post-upgrade tests
│   └── 06_tam_demo.sh                    # Full demo script
├── migrations/
│   ├── v1_to_v2_migration.sql            # v1->v2 migration
│   └── v2_to_v3_migration.sql            # v2->v3 migration
├── rollback/
│   ├── v2_to_v1_rollback.sql             # v2->v1 rollback
│   └── v3_to_v2_rollback.sql             # v3->v2 rollback
├── rapor/rapor.md                         # Detayli rapor
├── config/
├── backups/                               # Yukseltme oncesi yedekler
└── logs/                                  # Islem loglari
```

## Hizli Baslangic

```bash
export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"
chmod +x scripts/*.sh

# Yontem 1: Tam demo (hepsini sirayla calistirir)
bash scripts/06_tam_demo.sh

# Yontem 2: Adim adim
psql -U $(whoami) -d postgres -f scripts/01_v1_temel_sema.sql    # v1.0 kur
psql -U $(whoami) -d postgres -f scripts/02_v1_veri_yukle.sql    # Veri yukle
bash scripts/03_yukseltme_oncesi_kontrol.sh                       # Kontrol
bash scripts/04_migration_yonetici.sh                             # v1->v2->v3
bash scripts/05_yukseltme_sonrasi_kontrol.sh                      # Dogrulama
```

## Onemli Kavramlar

- **Schema Migration:** Veritabani semasinin kontorlu evrilmesi
- **Version Tracking:** `schema_version` tablosu ile gecmis takibi
- **Pre/Post Checks:** Yukseltme oncesi/sonrasi otomatik kontroller
- **Rollback:** Basarisiz migration durumunda geri alma
- **Uyumluluk Testi:** Tablo, kolon, FK, indeks ve performans kontrolu
