#!/bin/bash
# ============================================================================
# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Dosya: 09_yedek_test.sh
# Açıklama: Yedeklerin Doğruluğunu Test Etme
# ============================================================================

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Değişkenler
DB_NAME="eticaret_db"
DB_USER=$(whoami)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
TEST_DB="eticaret_test_verify"
TEST_RESULTS_FILE="$LOG_DIR/yedek_test_sonuclari_${TIMESTAMP}.txt"

export PATH="$PG_BIN:$PATH"

mkdir -p "$LOG_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEK DOĞRULAMA VE TEST SİSTEMİ${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

# Sonuç dosyası
cat > "$TEST_RESULTS_FILE" << EOF
============================================
YEDEK DOĞRULAMA TEST SONUÇLARI
Tarih: $(date '+%Y-%m-%d %H:%M:%S')
Veritabanı: $DB_NAME
============================================

EOF

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test sonucu kaydet
record_test() {
    local test_name=$1
    local result=$2
    local detail=$3
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$result" = "PASS" ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "  ${GREEN}✓ GEÇTI${NC}: $test_name"
        echo "[$TOTAL_TESTS] GEÇTI - $test_name: $detail" >> "$TEST_RESULTS_FILE"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "  ${RED}✗ KALDI${NC}: $test_name"
        echo "[$TOTAL_TESTS] KALDI - $test_name: $detail" >> "$TEST_RESULTS_FILE"
    fi
}

# ============================================================================
# TEST 1: Güncel Yedek Oluşturma
# ============================================================================
echo -e "\n${YELLOW}[TEST GRUBU 1] Yedek Dosyası Oluşturma Testleri${NC}"

# 1.1 Custom format yedek
echo -e "\n${BLUE}Test 1.1: Custom format yedek oluşturma${NC}"
TEST_BACKUP="$BACKUP_DIR/full/${DB_NAME}_test_verify_${TIMESTAMP}.dump"
mkdir -p "$BACKUP_DIR/full"
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z 6 -f "$TEST_BACKUP" 2>> "$LOG_DIR/yedek_test_${TIMESTAMP}.log"
if [ $? -eq 0 ] && [ -f "$TEST_BACKUP" ]; then
    FILE_SIZE=$(stat -f%z "$TEST_BACKUP" 2>/dev/null || stat --printf="%s" "$TEST_BACKUP" 2>/dev/null)
    record_test "Custom format yedek oluşturma" "PASS" "Boyut: $FILE_SIZE bytes"
else
    record_test "Custom format yedek oluşturma" "FAIL" "Yedek oluşturulamadı"
fi

# 1.2 Plain SQL yedek
echo -e "\n${BLUE}Test 1.2: Plain SQL yedek oluşturma${NC}"
SQL_BACKUP="$BACKUP_DIR/full/${DB_NAME}_test_verify_${TIMESTAMP}.sql"
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fp --create --clean -f "$SQL_BACKUP" 2>> "$LOG_DIR/yedek_test_${TIMESTAMP}.log"
if [ $? -eq 0 ] && [ -f "$SQL_BACKUP" ]; then
    FILE_SIZE=$(stat -f%z "$SQL_BACKUP" 2>/dev/null || stat --printf="%s" "$SQL_BACKUP" 2>/dev/null)
    record_test "Plain SQL yedek oluşturma" "PASS" "Boyut: $FILE_SIZE bytes"
else
    record_test "Plain SQL yedek oluşturma" "FAIL" "Yedek oluşturulamadı"
fi

# ============================================================================
# TEST 2: Yedek Dosyası Bütünlük Kontrolleri
# ============================================================================
echo -e "\n${YELLOW}[TEST GRUBU 2] Yedek Bütünlük Kontrolleri${NC}"

