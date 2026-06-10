#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_USER=$(whoami)
PRIMARY_DB="sosyal_medya_db"
REPLICA_DB="sosyal_medya_replica"
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$LOG_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   REPLIKASYON IZLEME RAPORU${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}[1/6] Replikasyon Genel Durumu${NC}"

echo -e "\n  ${BLUE}Publication (Yayinlayan):${NC}"
psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    SELECT pubname AS yayin, puballtables AS tum_tablolar,
           pubinsert AS insert, pubupdate AS update, pubdelete AS delete
    FROM pg_publication;
" 2>/dev/null

echo -e "  ${BLUE}Yayin Tablolari:${NC}"
psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    SELECT COUNT(*) AS tablo_sayisi FROM pg_publication_tables
    WHERE pubname = 'pub_sosyal_medya';
" 2>/dev/null

echo -e "  ${BLUE}Subscription (Abone):${NC}"
psql -U "$DB_USER" -d "$REPLICA_DB" -c "
    SELECT subname AS abone, subenabled AS aktif,
           LEFT(subconninfo, 60) AS baglanti
    FROM pg_subscription;
" 2>/dev/null

echo -e "\n${YELLOW}[2/6] Replication Slot Durumu${NC}"
psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    SELECT slot_name, slot_type, active,
           pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS gecikme
    FROM pg_replication_slots;
" 2>/dev/null

echo -e "\n${YELLOW}[3/6] WAL Sender Durumu (Primary)${NC}"
psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    SELECT pid, usename, application_name,
           state, sent_lsn, write_lsn, flush_lsn, replay_lsn,
           pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS gecikme
    FROM pg_stat_replication;
" 2>/dev/null

echo -e "\n${YELLOW}[4/6] Veri Esitleme Kontrolu${NC}"

TABLES="kullanicilar gonderiler yorumlar begeniler takipler mesajlar bildirimler hashtagler gonderi_hashtag"
echo -e "  ${BLUE}Tablo               Primary    Replica    Durum${NC}"
echo -e "  ─────────────────── ────────── ────────── ──────"

ALL_MATCH=true
for tbl in $TABLES; do
    P_COUNT=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "SELECT COUNT(*) FROM $tbl;" 2>/dev/null)
    R_COUNT=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "SELECT COUNT(*) FROM $tbl;" 2>/dev/null)

    if [ "$P_COUNT" = "$R_COUNT" ]; then
        STATUS="${GREEN}✓ Esit${NC}"
    else
        STATUS="${RED}✗ Farkli${NC}"
        ALL_MATCH=false
    fi
    printf "  %-20s %9s %9s  %b\n" "$tbl" "${P_COUNT:-0}" "${R_COUNT:-0}" "$STATUS"
done

if $ALL_MATCH; then
    echo -e "\n  ${GREEN}[OK] Tum tablolar esitlenmis!${NC}"
else
    echo -e "\n  ${YELLOW}[UYARI] Bazi tablolar henuz esitlenmemis${NC}"
fi

echo -e "\n${YELLOW}[5/6] Replikasyon Gecikme Analizi${NC}"

LAG=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "
    SELECT COALESCE(
        pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)),
        'N/A'
    ) FROM pg_replication_slots LIMIT 1;
" 2>/dev/null)
echo -e "  WAL gecikme: ${BLUE}${LAG:-Slot yok}${NC}"

STAT_LAG=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "
    SELECT COALESCE(
        pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)),
        'N/A'
    ) FROM pg_stat_replication LIMIT 1;
" 2>/dev/null)
echo -e "  Replay gecikme: ${BLUE}${STAT_LAG:-Sender yok}${NC}"

echo -e "\n${YELLOW}[6/6] Veritabani Boyutlari${NC}"

P_SIZE=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "SELECT pg_size_pretty(pg_database_size('$PRIMARY_DB'));" 2>/dev/null)
R_SIZE=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "SELECT pg_size_pretty(pg_database_size('$REPLICA_DB'));" 2>/dev/null)
echo -e "  Primary ($PRIMARY_DB): ${BLUE}$P_SIZE${NC}"
echo -e "  Replica ($REPLICA_DB): ${BLUE}$R_SIZE${NC}"

psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    INSERT INTO replikasyon_log (islem_tipi, kaynak_db, hedef_db, detay)
    VALUES ('izleme_raporu', '$PRIMARY_DB', '$REPLICA_DB', 'Lag: ${LAG:-N/A}');
" > /dev/null 2>&1

echo -e "\n${GREEN}Replikasyon izleme tamamlandi!${NC}"
