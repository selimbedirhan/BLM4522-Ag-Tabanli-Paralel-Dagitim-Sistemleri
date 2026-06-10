#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   REPLIKASYON ALTYAPI KURULUMU${NC}"
echo -e "${CYAN}============================================${NC}"

CURRENT_WAL=$(psql -U "$DB_USER" -d postgres -t -A -c "SHOW wal_level;" 2>/dev/null)
echo -e "\n  Mevcut WAL seviyesi: ${BLUE}$CURRENT_WAL${NC}"

if [ "$CURRENT_WAL" != "logical" ]; then
    echo -e "  ${YELLOW}WAL seviyesi 'logical' olarak degistiriliyor...${NC}"

    PG_CONF=$(psql -U "$DB_USER" -d postgres -t -A -c "SHOW config_file;" 2>/dev/null)
    echo -e "  Config: ${BLUE}$PG_CONF${NC}"

    cp "$PG_CONF" "${PG_CONF}.bak" 2>/dev/null

    if grep -q "^wal_level" "$PG_CONF" 2>/dev/null; then
        sed -i '' "s/^wal_level.*/wal_level = logical/" "$PG_CONF"
    elif grep -q "^#wal_level" "$PG_CONF" 2>/dev/null; then
        sed -i '' "s/^#wal_level.*/wal_level = logical/" "$PG_CONF"
    else
        echo "wal_level = logical" >> "$PG_CONF"
    fi

    if grep -q "^max_replication_slots" "$PG_CONF" 2>/dev/null; then
        sed -i '' "s/^max_replication_slots.*/max_replication_slots = 10/" "$PG_CONF"
    elif grep -q "^#max_replication_slots" "$PG_CONF" 2>/dev/null; then
        sed -i '' "s/^#max_replication_slots.*/max_replication_slots = 10/" "$PG_CONF"
    else
        echo "max_replication_slots = 10" >> "$PG_CONF"
    fi

    if grep -q "^max_wal_senders" "$PG_CONF" 2>/dev/null; then
        sed -i '' "s/^max_wal_senders.*/max_wal_senders = 10/" "$PG_CONF"
    elif grep -q "^#max_wal_senders" "$PG_CONF" 2>/dev/null; then
        sed -i '' "s/^#max_wal_senders.*/max_wal_senders = 10/" "$PG_CONF"
    else
        echo "max_wal_senders = 10" >> "$PG_CONF"
    fi

    echo -e "  ${YELLOW}PostgreSQL yeniden baslatiliyor...${NC}"
    /opt/homebrew/bin/brew services restart postgresql@14

    sleep 3
    for attempt in 1 2 3 4 5; do
        pg_isready -q 2>/dev/null && break
        echo -e "  Bekleniyor... ($attempt/5)"
        sleep 2
    done

    NEW_WAL=$(psql -U "$DB_USER" -d postgres -t -A -c "SHOW wal_level;" 2>/dev/null)
    echo -e "  Yeni WAL seviyesi: ${GREEN}$NEW_WAL${NC}"

    if [ "$NEW_WAL" = "logical" ]; then
        echo -e "  ${GREEN}[OK] WAL logical seviyesine yuklendi!${NC}"
    else
        echo -e "  ${RED}[HATA] WAL degisikligi uygulanamadi${NC}"
        echo -e "  Manuel olarak postgresql.conf'a 'wal_level = logical' ekleyin"
        echo -e "  ve 'brew services restart postgresql@14' yapin."
    fi
else
    echo -e "  ${GREEN}[OK] WAL zaten logical seviyesinde${NC}"
fi

echo -e "\n${YELLOW}Replikasyon Parametreleri:${NC}"
psql -U "$DB_USER" -d postgres -c "
    SELECT name AS parametre, setting AS deger, short_desc AS aciklama
    FROM pg_settings
    WHERE name IN ('wal_level','max_replication_slots','max_wal_senders',
                   'max_logical_replication_workers','wal_sender_timeout')
    ORDER BY name;
" 2>/dev/null

echo -e "\n${GREEN}Altyapi kurulumu tamamlandi!${NC}"
