#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="egitim_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

measure_query() {
    local query=$1
    local result=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        EXPLAIN (ANALYZE, FORMAT JSON) $query
    " 2>/dev/null | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
print(data[0]['Execution Time'])
" 2>/dev/null)
    echo "${result:-0}"
}

echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  PERFORMANS BENCHMARK                        ║${NC}"
echo -e "${MAGENTA}║  Indeks Oncesi vs Sonrasi Karsilastirma      ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

declare -a QUERY_NAMES=(
    "Sehre gore arama"
    "Kurs-Egitmen JOIN"
    "Odeme tarih filtre"
    "Kayit durum filtre"
    "Ders ilerleme agregasyon"
    "Kurs adi LIKE arama"
)

declare -a QUERIES=(
    "SELECT COUNT(*) FROM ogrenciler WHERE sehir = 'Istanbul'"
    "SELECT COUNT(*) FROM kurslar k JOIN egitmenler e ON k.egitmen_id = e.egitmen_id WHERE k.seviye = 'ileri'"
    "SELECT COUNT(*) FROM odemeler WHERE odeme_tarihi >= CURRENT_TIMESTAMP - INTERVAL '30 days' AND durum = 'basarili'"
    "SELECT COUNT(*) FROM kayitlar WHERE durum = 'aktif' AND ogrenci_id < 1000"
    "SELECT ogrenci_id, COUNT(*) FROM ders_ilerleme WHERE tamamlandi = TRUE GROUP BY ogrenci_id HAVING COUNT(*) > 3 LIMIT 10"
    "SELECT COUNT(*) FROM kurslar WHERE kurs_adi LIKE '%Python%'"
)

echo -e "\n${YELLOW}[Adim 1] Indeksleri kaldirma (baseline icin)...${NC}"

psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT 'DROP INDEX IF EXISTS ' || indexname || ';'
    FROM pg_indexes WHERE schemaname='public'
    AND indexname NOT LIKE '%_pkey' AND indexname NOT LIKE 'pg_%';
" 2>/dev/null | psql -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1

psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_stat_reset();" > /dev/null 2>&1
echo -e "  ${GREEN}Indeksler kaldirildi (baseline hazir)${NC}"

echo -e "\n${YELLOW}[Adim 2] Indekssiz olcumler...${NC}"

declare -a BEFORE_TIMES=()
for i in "${!QUERIES[@]}"; do
    psql -U "$DB_USER" -d "$DB_NAME" -c "${QUERIES[$i]}" > /dev/null 2>&1
    
    total=0
    for run in 1 2 3; do
        ms=$(measure_query "${QUERIES[$i]}")
        total=$(echo "$total + $ms" | bc 2>/dev/null)
    done
    avg=$(echo "scale=2; $total / 3" | bc 2>/dev/null)
    BEFORE_TIMES+=("$avg")
    printf "  %-30s %8s ms\n" "${QUERY_NAMES[$i]}" "$avg"
done

echo -e "\n${YELLOW}[Adim 3] Indeksleri olusturma...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/04_indeksleme_stratejileri.sql" > /dev/null 2>&1
echo -e "  ${GREEN}Indeksler olusturuldu${NC}"

psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_stat_reset();" > /dev/null 2>&1

echo -e "\n${YELLOW}[Adim 4] Indeksli olcumler...${NC}"

declare -a AFTER_TIMES=()
for i in "${!QUERIES[@]}"; do
    psql -U "$DB_USER" -d "$DB_NAME" -c "${QUERIES[$i]}" > /dev/null 2>&1
    
    total=0
    for run in 1 2 3; do
        ms=$(measure_query "${QUERIES[$i]}")
        total=$(echo "$total + $ms" | bc 2>/dev/null)
    done
    avg=$(echo "scale=2; $total / 3" | bc 2>/dev/null)
    AFTER_TIMES+=("$avg")
    printf "  %-30s %8s ms\n" "${QUERY_NAMES[$i]}" "$avg"
done

echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                    BENCHMARK SONUCLARI                            ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}"

printf "\n  ${BLUE}%-30s %10s %10s %10s %8s${NC}\n" "Sorgu" "Oncesi" "Sonrasi" "Fark" "Iyilesme"
printf "  %-30s %10s %10s %10s %8s\n" "------------------------------" "----------" "----------" "----------" "--------"

for i in "${!QUERY_NAMES[@]}"; do
    before="${BEFORE_TIMES[$i]}"
    after="${AFTER_TIMES[$i]}"
    
    if [ -n "$before" ] && [ -n "$after" ] && [ "$before" != "0" ]; then
        diff=$(echo "scale=2; $before - $after" | bc 2>/dev/null)
        pct=$(echo "scale=1; ($before - $after) * 100 / $before" | bc 2>/dev/null)
        
        color="$GREEN"
        [ "$(echo "$pct < 0" | bc 2>/dev/null)" = "1" ] && color="$RED"
        
        printf "  %-30s %8s ms %8s ms %8s ms ${color}%6s%%${NC}\n" \
            "${QUERY_NAMES[$i]}" "$before" "$after" "$diff" "$pct"
    else
        printf "  %-30s %8s ms %8s ms %10s %8s\n" \
            "${QUERY_NAMES[$i]}" "${before:-N/A}" "${after:-N/A}" "N/A" "N/A"
    fi
done

for i in "${!QUERY_NAMES[@]}"; do
    psql -U "$DB_USER" -d "$DB_NAME" -c "
        INSERT INTO performans_log (sorgu_adi, calisma_suresi_ms, indeks_kullanimi, notlar)
        VALUES ('${QUERY_NAMES[$i]}', ${AFTER_TIMES[$i]:-0}, true, 'Benchmark sonrasi: oncesi=${BEFORE_TIMES[$i]:-0}ms');
    " > /dev/null 2>&1
done

echo -e "\n${GREEN}Benchmark tamamlandi!${NC}"
echo -e "  Sonuclar performans_log tablosuna kaydedildi."
