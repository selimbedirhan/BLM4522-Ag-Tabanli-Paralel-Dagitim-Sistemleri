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
ROTATION_LOG="$LOG_DIR/rotasyon_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$ROTATION_LOG"; }

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEK ROTASYON SISTEMI${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

log "====== ROTASYON BASLADI ======"

echo -e "\n${YELLOW}[1/4] Mevcut Durum${NC}"

before_daily=$(find "$BACKUP_DIR/daily" -type f 2>/dev/null | wc -l | tr -d ' ')
before_weekly=$(find "$BACKUP_DIR/weekly" -type f 2>/dev/null | wc -l | tr -d ' ')
before_monthly=$(find "$BACKUP_DIR/monthly" -type f 2>/dev/null | wc -l | tr -d ' ')
before_total=$((before_daily + before_weekly + before_monthly))
before_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')

echo -e "  Gunluk: ${BLUE}$before_daily${NC} dosya"
echo -e "  Haftalik: ${BLUE}$before_weekly${NC} dosya"
echo -e "  Aylik: ${BLUE}$before_monthly${NC} dosya"
echo -e "  Toplam: ${BLUE}$before_total${NC} dosya ($before_size)"

log "Onceki durum: Gunluk=$before_daily, Haftalik=$before_weekly, Aylik=$before_monthly"

echo -e "\n${YELLOW}[2/4] Gunluk Yedek Temizligi (${RETENTION_DAILY_DAYS:-7} gunden eski)${NC}"

DELETED_DAILY=0
while IFS= read -r f; do
    if [ -f "$f" ]; then
        FNAME=$(basename "$f")
        FSIZE=$(stat -f%z "$f" 2>/dev/null || echo "0")
        log "SILINDI [gunluk]: $FNAME ($FSIZE bytes)"
        rm -f "$f"
        DELETED_DAILY=$((DELETED_DAILY + 1))
    fi
done < <(find "$BACKUP_DIR/daily" -type f -mtime +${RETENTION_DAILY_DAYS:-7} 2>/dev/null)

if [ $DELETED_DAILY -gt 0 ]; then
    echo -e "  ${GREEN}$DELETED_DAILY${NC} gunluk yedek silindi"
else
    echo -e "  Silinecek eski gunluk yedek yok"
fi

echo -e "\n${YELLOW}[3/4] Haftalik Yedek Temizligi (${RETENTION_WEEKLY_WEEKS:-4} haftadan eski)${NC}"

WEEKLY_DAYS=$(( ${RETENTION_WEEKLY_WEEKS:-4} * 7 ))
DELETED_WEEKLY=0

while IFS= read -r f; do
    if [ -f "$f" ]; then
        FNAME=$(basename "$f")
        log "SILINDI [haftalik]: $FNAME"
        rm -f "$f"
        DELETED_WEEKLY=$((DELETED_WEEKLY + 1))
    fi
done < <(find "$BACKUP_DIR/weekly" -type f -mtime +$WEEKLY_DAYS 2>/dev/null)

if [ $DELETED_WEEKLY -gt 0 ]; then
    echo -e "  ${GREEN}$DELETED_WEEKLY${NC} haftalik yedek silindi"
else
    echo -e "  Silinecek eski haftalik yedek yok"
fi

echo -e "\n${YELLOW}[4/4] Aylik Yedek + Toplam Limit Kontrolu${NC}"

MONTHLY_DAYS=$(( ${RETENTION_MONTHLY_MONTHS:-6} * 30 ))
DELETED_MONTHLY=0

while IFS= read -r f; do
    if [ -f "$f" ]; then
        FNAME=$(basename "$f")
        log "SILINDI [aylik]: $FNAME"
        rm -f "$f"
        DELETED_MONTHLY=$((DELETED_MONTHLY + 1))
    fi
done < <(find "$BACKUP_DIR/monthly" -type f -mtime +$MONTHLY_DAYS 2>/dev/null)

if [ $DELETED_MONTHLY -gt 0 ]; then
    echo -e "  ${GREEN}$DELETED_MONTHLY${NC} aylik yedek silindi"
else
    echo -e "  Silinecek eski aylik yedek yok"
fi

CURRENT_TOTAL=$(find "$BACKUP_DIR" -type f \( -name "*.dump" -o -name "*.sql.gz" \) 2>/dev/null | wc -l | tr -d ' ')
MAX=${MAX_BACKUP_COUNT:-50}
DELETED_EXCESS=0

if [ "$CURRENT_TOTAL" -gt "$MAX" ]; then
    EXCESS=$((CURRENT_TOTAL - MAX))
    echo -e "  ${YELLOW}Limit asimi${NC}: $CURRENT_TOTAL dosya (max: $MAX), $EXCESS dosya silinecek"
    
    find "$BACKUP_DIR" -type f \( -name "*.dump" -o -name "*.sql.gz" \) -printf '%T@ %p\n' 2>/dev/null | \
        sort -n | head -$EXCESS | awk '{print $2}' | while read f; do
        log "SILINDI [limit]: $(basename "$f")"
        rm -f "$f"
        DELETED_EXCESS=$((DELETED_EXCESS + 1))
    done
fi

DELETED_LOGS=0
while IFS= read -r f; do
    rm -f "$f"
    DELETED_LOGS=$((DELETED_LOGS + 1))
done < <(find "$LOG_DIR" -type f -name "*.log" -mtime +30 2>/dev/null)
[ $DELETED_LOGS -gt 0 ] && echo -e "  $DELETED_LOGS eski log dosyasi temizlendi"

after_total=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
after_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
TOTAL_DELETED=$((DELETED_DAILY + DELETED_WEEKLY + DELETED_MONTHLY + DELETED_EXCESS))

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   ROTASYON OZETI${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Silinen: Gunluk=$DELETED_DAILY, Haftalik=$DELETED_WEEKLY, Aylik=$DELETED_MONTHLY"
echo -e "  Toplam silinen: ${BLUE}$TOTAL_DELETED${NC} dosya"
echo -e "  Onceki: $before_total dosya ($before_size)"
echo -e "  Sonraki: $after_total dosya ($after_size)"
echo -e "  Log: $(basename $ROTATION_LOG)"

log "TAMAMLANDI: $TOTAL_DELETED dosya silindi"
echo -e "\n${GREEN}Rotasyon tamamlandi!${NC}"
