#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_DIR/config/yedekleme_ayar.conf" 2>/dev/null

LOG_DIR="$PROJECT_DIR/logs"
export PATH="${PG_BIN:-/opt/homebrew/opt/postgresql@14/bin}:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ALERT_LOG="$LOG_DIR/uyari_gecmisi.log"

mkdir -p "$LOG_DIR"

alert_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$ALERT_LOG"
}

notify_macos() {
    local title=$1 msg=$2 level=$3
    local sound="default"
    [ "$level" = "KRITIK" ] && sound="Basso"
    osascript -e "display notification \"$msg\" with title \"$title\" sound name \"$sound\"" 2>/dev/null
}

show_alert() {
    local level=$1 msg=$2
    case "$level" in
        KRITIK) echo -e "  ${RED}[KRITIK]${NC} $msg" ;;
        UYARI)  echo -e "  ${YELLOW}[UYARI]${NC} $msg" ;;
        BILGI)  echo -e "  ${GREEN}[BILGI]${NC} $msg" ;;
    esac
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEKLEME UYARI SISTEMI${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

ALERT_COUNT=0

echo -e "\n${YELLOW}[1/5] Son Basarili Yedek Kontrolu${NC}"

SON_BASARILI=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(yedek_tarihi)))::INTEGER
    FROM yedekleme_log WHERE durum = 'basarili';
" 2>/dev/null)

if [ -z "$SON_BASARILI" ] || [ "$SON_BASARILI" = "" ]; then
    show_alert "KRITIK" "Hic basarili yedek bulunamadi!"
    notify_macos "KRITIK UYARI" "Hic basarili yedek bulunamadi!" "KRITIK"
    alert_log "KRITIK" "Hic basarili yedek bulunamadi"
    ALERT_COUNT=$((ALERT_COUNT + 1))
elif [ "$SON_BASARILI" -gt 86400 ]; then
    SAAT=$((SON_BASARILI / 3600))
    show_alert "UYARI" "Son basarili yedek $SAAT saat once alinmis!"
    notify_macos "Yedek Gecikmesi" "Son basarili yedek $SAAT saat once!" "UYARI"
    alert_log "UYARI" "Son basarili yedek $SAAT saat once"
    ALERT_COUNT=$((ALERT_COUNT + 1))
else
    DAKIKA=$((SON_BASARILI / 60))
    show_alert "BILGI" "Son basarili yedek $DAKIKA dk once alinmis - Normal"
fi

echo -e "\n${YELLOW}[2/5] Basarisiz Yedek Kontrolu${NC}"

BASARISIZ=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM yedekleme_log
    WHERE durum = 'basarisiz' AND yedek_tarihi >= CURRENT_TIMESTAMP - INTERVAL '24 hours';
" 2>/dev/null)

if [ "$BASARISIZ" -gt 0 ] 2>/dev/null; then
    show_alert "KRITIK" "Son 24 saatte $BASARISIZ basarisiz yedekleme!"
    notify_macos "BASARISIZ YEDEK" "$BASARISIZ yedekleme basarisiz oldu!" "KRITIK"
    alert_log "KRITIK" "Son 24 saatte $BASARISIZ basarisiz yedek"
    ALERT_COUNT=$((ALERT_COUNT + 1))
    
    echo -e "  ${BLUE}Hata detaylari:${NC}"
    psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT TO_CHAR(yedek_tarihi,'HH24:MI') AS saat, yedek_tipi AS tip,
               COALESCE(LEFT(hata_mesaji,60),'Bilinmiyor') AS hata
        FROM yedekleme_log WHERE durum='basarisiz'
        AND yedek_tarihi >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
        ORDER BY yedek_tarihi DESC;
    " 2>/dev/null
else
    show_alert "BILGI" "Son 24 saatte basarisiz yedek yok - Normal"
fi

echo -e "\n${YELLOW}[3/5] Boyut Anomali Kontrolu${NC}"

ANOMALI=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM yedekleme_log
    WHERE durum = 'uyari' AND yedek_tarihi >= CURRENT_TIMESTAMP - INTERVAL '24 hours';
" 2>/dev/null)

if [ "$ANOMALI" -gt 0 ] 2>/dev/null; then
    show_alert "UYARI" "$ANOMALI boyut anomalisi tespit edildi!"
    alert_log "UYARI" "$ANOMALI boyut anomalisi"
    ALERT_COUNT=$((ALERT_COUNT + 1))
else
    show_alert "BILGI" "Boyut anomalisi yok - Normal"
fi

echo -e "\n${YELLOW}[4/5] Disk Alani Kontrolu${NC}"

DISK_USAGE=$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 90 ] 2>/dev/null; then
    show_alert "KRITIK" "Disk kullanimi %$DISK_USAGE - Kritik seviye!"
    notify_macos "DISK UYARI" "Disk kullanimi %$DISK_USAGE!" "KRITIK"
    alert_log "KRITIK" "Disk kullanimi %$DISK_USAGE"
    ALERT_COUNT=$((ALERT_COUNT + 1))
elif [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 80 ] 2>/dev/null; then
    show_alert "UYARI" "Disk kullanimi %$DISK_USAGE - Yuksek"
    alert_log "UYARI" "Disk kullanimi %$DISK_USAGE"
    ALERT_COUNT=$((ALERT_COUNT + 1))
else
    show_alert "BILGI" "Disk kullanimi %${DISK_USAGE:-0} - Normal"
fi

echo -e "\n${YELLOW}[5/5] PostgreSQL Durum Kontrolu${NC}"

if pg_isready -q 2>/dev/null; then
    CONN=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_stat_activity;" 2>/dev/null)
    MAX_CONN=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW max_connections;" 2>/dev/null)
    show_alert "BILGI" "PostgreSQL aktif - $CONN/$MAX_CONN baglanti"
else
    show_alert "KRITIK" "PostgreSQL sunucusu erisilemez!"
    notify_macos "DB KRITIK" "PostgreSQL sunucusu erisilemez!" "KRITIK"
    alert_log "KRITIK" "PostgreSQL erisilemez"
    ALERT_COUNT=$((ALERT_COUNT + 1))
fi

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   UYARI KONTROLU TAMAMLANDI${NC}"
echo -e "${CYAN}============================================${NC}"

if [ $ALERT_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}Tum kontroller basarili - Uyari yok${NC}"
    alert_log "BILGI" "Tum kontroller basarili"
else
    echo -e "  ${RED}$ALERT_COUNT uyari tespit edildi!${NC}"
fi

echo -e "  Uyari gecmisi: $(basename $ALERT_LOG)"
echo -e "\n  ${BLUE}Son 5 uyari:${NC}"
tail -5 "$ALERT_LOG" 2>/dev/null | while read line; do
    echo -e "    $line"
done

echo -e "\n${GREEN}Uyari sistemi kontrolu tamamlandi!${NC}"
