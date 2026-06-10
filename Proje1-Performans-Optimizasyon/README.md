# Proje 1: Veritabani Performans Optimizasyonu ve Izleme

**BLM4522 - Ag Tabanli Paralel Dagitim Sistemleri**

## Proje Hakkinda
PostgreSQL kullanarak sorgu optimizasyonu, indeksleme stratejileri, performans izleme ve raporlama. EXPLAIN ANALYZE ile yavas sorgu tespiti ve iyilestirmesi.

## Senaryo: Online Egitim Platformu
50.000+ satirlik buyuk veri seti uzerinde performans analizi.

## Proje Yapisi
```
Proje1-Performans-Optimizasyon/
├── scripts/
│   ├── 01_veritabani_olustur.sql         # Egitim DB semasi (10 tablo)
│   ├── 02_ornek_veri_yukle.sql           # 50.000+ ornek veri
│   ├── 03_yavas_sorgu_analizi.sql        # EXPLAIN ANALYZE (indekssiz)
│   ├── 04_indeksleme_stratejileri.sql    # Indeks olusturma
│   ├── 05_sorgu_optimizasyonu.sql        # Optimize sorgular
│   ├── 06_performans_izleme.sh           # pg_stat izleme + HTML rapor
│   ├── 07_benchmark.sh                   # Oncesi/sonrasi karsilastirma
│   └── 08_tam_demo.sh                    # Tam demo
├── rapor/rapor.md
├── reports/                               # HTML raporlar
└── logs/
```

## Hizli Baslangic
```bash
export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"
chmod +x scripts/*.sh
bash scripts/08_tam_demo.sh    # Hepsini calistirir
```

## Kapsanan Konular
| Konu | Aciklama |
|------|----------|
| EXPLAIN ANALYZE | Sorgu plani analizi, Seq Scan vs Index Scan |
| B-Tree Indeks | Temel indeksleme |
| Composite Indeks | Coklu kolon indeksi |
| Partial Indeks | Kosullu indeks (WHERE) |
| Covering Indeks | INCLUDE ile index-only scan |
| pg_trgm | LIKE aramalari icin trigram indeks |
| Materialized View | Onbelleklenmis karmasik sorgu |
| CTE Optimizasyon | Subquery -> CTE donusumu |
| EXISTS vs IN | Performans karsilastirmasi |
| pg_stat Views | Canli performans izleme |
| Cache Hit Ratio | Buffer/cache verimlilik analizi |
| Table Bloat | Tablo siskinlik analizi |
| Benchmark | Oncesi/sonrasi olcum ve karsilastirma |
