#!/bin/bash
# ============================================================================
# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Dosya: 03_tam_yedekleme.sh
# Açıklama: Tam (Full) Yedekleme İşlemleri
# ============================================================================

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Değişkenler
DB_NAME="eticaret_db"
DB_USER=$(whoami)
BACKUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/backups"
LOG_DIR="$(cd "$(dirname "$0")/.." && pwd)/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"

# PATH ayarla
export PATH="$PG_BIN:$PATH"

# Dizinleri oluştur
mkdir -p "$BACKUP_DIR/full" "$LOG_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   TAM (FULL) YEDEKLEME İŞLEMLERİ${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

# Fonksiyon: Yedekleme boyutunu formatla
format_size() {
    local size=$1
    if [ "$size" -gt 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    elif [ "$size" -gt 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    else
        echo "$size bytes"
    fi
}

# ============================================================================
# 1. Custom Format Yedekleme (pg_dump -Fc)
# En verimli format, sıkıştırma dahil, seçici geri yükleme destekler
# ============================================================================
echo -e "\n${YELLOW}[1/4] Custom Format Yedekleme (pg_dump -Fc)${NC}"
BACKUP_FILE_CUSTOM="$BACKUP_DIR/full/${DB_NAME}_full_custom_${TIMESTAMP}.dump"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z 6 \
    --verbose \
    --file="$BACKUP_FILE_CUSTOM" \
    2>> "$LOG_DIR/tam_yedekleme_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE_CUSTOM" 2>/dev/null || stat --printf="%s" "$BACKUP_FILE_CUSTOM" 2>/dev/null)
    echo -e "${GREEN}  ✓ Custom format yedekleme başarılı${NC}"
    echo -e "    Dosya: $BACKUP_FILE_CUSTOM"
    echo -e "    Boyut: $(format_size $FILE_SIZE)"
    echo -e "    Süre: ${DURATION} saniye"
else
    echo -e "${RED}  ✗ Custom format yedekleme BAŞARISIZ!${NC}"
fi

# ============================================================================
# 2. Plain SQL Format Yedekleme (pg_dump -Fp)
# Okunabilir SQL dosyası, herhangi bir PostgreSQL sürümüne restore edilebilir
# ============================================================================
echo -e "\n${YELLOW}[2/4] Plain SQL Format Yedekleme (pg_dump -Fp)${NC}"
BACKUP_FILE_SQL="$BACKUP_DIR/full/${DB_NAME}_full_plain_${TIMESTAMP}.sql"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fp \
    --create --clean --if-exists \
    --file="$BACKUP_FILE_SQL" \
    2>> "$LOG_DIR/tam_yedekleme_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE_SQL" 2>/dev/null || stat --printf="%s" "$BACKUP_FILE_SQL" 2>/dev/null)
    echo -e "${GREEN}  ✓ Plain SQL yedekleme başarılı${NC}"
    echo -e "    Dosya: $BACKUP_FILE_SQL"
    echo -e "    Boyut: $(format_size $FILE_SIZE)"
    echo -e "    Süre: ${DURATION} saniye"
else
    echo -e "${RED}  ✗ Plain SQL yedekleme BAŞARISIZ!${NC}"
fi

# ============================================================================
# 3. Sıkıştırılmış SQL Yedekleme (pg_dump + gzip)
# Disk alanı tasarrufu için SQL çıktısını gzip ile sıkıştırma
# ============================================================================
echo -e "\n${YELLOW}[3/4] Sıkıştırılmış SQL Yedekleme (gzip)${NC}"
BACKUP_FILE_GZIP="$BACKUP_DIR/full/${DB_NAME}_full_compressed_${TIMESTAMP}.sql.gz"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fp \
    --create --clean --if-exists \
    2>> "$LOG_DIR/tam_yedekleme_${TIMESTAMP}.log" | gzip -9 > "$BACKUP_FILE_GZIP"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE_GZIP" 2>/dev/null || stat --printf="%s" "$BACKUP_FILE_GZIP" 2>/dev/null)
    echo -e "${GREEN}  ✓ Sıkıştırılmış yedekleme başarılı${NC}"
    echo -e "    Dosya: $BACKUP_FILE_GZIP"
    echo -e "    Boyut: $(format_size $FILE_SIZE)"
    echo -e "    Süre: ${DURATION} saniye"
else
    echo -e "${RED}  ✗ Sıkıştırılmış yedekleme BAŞARISIZ!${NC}"
fi

# ============================================================================
# 4. Tar Format Yedekleme (pg_dump -Ft)
# Tar arşiv formatı, birden fazla dosya olarak saklar
# ============================================================================
echo -e "\n${YELLOW}[4/4] Tar Format Yedekleme (pg_dump -Ft)${NC}"
BACKUP_FILE_TAR="$BACKUP_DIR/full/${DB_NAME}_full_tar_${TIMESTAMP}.tar"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Ft \
    --file="$BACKUP_FILE_TAR" \
    2>> "$LOG_DIR/tam_yedekleme_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE_TAR" 2>/dev/null || stat --printf="%s" "$BACKUP_FILE_TAR" 2>/dev/null)
    echo -e "${GREEN}  ✓ Tar format yedekleme başarılı${NC}"
    echo -e "    Dosya: $BACKUP_FILE_TAR"
    echo -e "    Boyut: $(format_size $FILE_SIZE)"
    echo -e "    Süre: ${DURATION} saniye"
else
    echo -e "${RED}  ✗ Tar format yedekleme BAŞARISIZ!${NC}"
fi

# ============================================================================
# KARŞILAŞTIRMA TABLOSU
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEKLEME KARŞILAŞTIRMA TABLOSU${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "${BLUE}Format          | Boyut          | Restore Tipi${NC}"
echo -e "------------------------------------------------------"

if [ -f "$BACKUP_FILE_CUSTOM" ]; then
    SIZE=$(stat -f%z "$BACKUP_FILE_CUSTOM" 2>/dev/null)
    echo -e "Custom (.dump)  | $(format_size $SIZE)  | pg_restore"
fi
if [ -f "$BACKUP_FILE_SQL" ]; then
    SIZE=$(stat -f%z "$BACKUP_FILE_SQL" 2>/dev/null)
    echo -e "Plain SQL       | $(format_size $SIZE)  | psql"
fi
if [ -f "$BACKUP_FILE_GZIP" ]; then
    SIZE=$(stat -f%z "$BACKUP_FILE_GZIP" 2>/dev/null)
    echo -e "Compressed SQL  | $(format_size $SIZE)  | gunzip + psql"
fi
if [ -f "$BACKUP_FILE_TAR" ]; then
    SIZE=$(stat -f%z "$BACKUP_FILE_TAR" 2>/dev/null)
    echo -e "Tar             | $(format_size $SIZE)  | pg_restore"
fi

echo ""
echo -e "${GREEN}Tüm yedekleme işlemleri tamamlandı!${NC}"
echo -e "Log dosyası: $LOG_DIR/tam_yedekleme_${TIMESTAMP}.log"
echo -e "Yedek dizini: $BACKUP_DIR/full/"