# 2.1 pg_restore --list ile içerik doğrulama
echo -e "\n${BLUE}Test 2.1: Yedek içerik listesi kontrolü${NC}"
RESTORE_LIST=$(pg_restore --list "$TEST_BACKUP" 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$RESTORE_LIST" ]; then
    TABLE_COUNT=$(echo "$RESTORE_LIST" | grep -c "TABLE")
    INDEX_COUNT=$(echo "$RESTORE_LIST" | grep -c "INDEX")
    TRIGGER_COUNT=$(echo "$RESTORE_LIST" | grep -c "TRIGGER")
    FUNCTION_COUNT=$(echo "$RESTORE_LIST" | grep -c "FUNCTION")
    record_test "Yedek içerik doğrulama" "PASS" "Tablolar:$TABLE_COUNT İndeksler:$INDEX_COUNT Triggerlar:$TRIGGER_COUNT Fonksiyonlar:$FUNCTION_COUNT"
    
    echo -e "    Tablolar: $TABLE_COUNT"
    echo -e "    İndeksler: $INDEX_COUNT"
    echo -e "    Trigger'lar: $TRIGGER_COUNT"
    echo -e "    Fonksiyonlar: $FUNCTION_COUNT"
else
    record_test "Yedek içerik doğrulama" "FAIL" "İçerik listesi alınamadı"
fi

# 2.2 Dosya boyutu kontrolü (sıfır olmadığından emin ol)
echo -e "\n${BLUE}Test 2.2: Dosya boyutu kontrolü${NC}"
DUMP_SIZE=$(stat -f%z "$TEST_BACKUP" 2>/dev/null || stat --printf="%s" "$TEST_BACKUP" 2>/dev/null)
if [ "$DUMP_SIZE" -gt 1000 ]; then
    record_test "Yedek dosya boyutu kontrolü" "PASS" "$DUMP_SIZE bytes (> 1KB)"
else
    record_test "Yedek dosya boyutu kontrolü" "FAIL" "Dosya çok küçük: $DUMP_SIZE bytes"
fi

# 2.3 SQL dosyası syntax kontrolü
echo -e "\n${BLUE}Test 2.3: SQL dosyası içerik kontrolü${NC}"
HAS_CREATE=$(grep -c "CREATE TABLE" "$SQL_BACKUP" 2>/dev/null)
HAS_INSERT=$(grep -c "INSERT\|COPY" "$SQL_BACKUP" 2>/dev/null)
if [ "$HAS_CREATE" -gt 0 ] && [ "$HAS_INSERT" -gt 0 ]; then
    record_test "SQL içerik kontrolü" "PASS" "CREATE:$HAS_CREATE INSERT/COPY:$HAS_INSERT satır"
else
    record_test "SQL içerik kontrolü" "FAIL" "CREATE veya INSERT komutları eksik"
fi

# ============================================================================
# TEST 3: Yedekten Geri Yükleme Testleri
# ============================================================================
echo -e "\n${YELLOW}[TEST GRUBU 3] Geri Yükleme (Restore) Testleri${NC}"

# Test veritabanı oluştur
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null
psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $TEST_DB;" 2>> "$LOG_DIR/yedek_test_${TIMESTAMP}.log"

# 3.1 Custom format restore
echo -e "\n${BLUE}Test 3.1: Custom format geri yükleme${NC}"
START_TIME=$(date +%s)
pg_restore -U "$DB_USER" -d "$TEST_DB" \
    --clean --if-exists \
    --single-transaction \
    "$TEST_BACKUP" 2>> "$LOG_DIR/yedek_test_${TIMESTAMP}.log"
RESTORE_RESULT=$?
END_TIME=$(date +%s)
RESTORE_DURATION=$((END_TIME - START_TIME))

if [ $RESTORE_RESULT -eq 0 ] || [ $RESTORE_RESULT -eq 1 ]; then
    record_test "Custom format geri yükleme" "PASS" "Süre: ${RESTORE_DURATION}s"
else
    record_test "Custom format geri yükleme" "FAIL" "Exit code: $RESTORE_RESULT"
fi

# 3.2 Kayıt sayısı karşılaştırması
echo -e "\n${BLUE}Test 3.2: Kayıt sayısı karşılaştırması${NC}"
TABLES=("kategoriler" "tedarikciler" "musteriler" "urunler" "siparisler" "siparis_detaylari" "odemeler" "stok_hareketleri")
MATCH_COUNT=0
MISMATCH_COUNT=0

printf "\n  %-25s %12s %12s %s\n" "Tablo" "Orijinal" "Restore" "Durum"
printf "  %-25s %12s %12s %s\n" "-------------------------" "----------" "----------" "------"

for TABLE in "${TABLES[@]}"; do
    ORIG_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
    REST_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
    
    if [ "$ORIG_COUNT" = "$REST_COUNT" ]; then
        STATUS="✓"
        MATCH_COUNT=$((MATCH_COUNT + 1))
    else
        STATUS="✗"
        MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
    fi
    
    printf "  %-25s %12s %12s %s\n" "$TABLE" "$ORIG_COUNT" "$REST_COUNT" "$STATUS"
done

if [ $MISMATCH_COUNT -eq 0 ]; then
    record_test "Kayıt sayısı eşleşmesi" "PASS" "$MATCH_COUNT/${#TABLES[@]} tablo eşleşiyor"
else
    record_test "Kayıt sayısı eşleşmesi" "FAIL" "$MISMATCH_COUNT tablo farklı"
fi

# ============================================================================
# TEST 4: Veri Bütünlüğü Testleri
# ============================================================================
echo -e "\n${YELLOW}[TEST GRUBU 4] Veri Bütünlüğü Testleri${NC}"

# 4.1 Foreign key ilişkileri
echo -e "\n${BLUE}Test 4.1: Foreign key ilişkileri kontrolü${NC}"
FK_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public';
EOSQL
)
ORIG_FK_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public';
EOSQL
)
if [ "$FK_COUNT" = "$ORIG_FK_COUNT" ]; then
    record_test "Foreign key ilişkileri" "PASS" "$FK_COUNT foreign key mevcut"
else
    record_test "Foreign key ilişkileri" "FAIL" "Orijinal: $ORIG_FK_COUNT, Restore: $FK_COUNT"
fi

