# Proje 4: Veritabani Replikasyonu ve Yuk Dengeleme

**BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri**

## Proje Hakkinda
PostgreSQL Logical Replication ile veritabani replikasyonu, Read/Write splitting ile yuk dengeleme ve failover stratejileri.

## Senaryo: Sosyal Medya Platformu
80.000+ satirlik buyuk veri seti ile replikasyon testi.

## Mimari
```
┌─────────────────┐         ┌───────────────────┐
│   PRIMARY        │  ──→    │   REPLICA          │
│ sosyal_medya_db  │ Logical │ sosyal_medya_replica│
│ (Read + Write)   │  Rep.   │ (Read Only)        │
└─────────────────┘         └───────────────────┘
     ↑ WRITE                      ↑ READ
     │                             │
     └────── Uygulama Katmani ─────┘
```

## Proje Yapisi
```
Proje4-Replikasyon-Yuk-Dengeleme/
├── scripts/
│   ├── 01_veritabani_olustur.sql         # Primary DB semasi (10 tablo)
│   ├── 02_ornek_veri_yukle.sql           # 80.000+ ornek veri
│   ├── 03_replikasyon_altyapi.sh         # WAL level ayari
│   ├── 04_replikasyon_kurulum.sql        # Publication/Subscription
│   ├── 05_replikasyon_izleme.sh          # Durum izleme raporu
│   ├── 06_yuk_dengeleme.sh              # Read/Write splitting demo
│   ├── 07_failover_test.sh              # Failover simulasyonu
│   └── 08_tam_demo.sh                    # Tam demo
├── rapor/rapor.md
└── logs/
```

## Hizli Baslangic
```bash
export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"
chmod +x scripts/*.sh
bash scripts/08_tam_demo.sh
```

## Kapsanan Konular
| Konu | Aciklama |
|------|----------|
| Logical Replication | Publication/Subscription modeli |
| WAL Konfigurasyonu | wal_level, replication slots |
| Veri Esitleme | Primary-Replica kayit karsilastirmasi |
| Read/Write Splitting | Yazma Primary'ye, okuma Replica'ya |
| Replikasyon Lag | WAL gecikme izleme ve analiz |
| Failover | Subscription durdurma/baslatma, recovery |
| Replication Slots | Slot durumu ve yonetimi |
