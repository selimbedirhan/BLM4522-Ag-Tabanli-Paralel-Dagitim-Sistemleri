#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="kutuphane_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

LOG_DIR="$PROJECT_DIR/logs"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/yukseltme_oncesi_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0

check() {
    local name=$1 result=$2
    if [ "$result" -eq 0 ]; then
        echo -e "  ${GREEN}[OK]${NC} $name"; PASS=$((PASS+1))
    else
        echo -e "  ${RED}[FAIL]${NC} $name"; FAIL=$((FAIL+1))
    fi
    echo "[$( [ $result -eq 0 ] && echo 'OK' || echo 'FAIL')] $name" >> "$LOG_FILE"
}

warn() {
    echo -e "  ${YELLOW}[UYARI]${NC} $1"; WARN=$((WARN+1))
    echo "[UYARI] $1" >> "$LOG_FILE"
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YUKSELTME ONCESI KONTROL${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}[1/7] Baglanti Kontrolu${NC}"

pg_isready -q 2>/dev/null
check "PostgreSQL sunucusu erisilebilir" $?

psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1
check "Veritabani baglantisi ($DB_NAME)" $?

echo -e "\n${YELLOW}[2/7] Mevcut Surum Bilgisi${NC}"

CURRENT_VER=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT version_no FROM schema_version WHERE durum='basarili' ORDER BY version_id DESC LIMIT 1;
" 2>/dev/null)

if [ -n "$CURRENT_VER" ]; then
    echo -e "  ${BLUE}Mevcut surum:${NC} $CURRENT_VER"
    check "Surum tablosu mevcut" 0
else
    echo -e "  ${BLUE}Surum bilgisi bulunamadi${NC} (ilk kurulum)"
    CURRENT_VER="yok"
    check "Surum tablosu" 0
fi

echo -e "\n  ${BLUE}Surum gecmisi:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT version_no, LEFT(aciklama,50) AS aciklama,
           TO_CHAR(uygulama_tarihi,'YYYY-MM-DD HH24:MI') AS tarih, durum
    FROM schema_version ORDER BY version_id;
" 2>/dev/null

echo -e "\n${YELLOW}[3/7] Veritabani Durumu${NC}"

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
echo -e "  Boyut: ${BLUE}$DB_SIZE${NC}"

TBL_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';
" 2>/dev/null)
echo -e "  Tablo sayisi: ${BLUE}$TBL_COUNT${NC}"

IDX_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public';" 2>/dev/null)
echo -e "  Indeks sayisi: ${BLUE}$IDX_COUNT${NC}"

VIEW_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public';
" 2>/dev/null)
echo -e "  View sayisi: ${BLUE}$VIEW_COUNT${NC}"

FN_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM pg_proc WHERE pronamespace=(SELECT oid FROM pg_namespace WHERE nspname='public');
" 2>/dev/null)
echo -e "  Fonksiyon sayisi: ${BLUE}$FN_COUNT${NC}"

echo -e "\n${YELLOW}[4/7] Veri Butunlugu Kontrolu${NC}"

FK_VIOLATIONS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM odunc_islemleri oi
    LEFT JOIN kitaplar k ON oi.kitap_id = k.kitap_id
    WHERE k.kitap_id IS NULL;
" 2>/dev/null)
[ "$FK_VIOLATIONS" = "0" ] && check "Foreign key butunlugu" 0 || check "FK ihlali: $FK_VIOLATIONS" 1

NULL_ISBN=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM kitaplar WHERE isbn IS NULL;" 2>/dev/null)
[ "$NULL_ISBN" = "0" ] && check "ISBN bos kayit yok" 0 || warn "$NULL_ISBN kitapta ISBN bos"

DUP_ISBN=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM (SELECT isbn FROM kitaplar GROUP BY isbn HAVING COUNT(*)>1) t;
" 2>/dev/null)
[ "$DUP_ISBN" = "0" ] && check "Tekrarlanan ISBN yok" 0 || warn "$DUP_ISBN tekrarlanan ISBN"

echo -e "\n${YELLOW}[5/7] Aktif Islemler${NC}"

ACTIVE_CONN=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM pg_stat_activity WHERE datname='$DB_NAME' AND state='active' AND pid != pg_backend_pid();
" 2>/dev/null)
echo -e "  Aktif baglanti: ${BLUE}$ACTIVE_CONN${NC}"

RUNNING_Q=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM pg_stat_activity WHERE datname='$DB_NAME' AND state='active'
    AND query NOT LIKE '%pg_stat_activity%' AND pid != pg_backend_pid();
" 2>/dev/null)
if [ "$RUNNING_Q" -gt 0 ] 2>/dev/null; then
    warn "Calisan $RUNNING_Q sorgu var - yukseltme oncesi bekleyin"
else
    check "Calisan uzun sorgu yok" 0
fi

echo -e "\n${YELLOW}[6/7] Disk Alani${NC}"

DISK_AVAIL=$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
DISK_PCT=$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
echo -e "  Kullanilabilir: ${BLUE}$DISK_AVAIL${NC} (kullanim: %$DISK_PCT)"

if [ "$DISK_PCT" -gt 95 ] 2>/dev/null; then
    check "Yeterli disk alani" 1
elif [ "$DISK_PCT" -gt 90 ] 2>/dev/null; then
    warn "Disk kullanimi yuksek: %$DISK_PCT"
else
    check "Yeterli disk alani" 0
fi

echo -e "\n${YELLOW}[7/7] Yukseltme Oncesi Yedek${NC}"

BACKUP_FILE="$BACKUP_DIR/pre_upgrade_${CURRENT_VER}_${TIMESTAMP}.dump"
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -f "$BACKUP_FILE" 2>> "$LOG_FILE"
if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    BSIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || echo "0")
    check "Yukseltme oncesi yedek alindi ($(echo "scale=0;$BSIZE/1024" | bc)KB)" 0
else
    check "Yukseltme oncesi yedek" 1
fi

TOTAL=$((PASS + FAIL + WARN))
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   KONTROL SONUCU${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Basarili: ${GREEN}$PASS${NC} | Basarisiz: ${RED}$FAIL${NC} | Uyari: ${YELLOW}$WARN${NC}"
echo -e "  Mevcut surum: ${BLUE}$CURRENT_VER${NC}"
echo -e "  Yedek: $(basename $BACKUP_FILE)"

if [ $FAIL -eq 0 ]; then
    echo -e "\n  ${GREEN}YUKSELTMEYE HAZIR!${NC}"
else
    echo -e "\n  ${RED}YUKSELTME YAPILAMAZ - $FAIL sorun cozulmeli!${NC}"
fi

echo -e "  Log: $(basename $LOG_FILE)"
