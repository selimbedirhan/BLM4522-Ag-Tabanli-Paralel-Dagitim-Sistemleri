#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_NAME="eticaret_db"
DB_USER=$(whoami)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
RETENTION_DAYS=7  # Yedekleri kaç gün tutacağız

export PATH="$PG_BIN:$PATH"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   ZAMANLANMIŞ YEDEKLEME SİSTEMİ${NC}"
echo -e "${CYAN}   Cron Zamanlayıcı Kurulumu${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}[1/4] Otomatik Yedekleme Scripti Oluşturma${NC}"

AUTO_BACKUP_SCRIPT="$SCRIPTS_DIR/auto_backup.sh"
cat > "$AUTO_BACKUP_SCRIPT" << 'SCRIPT_EOF'
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
SCRIPT_EOF

chmod +x "$AUTO_BACKUP_SCRIPT"
echo -e "${GREEN}  ✓ Otomatik yedekleme scripti oluşturuldu${NC}"
echo -e "    Dosya: $AUTO_BACKUP_SCRIPT"

echo -e "\n${YELLOW}[2/4] Cron Job Tanımları${NC}"

CRON_FILE="$PROJECT_DIR/config/crontab_yedekleme.txt"
cat > "$CRON_FILE" << EOF

PATH=/opt/homebrew/opt/postgresql@14/bin:/usr/local/bin:/usr/bin:/bin
SHELL=/bin/bash

0 2 * * * $AUTO_BACKUP_SCRIPT >> $LOG_DIR/cron_output.log 2>&1

0 3 * * 0 $SCRIPTS_DIR/03_tam_yedekleme.sh >> $LOG_DIR/cron_output.log 2>&1

0 9-18 * * 1-5 $SCRIPTS_DIR/04_fark_yedekleme.sh >> $LOG_DIR/cron_output.log 2>&1

EOF

echo -e "${GREEN}  ✓ Cron tanımları dosyası oluşturuldu${NC}"
echo -e "    Dosya: $CRON_FILE"
echo -e "\n  ${BLUE}Tanımlanan zamanlayıcılar:${NC}"
echo -e "    🕐 Günlük tam yedek    : Her gün 02:00"
echo -e "    🕐 Haftalık tam yedek  : Her Pazar 03:00"
echo -e "    🕐 Saatlik fark yedek  : Hafta içi 09:00-18:00"

echo -e "\n${YELLOW}[3/4] Otomatik Yedekleme Testi${NC}"
echo -e "  ${BLUE}Auto backup scripti test ediliyor...${NC}"

bash "$AUTO_BACKUP_SCRIPT"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}  ✓ Otomatik yedekleme testi başarılı${NC}"
    LATEST_LOG=$(ls -t "$LOG_DIR"/auto_backup_*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo -e "\n  ${BLUE}Son yedekleme logu:${NC}"
        cat "$LATEST_LOG" | while read line; do
            echo -e "    $line"
        done
    fi
else
    echo -e "${RED}  ✗ Otomatik yedekleme testi BAŞARISIZ!${NC}"
fi

echo -e "\n${YELLOW}[4/4] Cron Kurulum Talimatları${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Cron zamanlayıcıyı kurmak için:"
echo -e ""
echo -e "  ${BLUE}1. Mevcut cron'ları görüntüle:${NC}"
echo -e "     crontab -l"
echo -e ""
echo -e "  ${BLUE}2. Yedekleme cron'unu kur:${NC}"
echo -e "     crontab $CRON_FILE"
echo -e ""
echo -e "  ${BLUE}3. Kurulumu doğrula:${NC}"
echo -e "     crontab -l"
echo -e ""
echo -e "  ${BLUE}4. Cron servis durumu:${NC}"
echo -e "     sudo launchctl list | grep cron"
echo -e ""
echo -e "  ${YELLOW}NOT: macOS'ta cron için 'Full Disk Access' izni${NC}"
echo -e "  ${YELLOW}gerekebilir (Sistem Ayarları > Gizlilik > Tam Disk Erişimi)${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "\n${GREEN}Zamanlayıcı kurulumu tamamlandı!${NC}"
