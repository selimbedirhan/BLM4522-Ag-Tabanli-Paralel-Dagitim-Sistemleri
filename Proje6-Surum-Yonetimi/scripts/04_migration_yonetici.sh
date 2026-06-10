#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="kutuphane_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

MIGRATION_DIR="$PROJECT_DIR/migrations"
ROLLBACK_DIR="$PROJECT_DIR/rollback"
LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/migration_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   MIGRATION YONETICI${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

CURRENT_VER=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT version_no FROM schema_version WHERE durum='basarili' ORDER BY version_id DESC LIMIT 1;
" 2>/dev/null)
echo -e "\n  Mevcut surum: ${BLUE}${CURRENT_VER:-1.0.0}${NC}"

run_migration_v2() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  YUKSELTME: v1.0.0 -> v2.0.0${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    log "MIGRATION BASLADI: v1.0.0 -> v2.0.0"
    
    echo -e "\n  ${BLUE}Degisiklikler:${NC}"
    echo -e "    + Yayinevleri tablosu"
    echo -e "    + Kitap-Yazar coka-cok tablosu"
    echo -e "    + Ceza sistemi tablosu"
    echo -e "    + Rezervasyon tablosu"
    echo -e "    + kitaplar: yayinevi_id, dil, aciklama, etiketler"
    echo -e "    + uyeler: uyelik_tipi, dogum_tarihi, max_odunc"
    echo -e "    + 2 yeni view, 1 yeni fonksiyon"
    
    START=$(date +%s)
    psql -U "$DB_USER" -d postgres -f "$MIGRATION_DIR/v1_to_v2_migration.sql" >> "$LOG_FILE" 2>&1
    RESULT=$?
    END=$(date +%s)
    DURATION=$((END - START))
    
    if [ $RESULT -eq 0 ]; then
        log "BASARILI: v2.0.0 ($DURATION sn)"
        echo -e "\n  ${GREEN}Migration basarili!${NC} (${DURATION}sn)"
        
        psql -U "$DB_USER" -d "$DB_NAME" -c "
            UPDATE schema_version SET sure_ms = ${DURATION}000 WHERE version_no = '2.0.0';
        " > /dev/null 2>&1
    else
        log "BASARISIZ: v2.0.0 (exit: $RESULT)"
        echo -e "\n  ${RED}Migration BASARISIZ!${NC} Log: $(basename $LOG_FILE)"
        return 1
    fi
}

run_migration_v3() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  YUKSELTME: v2.0.0 -> v3.0.0${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    log "MIGRATION BASLADI: v2.0.0 -> v3.0.0"
    
    echo -e "\n  ${BLUE}Degisiklikler:${NC}"
    echo -e "    + Dijital kitaplar tablosu"
    echo -e "    + Etkinlikler tablosu"
    echo -e "    + Etkinlik katilim tablosu"
    echo -e "    + Degerlendirmeler tablosu"
    echo -e "    + Bildirimler tablosu"
    echo -e "    + kitaplar: ort_puan, degerlendirme_sayisi, dijital_mevcut"
    echo -e "    + uyeler: toplam_odunc, gecikme_sayisi, puan"
    echo -e "    + 2 view, 1 trigger, performans indeksleri"
    
    START=$(date +%s)
    psql -U "$DB_USER" -d postgres -f "$MIGRATION_DIR/v2_to_v3_migration.sql" >> "$LOG_FILE" 2>&1
    RESULT=$?
    END=$(date +%s)
    DURATION=$((END - START))
    
    if [ $RESULT -eq 0 ]; then
        log "BASARILI: v3.0.0 ($DURATION sn)"
        echo -e "\n  ${GREEN}Migration basarili!${NC} (${DURATION}sn)"
        psql -U "$DB_USER" -d "$DB_NAME" -c "
            UPDATE schema_version SET sure_ms = ${DURATION}000 WHERE version_no = '3.0.0';
        " > /dev/null 2>&1
    else
        log "BASARISIZ: v3.0.0"
        echo -e "\n  ${RED}Migration BASARISIZ!${NC}"
        return 1
    fi
}

run_rollback_v2() {
    echo -e "\n${YELLOW}Rollback: v2.0 -> v1.0${NC}"
    log "ROLLBACK: v2.0 -> v1.0"
    psql -U "$DB_USER" -d postgres -f "$ROLLBACK_DIR/v2_to_v1_rollback.sql" >> "$LOG_FILE" 2>&1
    [ $? -eq 0 ] && echo -e "  ${GREEN}Rollback basarili${NC}" || echo -e "  ${RED}Rollback basarisiz${NC}"
}

run_rollback_v3() {
    echo -e "\n${YELLOW}Rollback: v3.0 -> v2.0${NC}"
    log "ROLLBACK: v3.0 -> v2.0"
    psql -U "$DB_USER" -d postgres -f "$ROLLBACK_DIR/v3_to_v2_rollback.sql" >> "$LOG_FILE" 2>&1
    [ $? -eq 0 ] && echo -e "  ${GREEN}Rollback basarili${NC}" || echo -e "  ${RED}Rollback basarisiz${NC}"
}

if [ "$CURRENT_VER" = "1.0.0" ] || [ -z "$CURRENT_VER" ]; then
    run_migration_v2
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}v2 migration basarisiz! Durduruluyor.${NC}"
        exit 1
    fi
fi

CURRENT_VER=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT version_no FROM schema_version WHERE durum='basarili' ORDER BY version_id DESC LIMIT 1;
" 2>/dev/null)

if [ "$CURRENT_VER" = "2.0.0" ]; then
    run_migration_v3
fi

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   SURUM GECMISI${NC}"
echo -e "${CYAN}============================================${NC}"

psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT version_no AS surum, LEFT(aciklama,50) AS aciklama,
           TO_CHAR(uygulama_tarihi,'YYYY-MM-DD HH24:MI') AS tarih,
           COALESCE(sure_ms||'ms', '-') AS sure, durum
    FROM schema_version ORDER BY version_id;
" 2>/dev/null

FINAL_VER=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT version_no FROM schema_version WHERE durum='basarili' ORDER BY version_id DESC LIMIT 1;
" 2>/dev/null)
echo -e "\n  Son surum: ${GREEN}$FINAL_VER${NC}"
echo -e "  Log: $(basename $LOG_FILE)"
echo -e "\n${GREEN}Migration islemleri tamamlandi!${NC}"
