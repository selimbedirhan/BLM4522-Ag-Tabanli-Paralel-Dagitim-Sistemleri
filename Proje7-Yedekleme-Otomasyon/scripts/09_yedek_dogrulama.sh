#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_DIR/config/yedekleme_ayar.conf" 2>/dev/null

BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
export PATH="${PG_BIN:-/opt/homebrew/opt/postgresql@14/bin}:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_LOG="$LOG_DIR/dogrulama_${TIMESTAMP}.log"
TEST_DB="${VERIFY_TEST_DB:-hastane_db_verify_test}"

mkdir -p "$LOG_DIR"

PASS=0; FAIL=0

test_result() {
    local name=$1 result=$2
    if [ "$result" -eq 0 ]; then
        echo -e "  ${GREEN}GECTI${NC}: $name"
        echo "GECTI: $name" >> "$TEST_LOG"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}KALDI${NC}: $name"
        echo "KALDI: $name" >> "$TEST_LOG"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   OTOMATIK YEDEK DOGRULAMA${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}[Test 1] Yedek Olusturma${NC}"

TEST_DUMP="$BACKUP_DIR/daily/dogrulama_test_${TIMESTAMP}.dump"
TEST_SQL="$BACKUP_DIR/daily/dogrulama_test_${TIMESTAMP}.sql"

pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -f "$TEST_DUMP" 2>> "$TEST_LOG"
test_result "Custom format yedek olusturma" $?

pg_dump -U "$DB_USER" -d "$DB_NAME" -Fp -f "$TEST_SQL" 2>> "$TEST_LOG"
test_result "Plain SQL yedek olusturma" $?

echo -e "\n${YELLOW}[Test 2] Butunluk Kontrolleri${NC}"

OBJ_COUNT=$(pg_restore --list "$TEST_DUMP" 2>/dev/null | wc -l | tr -d ' ')
if [ "$OBJ_COUNT" -gt 10 ]; then
    test_result "Yedek icerik kontrolu ($OBJ_COUNT obje)" 0
else
    test_result "Yedek icerik kontrolu" 1
fi

DUMP_SIZE=$(stat -f%z "$TEST_DUMP" 2>/dev/null || echo "0")
if [ "$DUMP_SIZE" -gt 1024 ]; then
    test_result "Dosya boyutu kontrolu ($(echo "scale=0;$DUMP_SIZE/1024" | bc)KB)" 0
else
    test_result "Dosya boyutu kontrolu" 1
fi

if grep -q "CREATE TABLE" "$TEST_SQL" 2>/dev/null && grep -q "INSERT INTO\|COPY" "$TEST_SQL" 2>/dev/null; then
    test_result "SQL icerik kontrolu (CREATE TABLE + veri)" 0
else
    test_result "SQL icerik kontrolu" 1
fi

echo -e "\n${YELLOW}[Test 3] Restore Testi${NC}"

psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" > /dev/null 2>&1
psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $TEST_DB;" > /dev/null 2>&1
test_result "Test veritabani olusturma" $?

pg_restore -U "$DB_USER" -d "$TEST_DB" --no-owner --no-privileges "$TEST_DUMP" 2>> "$TEST_LOG"
test_result "Yedekten geri yukleme" $?

echo -e "\n${YELLOW}[Test 4] Veri Butunlugu${NC}"

echo -e "  ${BLUE}Kayit Karsilastirmasi:${NC}"
printf "  %-20s %10s %10s %s\n" "Tablo" "Orijinal" "Restore" "Durum"
printf "  %-20s %10s %10s %s\n" "--------------------" "----------" "----------" "------"

ALL_MATCH=0
for tbl in bolumler doktorlar hastalar ilaclar randevular muayeneler yatislar receteler faturalar; do
    ORIG=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM $tbl;" 2>/dev/null)
    REST=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "SELECT COUNT(*) FROM $tbl;" 2>/dev/null)
    if [ "$ORIG" = "$REST" ]; then
        STATUS="✓"
    else
        STATUS="✗"
        ALL_MATCH=1
    fi
    printf "  %-20s %10s %10s %s\n" "$tbl" "$ORIG" "$REST" "$STATUS"
done
test_result "Kayit sayisi eslesmesi" $ALL_MATCH

FK_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "
    SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public';
" 2>/dev/null)
ORIG_FK=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public';
" 2>/dev/null)
if [ "$FK_COUNT" = "$ORIG_FK" ]; then
    test_result "Foreign key iliskileri ($FK_COUNT adet)" 0
else
    test_result "Foreign key iliskileri (beklenen: $ORIG_FK, bulunan: $FK_COUNT)" 1
fi

IDX_ORIG=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public';" 2>/dev/null)
IDX_REST=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public';" 2>/dev/null)
if [ "$IDX_ORIG" = "$IDX_REST" ]; then
    test_result "Indeks sayisi eslesmesi ($IDX_ORIG)" 0
else
    test_result "Indeks sayisi (beklenen: $IDX_ORIG, bulunan: $IDX_REST)" 1
fi

FN_ORIG=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_proc WHERE pronamespace=(SELECT oid FROM pg_namespace WHERE nspname='public');" 2>/dev/null)
FN_REST=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "SELECT COUNT(*) FROM pg_proc WHERE pronamespace=(SELECT oid FROM pg_namespace WHERE nspname='public');" 2>/dev/null)
if [ "$FN_ORIG" = "$FN_REST" ]; then
    test_result "Fonksiyon sayisi ($FN_ORIG)" 0
else
    test_result "Fonksiyon sayisi (beklenen: $FN_ORIG, bulunan: $FN_REST)" 1
fi

echo -e "\n${YELLOW}[Test 5] Performans${NC}"

START_PERF=$(date +%s%N)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -f /dev/null 2>/dev/null
END_PERF=$(date +%s%N)
PERF_MS=$(( (END_PERF - START_PERF) / 1000000 ))
test_result "Yedekleme performansi (${PERF_MS}ms)" 0

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_database_size('$DB_NAME');" 2>/dev/null)
echo -e "  Veritabani: $(echo "scale=2;$DB_SIZE/1048576" | bc)MB | Yedek: $(echo "scale=2;$DUMP_SIZE/1024" | bc)KB | Oran: $(echo "scale=1;$DUMP_SIZE*100/$DB_SIZE" | bc)%"

echo -e "\n${YELLOW}Temizlik...${NC}"
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" > /dev/null 2>&1
rm -f "$TEST_DUMP" "$TEST_SQL"
echo -e "  ${GREEN}Test veritabani ve dosyalar temizlendi${NC}"

psql -U "$DB_USER" -d "$DB_NAME" -c "
    INSERT INTO yedekleme_log (yedek_tipi, dosya_adi, sure_saniye, durum, aciklama)
    VALUES ('dogrulama', 'dogrulama_test_${TIMESTAMP}', $((PERF_MS/1000)),
            '$([ $FAIL -eq 0 ] && echo "dogrulandi" || echo "basarisiz")',
            '$PASS gecti, $FAIL kaldi');
" 2>/dev/null

TOTAL=$((PASS + FAIL))
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   DOGRULAMA SONUCLARI${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Toplam: $TOTAL | Gecti: ${GREEN}$PASS${NC} | Kaldi: ${RED}$FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}TUM TESTLER BASARILI!${NC}"
else
    echo -e "  ${RED}$FAIL TEST BASARISIZ!${NC}"
fi

echo -e "  Log: $(basename $TEST_LOG)"
echo -e "\n${GREEN}Dogrulama tamamlandi!${NC}"
