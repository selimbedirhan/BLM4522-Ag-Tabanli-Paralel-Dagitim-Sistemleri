#!/bin/bash

DB_NAME="eticaret_db"
DB_USER=$(whoami)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups/auto"
LOG_DIR="$PROJECT_DIR/logs"
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/auto_backup_${TIMESTAMP}.log"

export PATH="$PG_BIN:$PATH"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "====== OTOMATİK YEDEKLEME BAŞLADI ======"
log "Veritabanı: $DB_NAME"

if ! pg_isready -q; then
    log "HATA: PostgreSQL sunucusu erişilemez!"
    exit 1
fi

if ! psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    log "HATA: $DB_NAME veritabanına bağlanılamadı!"
    exit 1
fi

BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_auto_${TIMESTAMP}.dump"
log "Yedekleme başlıyor: $BACKUP_FILE"

START_TIME=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z 6 \
    --file="$BACKUP_FILE" 2>> "$LOG_FILE"

RESULT=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $RESULT -eq 0 ]; then
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat --printf="%s" "$BACKUP_FILE" 2>/dev/null)
    FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE/1048576" | bc)
    log "BAŞARILI: Yedekleme tamamlandı"
    log "  Boyut: ${FILE_SIZE_MB} MB"
    log "  Süre: ${DURATION} saniye"
    
    pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "DOĞRULAMA: Yedek dosyası geçerli ✓"
    else
        log "UYARI: Yedek dosyası doğrulanamadı!"
    fi
else
    log "HATA: Yedekleme BAŞARISIZ! (exit code: $RESULT)"
    rm -f "$BACKUP_FILE"
fi

log "Eski yedekler temizleniyor ($RETENTION_DAYS günden eski)..."
DELETED_COUNT=0
find "$BACKUP_DIR" -name "*.dump" -mtime +$RETENTION_DAYS -type f | while read file; do
    rm -f "$file"
    log "  Silindi: $(basename $file)"
    DELETED_COUNT=$((DELETED_COUNT + 1))
done

find "$LOG_DIR" -name "auto_backup_*.log" -mtime +30 -type f -delete

BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.dump" -type f | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
log "Toplam yedek sayısı: $BACKUP_COUNT | Toplam boyut: $TOTAL_SIZE"

log "====== OTOMATİK YEDEKLEME TAMAMLANDI ======"
