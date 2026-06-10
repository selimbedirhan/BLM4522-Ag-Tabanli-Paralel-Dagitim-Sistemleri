#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="egitim_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  BLM4522 - Proje 1                           ║${NC}"
echo -e "${MAGENTA}║  Performans Optimizasyonu ve Izleme           ║${NC}"
echo -e "${MAGENTA}║  PostgreSQL 14 | $(date '+%Y-%m-%d %H:%M:%S')            ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

run_step() {
    local num=$1 title=$2
    echo -e "\n${MAGENTA}━━━ ADIM $num: $title ━━━${NC}\n"
}

run_step 1 "Veritabani Olusturma"
psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/01_veritabani_olustur.sql" 2>&1 | tail -5
sleep 1

run_step 2 "Ornek Veri Yukleme (50.000+ satir)"
psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/02_ornek_veri_yukle.sql" 2>&1 | tail -15
sleep 1

run_step 3 "Yavas Sorgu Analizi (Indekssiz)"
echo -e "  ${BLUE}EXPLAIN ANALYZE ciktilari (indekssiz Seq Scan):${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN ANALYZE SELECT * FROM ogrenciler WHERE sehir = 'Istanbul';" 2>/dev/null | head -10
echo "  ..."
psql -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN ANALYZE SELECT COUNT(*) FROM odemeler WHERE odeme_tarihi >= CURRENT_TIMESTAMP - INTERVAL '30 days' AND durum = 'basarili';" 2>/dev/null | head -10
sleep 1

run_step 4 "Indeksleme Stratejileri"
psql -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/04_indeksleme_stratejileri.sql" 2>&1 | grep -E "olusturuldu|Toplam|boyut"
sleep 1

run_step 5 "Optimize Sorgu Analizi (Indeksli)"
echo -e "  ${BLUE}EXPLAIN ANALYZE ciktilari (indeksli Index Scan):${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN ANALYZE SELECT * FROM ogrenciler WHERE sehir = 'Istanbul';" 2>/dev/null | head -10
echo "  ..."
psql -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN ANALYZE SELECT COUNT(*) FROM odemeler WHERE odeme_tarihi >= CURRENT_TIMESTAMP - INTERVAL '30 days' AND durum = 'basarili';" 2>/dev/null | head -10
sleep 1

run_step 6 "Performans Izleme ve Raporlama"
bash "$SCRIPT_DIR/06_performans_izleme.sh" 2>&1
sleep 1

run_step 7 "Benchmark (Oncesi/Sonrasi Karsilastirma)"
bash "$SCRIPT_DIR/07_benchmark.sh" 2>&1

echo -e "\n${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         DEMO TAMAMLANDI                       ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Gosterilen Konular:${NC}"
echo -e "  ${GREEN}1.${NC} Buyuk veri seti olusturma (50.000+ kayit)"
echo -e "  ${GREEN}2.${NC} EXPLAIN ANALYZE ile yavas sorgu tespiti"
echo -e "  ${GREEN}3.${NC} Indeksleme stratejileri (B-tree, Composite, Partial, Covering, trgm)"
echo -e "  ${GREEN}4.${NC} Sorgu optimizasyonu (CTE, Materialized View, EXISTS vs IN)"
echo -e "  ${GREEN}5.${NC} pg_stat view'lari ile performans izleme"
echo -e "  ${GREEN}6.${NC} Cache hit orani, table bloat, indeks kullanim analizi"
echo -e "  ${GREEN}7.${NC} Oncesi/Sonrasi benchmark karsilastirmasi"

echo -e "\n${GREEN}Proje 1: Performans Optimizasyonu tamamlandi!${NC}"
