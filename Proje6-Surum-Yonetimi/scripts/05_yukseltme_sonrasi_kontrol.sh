#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="kutuphane_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/yukseltme_sonrasi_${TIMESTAMP}.log"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

PASS=0; FAIL=0

test_r() {
    local name=$1 result=$2
    if [ "$result" -eq 0 ]; then
        echo -e "  ${GREEN}GECTI${NC}: $name"; PASS=$((PASS+1))
    else
        echo -e "  ${RED}KALDI${NC}: $name"; FAIL=$((FAIL+1))
    fi
    echo "[$( [ $result -eq 0 ] && echo 'GECTI' || echo 'KALDI')] $name" >> "$LOG_FILE"
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YUKSELTME SONRASI KONTROL${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

CURRENT_VER=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT version_no FROM schema_version WHERE durum='basarili' ORDER BY version_id DESC LIMIT 1;
" 2>/dev/null)
echo -e "\n  Mevcut surum: ${BLUE}$CURRENT_VER${NC}"

echo -e "\n${YELLOW}[Test 1] Tablo Varlik Kontrolu${NC}"

for tbl in schema_version yazarlar kategoriler kitaplar uyeler odunc_islemleri; do
    EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$tbl' AND table_schema='public';
    " 2>/dev/null)
    [ "$EXISTS" = "1" ] && test_r "v1.0 tablo: $tbl" 0 || test_r "v1.0 tablo: $tbl" 1
done

if [ "$CURRENT_VER" = "2.0.0" ] || [ "$CURRENT_VER" = "3.0.0" ]; then
    for tbl in yayinevleri kitap_yazarlar cezalar rezervasyonlar; do
        EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
            SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$tbl' AND table_schema='public';
        " 2>/dev/null)
        [ "$EXISTS" = "1" ] && test_r "v2.0 tablo: $tbl" 0 || test_r "v2.0 tablo: $tbl" 1
    done
fi

if [ "$CURRENT_VER" = "3.0.0" ]; then
    for tbl in dijital_kitaplar etkinlikler etkinlik_katilim degerlendirmeler bildirimler; do
        EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
            SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$tbl' AND table_schema='public';
        " 2>/dev/null)
        [ "$EXISTS" = "1" ] && test_r "v3.0 tablo: $tbl" 0 || test_r "v3.0 tablo: $tbl" 1
    done
fi

echo -e "\n${YELLOW}[Test 2] Kolon Kontrolu${NC}"

if [ "$CURRENT_VER" = "2.0.0" ] || [ "$CURRENT_VER" = "3.0.0" ]; then
    for col in "kitaplar|yayinevi_id" "kitaplar|dil" "uyeler|uyelik_tipi" "uyeler|max_odunc"; do
        TBL=$(echo $col | cut -d'|' -f1)
        COL=$(echo $col | cut -d'|' -f2)
        EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
            SELECT COUNT(*) FROM information_schema.columns WHERE table_name='$TBL' AND column_name='$COL';
        " 2>/dev/null)
        [ "$EXISTS" = "1" ] && test_r "v2.0 kolon: $TBL.$COL" 0 || test_r "v2.0 kolon: $TBL.$COL" 1
    done
fi

if [ "$CURRENT_VER" = "3.0.0" ]; then
    for col in "kitaplar|ort_puan" "kitaplar|dijital_mevcut" "uyeler|toplam_odunc"; do
        TBL=$(echo $col | cut -d'|' -f1)
        COL=$(echo $col | cut -d'|' -f2)
        EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
            SELECT COUNT(*) FROM information_schema.columns WHERE table_name='$TBL' AND column_name='$COL';
        " 2>/dev/null)
        [ "$EXISTS" = "1" ] && test_r "v3.0 kolon: $TBL.$COL" 0 || test_r "v3.0 kolon: $TBL.$COL" 1
    done
fi

echo -e "\n${YELLOW}[Test 3] Veri Butunlugu${NC}"

echo -e "  ${BLUE}Tablo kayit sayilari:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT relname AS tablo, n_live_tup AS kayit
    FROM pg_stat_user_tables WHERE schemaname='public'
    ORDER BY n_live_tup DESC;
" 2>/dev/null

FK_OK=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public';
" 2>/dev/null)
test_r "Foreign key iliskileri ($FK_OK adet)" 0

TOTAL=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT SUM(n_live_tup) FROM pg_stat_user_tables WHERE schemaname='public';
" 2>/dev/null)
echo -e "  Toplam kayit: ${BLUE}$TOTAL${NC}"
[ "$TOTAL" -gt 0 ] 2>/dev/null && test_r "Veri mevcut ($TOTAL kayit)" 0 || test_r "Veri kontrolu" 1

echo -e "\n${YELLOW}[Test 4] View ve Fonksiyon${NC}"

VIEW_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public';
" 2>/dev/null)
test_r "View sayisi: $VIEW_COUNT" 0

if [ "$CURRENT_VER" = "3.0.0" ]; then
    psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM v_kutuphane_istatistik;" > /dev/null 2>&1
    test_r "v_kutuphane_istatistik calisiyor" $?
    
    psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM v_populer_kitaplar LIMIT 1;" > /dev/null 2>&1
    test_r "v_populer_kitaplar calisiyor" $?
fi

echo -e "\n${YELLOW}[Test 5] Performans${NC}"

START_P=$(date +%s%N)
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM kitaplar k JOIN yazarlar y ON k.yazar_id=y.yazar_id;" > /dev/null 2>&1
END_P=$(date +%s%N)
QUERY_MS=$(( (END_P - START_P) / 1000000 ))
test_r "Join sorgu performansi (${QUERY_MS}ms)" 0

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
echo -e "  Veritabani boyutu: ${BLUE}$DB_SIZE${NC}"

TOTAL_T=$((PASS + FAIL))
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   KONTROL SONUCU${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Surum: ${BLUE}$CURRENT_VER${NC}"
echo -e "  Toplam: $TOTAL_T | Gecti: ${GREEN}$PASS${NC} | Kaldi: ${RED}$FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}TUM TESTLER BASARILI - Yukseltme dogrulandi!${NC}"
else
    echo -e "  ${RED}$FAIL TEST BASARISIZ - Rollback dusunulebilir!${NC}"
fi
echo -e "  Log: $(basename $LOG_FILE)"
