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
LOG_FILE="$LOG_DIR/yedekleme_${TIMESTAMP}.log"

mkdir -p "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly" "$LOG_DIR"

log() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $1" | tee -a "$LOG_FILE"
}

format_size() {
    local s=$1
    if [ "$s" -gt 1048576 ] 2>/dev/null; then echo "$(echo "scale=2;$s/1048576" | bc)MB"
    elif [ "$s" -gt 1024 ] 2>/dev/null; then echo "$(echo "scale=2;$s/1024" | bc)KB"
    else echo "${s}B"; fi
}

log_to_db() {
    local tip=$1 dosya=$2 boyut=$3 sure=$4 durum=$5 hata=$6
    local db_boyut=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_database_size('$DB_NAME');" 2>/dev/null)
    psql -U "$DB_USER" -d "$DB_NAME" -c "
        INSERT INTO yedekleme_log (yedek_tipi, dosya_adi, dosya_boyutu, sure_saniye, durum, hata_mesaji, veritabani_boyutu)
        VALUES ('$tip','$(basename "$dosya")',$boyut,$sure,'$durum',$([ -n "$hata" ] && echo "'$hata'" || echo "NULL"),$db_boyut);
    " >> "$LOG_FILE" 2>&1
}

notify() {
    local title=$1 msg=$2
    osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   OTOMATIK YEDEKLEME SISTEMI${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

if ! pg_isready -q 2>/dev/null; then
    log "HATA: PostgreSQL erisilemez!"
    notify "Yedekleme HATA" "PostgreSQL sunucusu erisilemez!"
    exit 1
fi

log "====== OTOMATIK YEDEKLEME BASLADI ======"
log "Veritabani: $DB_NAME"

DAY_OF_WEEK=$(date +%u)  # 1=Pazartesi, 7=Pazar
DAY_OF_MONTH=$(date +%d)

if [ "$DAY_OF_MONTH" = "01" ]; then
    BACKUP_TYPE="monthly"
    BACKUP_SUBDIR="monthly"
    log "Yedek tipi: AYLIK (ayin ilk gunu)"
elif [ "$DAY_OF_WEEK" = "7" ]; then
    BACKUP_TYPE="weekly"
    BACKUP_SUBDIR="weekly"
    log "Yedek tipi: HAFTALIK (Pazar)"
else
    BACKUP_TYPE="daily"
    BACKUP_SUBDIR="daily"
    log "Yedek tipi: GUNLUK"
fi

echo -e "\n${YELLOW}[1/3] Custom Format Yedekleme${NC}"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_SUBDIR/${BACKUP_PREFIX:-hastane_db}_${BACKUP_TYPE}_${TIMESTAMP}.dump"

START=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z "${BACKUP_COMPRESSION:-6}" \
    --verbose --file="$BACKUP_FILE" 2>> "$LOG_FILE"
RESULT=$?
END=$(date +%s)
DURATION=$((END - START))

if [ $RESULT -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    FSIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || echo "0")
    log "BASARILI: Yedek alindi - $(format_size $FSIZE) ($DURATION sn)"
    echo -e "  ${GREEN}Basarili${NC}: $(basename $BACKUP_FILE) ($(format_size $FSIZE), ${DURATION}sn)"
    log_to_db "$BACKUP_TYPE" "$BACKUP_FILE" "$FSIZE" "$DURATION" "basarili" ""
    
    if [ "${VERIFY_AFTER_BACKUP}" = "true" ]; then
        echo -e "\n${YELLOW}[2/3] Yedek Dogrulama${NC}"
        pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log "DOGRULAMA: Yedek dosyasi gecerli"
            echo -e "  ${GREEN}Dogrulandi${NC}: Yedek dosyasi gecerli"
            
            psql -U "$DB_USER" -d "$DB_NAME" -c "
                UPDATE yedekleme_log SET dogrulama_durumu = TRUE, dogrulama_tarihi = CURRENT_TIMESTAMP
                WHERE dosya_adi = '$(basename "$BACKUP_FILE")';
            " >> "$LOG_FILE" 2>&1
        else
            log "UYARI: Yedek dogrulama basarisiz!"
            echo -e "  ${RED}Basarisiz${NC}: Yedek dogrulanamadi"
            notify "Yedek Uyari" "Yedek dogrulama basarisiz: $(basename $BACKUP_FILE)"
        fi
    fi
    
    notify "Yedekleme OK" "${BACKUP_TYPE} yedek alindi: $(format_size $FSIZE)"
else
    FSIZE=0
    log "HATA: Yedekleme BASARISIZ! (exit: $RESULT)"
    echo -e "  ${RED}BASARISIZ${NC}: Yedekleme hatasi (kod: $RESULT)"
    log_to_db "$BACKUP_TYPE" "$BACKUP_FILE" "0" "$DURATION" "basarisiz" "pg_dump exit code: $RESULT"
    notify "Yedekleme HATA" "${BACKUP_TYPE} yedekleme basarisiz!"
fi

echo -e "\n${YELLOW}[3/3] SQL Format Yedekleme (Arsiv)${NC}"
SQL_FILE="$BACKUP_DIR/$BACKUP_SUBDIR/${BACKUP_PREFIX:-hastane_db}_${BACKUP_TYPE}_${TIMESTAMP}.sql.gz"

START2=$(date +%s)
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fp --create --clean 2>> "$LOG_FILE" | gzip -9 > "$SQL_FILE"
RESULT2=${PIPESTATUS[0]}
END2=$(date +%s)
DURATION2=$((END2 - START2))

if [ $RESULT2 -eq 0 ] && [ -f "$SQL_FILE" ]; then
    FSIZE2=$(stat -f%z "$SQL_FILE" 2>/dev/null || echo "0")
    log "BASARILI: SQL arsiv alindi - $(format_size $FSIZE2) ($DURATION2 sn)"
    echo -e "  ${GREEN}Basarili${NC}: $(basename $SQL_FILE) ($(format_size $FSIZE2), ${DURATION2}sn)"
    log_to_db "${BACKUP_TYPE}_sql" "$SQL_FILE" "$FSIZE2" "$DURATION2" "basarili" ""
else
    log "HATA: SQL arsiv BASARISIZ!"
    echo -e "  ${RED}BASARISIZ${NC}: SQL arsiv hatasi"
fi

if [ "${ALERT_ON_SIZE_ANOMALY}" = "true" ] && [ $FSIZE -gt 0 ]; then
    PREV_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT dosya_boyutu FROM yedekleme_log
        WHERE durum = 'basarili' AND yedek_tipi = '$BACKUP_TYPE'
        ORDER BY yedek_tarihi DESC OFFSET 1 LIMIT 1;
    " 2>/dev/null)
    
    if [ -n "$PREV_SIZE" ] && [ "$PREV_SIZE" -gt 0 ] 2>/dev/null; then
        DIFF_PCT=$(echo "scale=0; ($FSIZE - $PREV_SIZE) * 100 / $PREV_SIZE" | bc 2>/dev/null)
        THRESHOLD="${ALERT_SIZE_THRESHOLD_PERCENT:-50}"
        
        if [ -n "$DIFF_PCT" ]; then
            if [ "$DIFF_PCT" -gt "$THRESHOLD" ] || [ "$DIFF_PCT" -lt "-$THRESHOLD" ]; then
                log "UYARI: Boyut anomalisi! Degisim: %$DIFF_PCT (esik: %$THRESHOLD)"
                echo -e "  ${YELLOW}UYARI${NC}: Boyut anomalisi - onceki: $(format_size $PREV_SIZE), simdi: $(format_size $FSIZE) (%$DIFF_PCT)"
                notify "Boyut Uyari" "Yedek boyutu %$DIFF_PCT degisti!"
                
                psql -U "$DB_USER" -d "$DB_NAME" -c "
                    INSERT INTO yedekleme_log (yedek_tipi, dosya_adi, durum, hata_mesaji)
                    VALUES ('anomali_uyari', '$(basename "$BACKUP_FILE")', 'uyari', 
                            'Boyut degisimi: %$DIFF_PCT (onceki: $PREV_SIZE, simdi: $FSIZE)');
                " >> "$LOG_FILE" 2>&1
            fi
        fi
    fi
fi

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEKLEME OZETI${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Tip: ${BLUE}$BACKUP_TYPE${NC}"
echo -e "  Custom: $(basename $BACKUP_FILE) ($(format_size $FSIZE))"
echo -e "  SQL.gz: $(basename $SQL_FILE) ($(format_size $FSIZE2))"
echo -e "  Sure: ${DURATION}sn + ${DURATION2}sn"
echo -e "  Log: $(basename $LOG_FILE)"

echo -e "\n  ${BLUE}Son 5 yedekleme kaydi:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT log_id, yedek_tipi AS tip,
           TO_CHAR(yedek_tarihi, 'MM-DD HH24:MI') AS tarih,
           pg_size_pretty(dosya_boyutu) AS boyut,
           sure_saniye || 'sn' AS sure, durum
    FROM yedekleme_log ORDER BY log_id DESC LIMIT 5;
" 2>/dev/null

log "====== OTOMATIK YEDEKLEME TAMAMLANDI ======"
echo -e "\n${GREEN}Otomatik yedekleme tamamlandi!${NC}"