# 4.2 İndeks kontrolü
echo -e "\n${BLUE}Test 4.2: İndeks kontrolü${NC}"
IDX_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';
EOSQL
)
ORIG_IDX_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';
EOSQL
)
if [ "$IDX_COUNT" = "$ORIG_IDX_COUNT" ]; then
    record_test "İndeks sayısı eşleşmesi" "PASS" "$IDX_COUNT indeks mevcut"
else
    record_test "İndeks sayısı eşleşmesi" "FAIL" "Orijinal: $ORIG_IDX_COUNT, Restore: $IDX_COUNT"
fi

# 4.3 View kontrolü
echo -e "\n${BLUE}Test 4.3: View (Görünüm) kontrolü${NC}"
VIEW_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public';
EOSQL
)
ORIG_VIEW_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public';
EOSQL
)
if [ "$VIEW_COUNT" = "$ORIG_VIEW_COUNT" ]; then
    record_test "View sayısı eşleşmesi" "PASS" "$VIEW_COUNT view mevcut"
else
    record_test "View sayısı eşleşmesi" "FAIL" "Orijinal: $ORIG_VIEW_COUNT, Restore: $VIEW_COUNT"
fi

# 4.4 Trigger/Function kontrolü
echo -e "\n${BLUE}Test 4.4: Trigger ve Fonksiyon kontrolü${NC}"
FUNC_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public';
EOSQL
)
ORIG_FUNC_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A << EOSQL 2>/dev/null
SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public';
EOSQL
)
if [ "$FUNC_COUNT" = "$ORIG_FUNC_COUNT" ]; then
    record_test "Fonksiyon sayısı eşleşmesi" "PASS" "$FUNC_COUNT fonksiyon mevcut"
else
    record_test "Fonksiyon sayısı eşleşmesi" "FAIL" "Orijinal: $ORIG_FUNC_COUNT, Restore: $FUNC_COUNT"
fi

# 4.5 Veri doğruluk kontrolü (checksum benzeri)
echo -e "\n${BLUE}Test 4.5: Veri doğruluğu (toplam/ortalama kontrolü)${NC}"
ORIG_SUM=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT ROUND(SUM(birim_fiyat), 2) FROM urunler;" 2>/dev/null)
REST_SUM=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "SELECT ROUND(SUM(birim_fiyat), 2) FROM urunler;" 2>/dev/null)
if [ "$ORIG_SUM" = "$REST_SUM" ]; then
    record_test "Ürün fiyat toplamı kontrolü" "PASS" "Toplam: ₺$ORIG_SUM"
else
    record_test "Ürün fiyat toplamı kontrolü" "FAIL" "Orijinal: ₺$ORIG_SUM, Restore: ₺$REST_SUM"
fi

# ============================================================================
# TEST 5: Performans Testi
# ============================================================================
echo -e "\n${YELLOW}[TEST GRUBU 5] Yedekleme/Geri Yükleme Performans Testleri${NC}"

# 5.1 Yedekleme süresi
echo -e "\n${BLUE}Test 5.1: Yedekleme performansı${NC}"
START_TIME=$(date +%s%N)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z 6 -f /dev/null 2>/dev/null
END_TIME=$(date +%s%N)
BACKUP_TIME_MS=$(( (END_TIME - START_TIME) / 1000000 ))
record_test "Yedekleme performansı" "PASS" "Süre: ${BACKUP_TIME_MS}ms"
echo -e "    Yedekleme süresi: ${BACKUP_TIME_MS}ms"

# 5.2 Veritabanı boyutu
echo -e "\n${BLUE}Test 5.2: Veritabanı boyutu raporu${NC}"
DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
DUMP_SIZE_HR=$(ls -lh "$TEST_BACKUP" 2>/dev/null | awk '{print $5}')
echo -e "    Veritabanı boyutu: $DB_SIZE"
echo -e "    Yedek boyutu: $DUMP_SIZE_HR"
record_test "Boyut raporu" "PASS" "DB: $DB_SIZE, Yedek: $DUMP_SIZE_HR"

# ============================================================================
# Temizlik
# ============================================================================
echo -e "\n${YELLOW}Temizlik yapılıyor...${NC}"
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null
echo -e "${GREEN}  ✓ Test veritabanı temizlendi${NC}"

# ============================================================================
# SONUÇ RAPORU
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   TEST SONUÇ RAPORU${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "  Toplam Test: $TOTAL_TESTS"
echo -e "  ${GREEN}Geçti: $PASSED_TESTS${NC}"
echo -e "  ${RED}Kaldı: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n  ${GREEN}🎉 TÜM TESTLER BAŞARILI!${NC}"
    PASS_RATE=100
else
    PASS_RATE=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)
    echo -e "\n  ${YELLOW}⚠ Başarı oranı: %$PASS_RATE${NC}"
fi

# Sonuç dosyasına yaz
cat >> "$TEST_RESULTS_FILE" << EOF

============================================
SONUÇ: $PASSED_TESTS/$TOTAL_TESTS test başarılı (%$PASS_RATE)
============================================
EOF

echo -e "\n  Detaylı rapor: $TEST_RESULTS_FILE"
echo -e "\n${GREEN}Yedek doğrulama testleri tamamlandı!${NC}"
