#!/bin/bash
# ============================================================================
# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Dosya: 04_fark_yedekleme.sh
# Açıklama: Fark (Differential) Yedekleme İşlemleri
# PostgreSQL'de fark yedekleme, şema/tablo bazlı kısmi yedekleme ve
# pg_dump ile belirli objelerin yedeklenmesi şeklinde uygulanır.
# ============================================================================

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Değişkenler
DB_NAME="eticaret_db"
DB_USER=$(whoami)
BACKUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/backups"
LOG_DIR="$(cd "$(dirname "$0")/.." && pwd)/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"

export PATH="$PG_BIN:$PATH"

mkdir -p "$BACKUP_DIR/differential" "$LOG_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   FARK (DIFFERENTIAL) YEDEKLEME İŞLEMLERİ${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

# Fonksiyon: Boyut formatla
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
# 1. Sadece Şema (DDL) Yedekleme
# Tablo yapıları, indeksler, trigger'lar, fonksiyonlar
# ============================================================================
echo -e "\n${YELLOW}[1/5] Sadece Şema (DDL) Yedekleme${NC}"
BACKUP_SCHEMA="$BACKUP_DIR/differential/${DB_NAME}_schema_only_${TIMESTAMP}.sql"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --schema-only \
    --create --clean --if-exists \
    --file="$BACKUP_SCHEMA" \
    2>> "$LOG_DIR/fark_yedekleme_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    FILE_SIZE=$(stat -f%z "$BACKUP_SCHEMA" 2>/dev/null || stat --printf="%s" "$BACKUP_SCHEMA" 2>/dev/null)
    echo -e "${GREEN}  ✓ Şema yedekleme başarılı${NC}"
    echo -e "    Dosya: $BACKUP_SCHEMA"
    echo -e "    Boyut: $(format_size $FILE_SIZE) | Süre: $((END_TIME - START_TIME))s"
else
    echo -e "${RED}  ✗ Şema yedekleme BAŞARISIZ!${NC}"
fi

# ============================================================================
# 2. Sadece Veri Yedekleme
# Tablo verileri (INSERT komutları olarak)
# ============================================================================
echo -e "\n${YELLOW}[2/5] Sadece Veri Yedekleme${NC}"
BACKUP_DATA="$BACKUP_DIR/differential/${DB_NAME}_data_only_${TIMESTAMP}.sql"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --data-only \
    --column-inserts \
    --file="$BACKUP_DATA" \
    2>> "$LOG_DIR/fark_yedekleme_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    FILE_SIZE=$(stat -f%z "$BACKUP_DATA" 2>/dev/null || stat --printf="%s" "$BACKUP_DATA" 2>/dev/null)
    echo -e "${GREEN}  ✓ Veri yedekleme başarılı${NC}"
    echo -e "    Dosya: $BACKUP_DATA"
    echo -e "    Boyut: $(format_size $FILE_SIZE) | Süre: $((END_TIME - START_TIME))s"
else
    echo -e "${RED}  ✗ Veri yedekleme BAŞARISIZ!${NC}"
fi

# ============================================================================
# 3. Tablo Bazlı Yedekleme (Belirli tablolar)
# Sadece değişen tabloların yedeği alınır
# ============================================================================
echo -e "\n${YELLOW}[3/5] Tablo Bazlı Kısmi Yedekleme${NC}"

# Yedeklenecek tablolar - en çok değişen tablolar
TABLES=("siparisler" "siparis_detaylari" "odemeler" "stok_hareketleri")

for TABLE in "${TABLES[@]}"; do
    BACKUP_TABLE="$BACKUP_DIR/differential/${DB_NAME}_table_${TABLE}_${TIMESTAMP}.sql"
    
    pg_dump -U "$DB_USER" -d "$DB_NAME" \
        --table="$TABLE" \
        --file="$BACKUP_TABLE" \
        2>> "$LOG_DIR/fark_yedekleme_${TIMESTAMP}.log"
    
    if [ $? -eq 0 ]; then
        FILE_SIZE=$(stat -f%z "$BACKUP_TABLE" 2>/dev/null || stat --printf="%s" "$BACKUP_TABLE" 2>/dev/null)
        ROW_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
        echo -e "${GREEN}  ✓ $TABLE tablosu yedeklendi${NC}"
        echo -e "    Kayıt: $ROW_COUNT | Boyut: $(format_size $FILE_SIZE)"
    else
        echo -e "${RED}  ✗ $TABLE tablosu yedekleme BAŞARISIZ!${NC}"
    fi
