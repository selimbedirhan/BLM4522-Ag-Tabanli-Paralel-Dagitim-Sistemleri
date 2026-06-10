#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config/yedekleme_ayar.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
REPORT_DIR="$PROJECT_DIR/reports"
export PATH="${PG_BIN:-/opt/homebrew/opt/postgresql@14/bin}:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

setup_dirs() {
    mkdir -p "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
}

log_msg() {
    local level=$1 msg=$2
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/otomasyon_$(date +%Y%m%d).log"
    echo "[$ts] [$level] $msg" >> "$log_file"
    case "$level" in
        INFO)   echo -e "  ${GREEN}[INFO]${NC} $msg" ;;
        WARN)   echo -e "  ${YELLOW}[WARN]${NC} $msg" ;;
        ERROR)  echo -e "  ${RED}[HATA]${NC} $msg" ;;
        OK)     echo -e "  ${GREEN}[OK]${NC} $msg" ;;
    esac
}

format_size() {
    local s=$1
    if [ -z "$s" ] || [ "$s" = "0" ]; then echo "0B"
    elif [ "$s" -gt 1073741824 ]; then echo "$(echo "scale=2;$s/1073741824" | bc)GB"
    elif [ "$s" -gt 1048576 ]; then echo "$(echo "scale=2;$s/1048576" | bc)MB"
    elif [ "$s" -gt 1024 ]; then echo "$(echo "scale=2;$s/1024" | bc)KB"
    else echo "${s}B"; fi
}

check_db() {
    if ! pg_isready -q 2>/dev/null; then
        log_msg ERROR "PostgreSQL sunucusu erisilemez!"
        return 1
    fi
    if ! psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        log_msg ERROR "$DB_NAME veritabanina baglanilmadi!"
        return 1
    fi
    return 0
}

log_backup_to_db() {
    local tip=$1 dosya=$2 boyut=$3 sure=$4 durum=$5 hata=$6
    local db_boyut=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
        "SELECT pg_database_size('$DB_NAME');" 2>/dev/null)
    psql -U "$DB_USER" -d "$DB_NAME" -c "
        INSERT INTO yedekleme_log (yedek_tipi, dosya_adi, dosya_boyutu, sure_saniye, durum, hata_mesaji, veritabani_boyutu)
        VALUES ('$tip', '$(basename "$dosya")', $boyut, $sure, '$durum', $([ -n "$hata" ] && echo "'$hata'" || echo "NULL"), $db_boyut);
    " 2>/dev/null
}

send_notification() {
    local title=$1 msg=$2
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   OTOMASYON ALTYAPI KURULUMU${NC}"
echo -e "${CYAN}============================================${NC}"

setup_dirs
log_msg INFO "Dizinler olusturuldu"

if check_db; then
    log_msg OK "PostgreSQL baglantisi basarili ($DB_NAME)"
else
    log_msg ERROR "Veritabani baglantisi basarisiz!"
    exit 1
fi

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
log_msg INFO "Veritabani boyutu: $DB_SIZE"

TBL_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>/dev/null)
log_msg INFO "Tablo sayisi: $TBL_COUNT"

if [ -f "$CONFIG_FILE" ]; then
    log_msg OK "Ayar dosyasi yuklendi: $(basename $CONFIG_FILE)"
    echo -e "\n  ${BLUE}Aktif Ayarlar:${NC}"
    echo -e "    Veritabani: $DB_NAME"
    echo -e "    Yedek formati: $BACKUP_FORMAT"
    echo -e "    Sikistirma: $BACKUP_COMPRESSION"
    echo -e "    Saklama (gunluk): $RETENTION_DAILY_DAYS gun"
    echo -e "    Dogrulama: $VERIFY_AFTER_BACKUP"
    echo -e "    Uyari: $ALERT_ENABLED"
else
    log_msg WARN "Ayar dosyasi bulunamadi, varsayilan degerler kullanilacak"
fi

echo -e "\n${GREEN}Otomasyon altyapisi hazir!${NC}"