done

# ============================================================================
# 4. Son N Günde Değişen Verilerin Yedeklenmesi
# Koşullu veri yedekleme - tarih filtresiyle
# ============================================================================
echo -e "\n${YELLOW}[4/5] Son 7 Günde Değişen Verilerin Yedeği${NC}"
BACKUP_RECENT="$BACKUP_DIR/differential/${DB_NAME}_recent_changes_${TIMESTAMP}.sql"
DAYS_AGO=7

cat > "$BACKUP_RECENT" << EOSQL
-- ============================================================================
-- Son $DAYS_AGO Günde Değişen Verilerin Yedeği
-- Yedek Tarihi: $(date '+%Y-%m-%d %H:%M:%S')
-- ============================================================================

-- Son $DAYS_AGO günde eklenen siparişler
EOSQL

psql -U "$DB_USER" -d "$DB_NAME" -c "\COPY (SELECT * FROM siparisler WHERE siparis_tarihi >= CURRENT_TIMESTAMP - INTERVAL '$DAYS_AGO days') TO STDOUT WITH CSV HEADER" >> "$BACKUP_RECENT" 2>> "$LOG_DIR/fark_yedekleme_${TIMESTAMP}.log"

RECENT_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM siparisler WHERE siparis_tarihi >= CURRENT_TIMESTAMP - INTERVAL '$DAYS_AGO days';" 2>/dev/null)
echo -e "${GREEN}  ✓ Son $DAYS_AGO günde değişen $RECENT_COUNT sipariş yedeklendi${NC}"
echo -e "    Dosya: $BACKUP_RECENT"

# ============================================================================
# 5. Metadata ve İstatistik Bilgisi Kaydetme
# Bir sonraki fark yedekleme için referans noktası
# ============================================================================
echo -e "\n${YELLOW}[5/5] Yedekleme Metadata Kaydı${NC}"
METADATA_FILE="$BACKUP_DIR/differential/metadata_${TIMESTAMP}.json"

# Tablo istatistiklerini JSON olarak kaydet
psql -U "$DB_USER" -d "$DB_NAME" -t -A << EOSQL > "$METADATA_FILE"
SELECT json_build_object(
    'yedek_tarih', CURRENT_TIMESTAMP,
    'veritabani', '$DB_NAME',
    'yedek_tipi', 'differential',
    'tablolar', (
        SELECT json_agg(json_build_object(
            'tablo_adi', schemaname || '.' || relname,
            'kayit_sayisi', n_live_tup,
            'son_vacuum', last_autovacuum,
            'son_analyze', last_autoanalyze,
            'degisiklik_sayisi', n_tup_ins + n_tup_upd + n_tup_del
        ))
        FROM pg_stat_user_tables
    ),
    'veritabani_boyutu', pg_size_pretty(pg_database_size('$DB_NAME'))
);
EOSQL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Metadata kaydı başarılı${NC}"
    echo -e "    Dosya: $METADATA_FILE"
else
    echo -e "${RED}  ✗ Metadata kaydı BAŞARISIZ!${NC}"
fi

# ============================================================================
# ÖZET
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   FARK YEDEKLEME ÖZETİ${NC}"
echo -e "${CYAN}============================================${NC}"

TOTAL_SIZE=0
for f in "$BACKUP_DIR/differential/"*"$TIMESTAMP"*; do
    if [ -f "$f" ]; then
        SIZE=$(stat -f%z "$f" 2>/dev/null || stat --printf="%s" "$f" 2>/dev/null)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
done

echo -e "  Toplam dosya boyutu: $(format_size $TOTAL_SIZE)"
echo -e "  Yedek dizini: $BACKUP_DIR/differential/"
echo -e "  Log: $LOG_DIR/fark_yedekleme_${TIMESTAMP}.log"
echo -e "\n${GREEN}Fark yedekleme işlemleri tamamlandı!${NC}"
