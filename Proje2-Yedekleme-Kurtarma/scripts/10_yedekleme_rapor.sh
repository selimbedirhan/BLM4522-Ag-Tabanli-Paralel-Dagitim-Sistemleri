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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
REPORT_FILE="$LOG_DIR/yedekleme_raporu_${TIMESTAMP}.html"

export PATH="$PG_BIN:$PATH"
mkdir -p "$LOG_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEKLEME DURUMU RAPORU${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

format_size() {
    local size=$1
    if [ -z "$size" ] || [ "$size" = "0" ]; then
        echo "0 bytes"
    elif [ "$size" -gt 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    elif [ "$size" -gt 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    else
        echo "$size bytes"
    fi
}

echo -e "\n${YELLOW}[1/5] Veritabani Genel Bilgileri${NC}"
echo -e "\n  ${BLUE}Veritabani Boyutlari:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT datname AS \"Veritabani\", pg_size_pretty(pg_database_size(datname)) AS \"Boyut\" FROM pg_database WHERE datname NOT LIKE 'template%' ORDER BY pg_database_size(datname) DESC;" 2>/dev/null

echo -e "\n  ${BLUE}Tablo Boyutlari:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT relname AS \"Tablo\", pg_size_pretty(pg_total_relation_size(relid)) AS \"Toplam Boyut\", pg_size_pretty(pg_relation_size(relid)) AS \"Veri Boyutu\", pg_size_pretty(pg_indexes_size(relid)) AS \"Indeks Boyutu\", n_live_tup AS \"Kayit Sayisi\" FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC;" 2>/dev/null

echo -e "\n${YELLOW}[2/5] Yedek Dosyalari Listesi${NC}"
echo -e "\n  ${BLUE}Full Yedekler:${NC}"
if ls "$BACKUP_DIR/full/"*.dump 2>/dev/null | head -5 > /dev/null 2>&1; then
    printf "  %-50s %12s %20s\n" "Dosya" "Boyut" "Tarih"
    printf "  %-50s %12s %20s\n" "--------------------------------------------------" "----------" "--------------------"
    for f in "$BACKUP_DIR/full/"*.dump "$BACKUP_DIR/full/"*.sql "$BACKUP_DIR/full/"*.sql.gz "$BACKUP_DIR/full/"*.tar; do
        if [ -f "$f" ]; then
            FNAME=$(basename "$f")
            FSIZE=$(stat -f%z "$f" 2>/dev/null || echo "0")
            FDATE=$(stat -f"%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "N/A")
            printf "  %-50s %12s %20s\n" "$FNAME" "$(format_size $FSIZE)" "$FDATE"
        fi
    done
fi

echo -e "\n  ${BLUE}Differential Yedekler:${NC}"
for f in "$BACKUP_DIR/differential/"*; do
    if [ -f "$f" ]; then
        FNAME=$(basename "$f")
        FSIZE=$(stat -f%z "$f" 2>/dev/null || echo "0")
        printf "  %-50s %12s\n" "$FNAME" "$(format_size $FSIZE)"
    fi
done

echo -e "\n  ${BLUE}Otomatik Yedekler:${NC}"
for f in "$BACKUP_DIR/auto/"*.dump; do
    if [ -f "$f" ]; then
        FNAME=$(basename "$f")
        FSIZE=$(stat -f%z "$f" 2>/dev/null || echo "0")
        FDATE=$(stat -f"%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "N/A")
        printf "  %-50s %12s %20s\n" "$FNAME" "$(format_size $FSIZE)" "$FDATE"
    fi
done

echo -e "\n${YELLOW}[3/5] Yedekleme Istatistikleri${NC}"
TOTAL_BACKUP_COUNT=$(find "$BACKUP_DIR" -type f \( -name "*.dump" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar" \) 2>/dev/null | wc -l | tr -d ' ')
TOTAL_BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
echo -e "  Toplam yedek dosyasi: ${BLUE}$TOTAL_BACKUP_COUNT${NC}"
echo -e "  Toplam yedek boyutu: ${BLUE}$TOTAL_BACKUP_SIZE${NC}"

echo -e "\n${YELLOW}[4/5] PostgreSQL Durum Bilgileri${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'Surum' AS bilgi, version() AS deger UNION ALL SELECT 'WAL Level', setting FROM pg_settings WHERE name = 'wal_level' UNION ALL SELECT 'Archive Mode', setting FROM pg_settings WHERE name = 'archive_mode' UNION ALL SELECT 'Max Connections', setting FROM pg_settings WHERE name = 'max_connections' UNION ALL SELECT 'Shared Buffers', setting FROM pg_settings WHERE name = 'shared_buffers' UNION ALL SELECT 'Checkpoint Timeout', setting FROM pg_settings WHERE name = 'checkpoint_timeout';" 2>/dev/null

echo -e "\n${YELLOW}[5/5] HTML Rapor Olusturma${NC}"

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
WAL_LVL=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW wal_level;" 2>/dev/null)
ARCH_MODE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW archive_mode;" 2>/dev/null)
MAX_WAL=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW max_wal_size;" 2>/dev/null)
CHKPT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW checkpoint_timeout;" 2>/dev/null)
SHBUF=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW shared_buffers;" 2>/dev/null)
CURRENT_YEAR=$(date '+%Y')
CURRENT_DT=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$REPORT_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Yedekleme Raporu</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }
        .container { max-width: 1000px; margin: 0 auto; }
        h1 { color: #00d4ff; text-align: center; border-bottom: 2px solid #00d4ff; padding-bottom: 10px; }
        h2 { color: #f39c12; margin-top: 30px; }
        .card { background: #16213e; border-radius: 10px; padding: 20px; margin: 15px 0; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th { background: #0f3460; color: #00d4ff; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #333; }
        .status-ok { color: #2ecc71; font-weight: bold; }
        .metric { display: inline-block; background: #0f3460; border-radius: 8px; padding: 15px 25px; margin: 5px; text-align: center; }
        .metric .value { font-size: 24px; font-weight: bold; color: #00d4ff; }
        .metric .label { font-size: 12px; color: #aaa; }
        .footer { text-align: center; color: #666; margin-top: 30px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Yedekleme Durumu Raporu</h1>
HTMLEOF

echo "        <p style=\"text-align: center; color: #aaa;\">$CURRENT_DT | $DB_NAME | PostgreSQL</p>" >> "$REPORT_FILE"
echo "        <div style=\"text-align: center; margin: 20px 0;\">" >> "$REPORT_FILE"
echo "            <div class=\"metric\"><div class=\"value\">$DB_SIZE</div><div class=\"label\">Veritabani Boyutu</div></div>" >> "$REPORT_FILE"
echo "            <div class=\"metric\"><div class=\"value\">$TOTAL_BACKUP_COUNT</div><div class=\"label\">Toplam Yedek</div></div>" >> "$REPORT_FILE"
echo "            <div class=\"metric\"><div class=\"value\">$TOTAL_BACKUP_SIZE</div><div class=\"label\">Yedek Boyutu</div></div>" >> "$REPORT_FILE"
echo "        </div>" >> "$REPORT_FILE"

echo "        <h2>Veritabani Tablolari</h2>" >> "$REPORT_FILE"
echo "        <div class=\"card\"><table>" >> "$REPORT_FILE"
echo "            <tr><th>Tablo</th><th>Kayit Sayisi</th><th>Boyut</th></tr>" >> "$REPORT_FILE"

psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT relname, n_live_tup, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC;" 2>/dev/null | while IFS='|' read tablo kayit boyut; do
    echo "            <tr><td>$tablo</td><td>$kayit</td><td>$boyut</td></tr>" >> "$REPORT_FILE"
done

echo "        </table></div>" >> "$REPORT_FILE"

echo "        <h2>Yedek Dosyalari</h2>" >> "$REPORT_FILE"
echo "        <div class=\"card\"><table>" >> "$REPORT_FILE"
echo "            <tr><th>Dosya</th><th>Boyut</th><th>Tarih</th><th>Durum</th></tr>" >> "$REPORT_FILE"

find "$BACKUP_DIR" -type f \( -name "*.dump" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.tar" \) 2>/dev/null | sort -r | head -20 | while read f; do
    FNAME=$(basename "$f")
    FSIZE=$(stat -f%z "$f" 2>/dev/null || echo "0")
    FDATE=$(stat -f"%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "N/A")
    FSIZE_HR="${FSIZE} bytes"
    if [ "$FSIZE" -gt 1048576 ] 2>/dev/null; then
        FSIZE_HR="$(echo "scale=2; $FSIZE/1048576" | bc) MB"
    elif [ "$FSIZE" -gt 1024 ] 2>/dev/null; then
        FSIZE_HR="$(echo "scale=2; $FSIZE/1024" | bc) KB"
    fi
    echo "            <tr><td>$FNAME</td><td>$FSIZE_HR</td><td>$FDATE</td><td class='status-ok'>OK</td></tr>" >> "$REPORT_FILE"
done

echo "        </table></div>" >> "$REPORT_FILE"

echo "        <h2>PostgreSQL Yapilandirma</h2>" >> "$REPORT_FILE"
echo "        <div class=\"card\"><table>" >> "$REPORT_FILE"
echo "            <tr><th>Parametre</th><th>Deger</th></tr>" >> "$REPORT_FILE"
echo "            <tr><td>WAL Level</td><td>$WAL_LVL</td></tr>" >> "$REPORT_FILE"
echo "            <tr><td>Archive Mode</td><td>$ARCH_MODE</td></tr>" >> "$REPORT_FILE"
echo "            <tr><td>Max WAL Size</td><td>$MAX_WAL</td></tr>" >> "$REPORT_FILE"
echo "            <tr><td>Checkpoint Timeout</td><td>$CHKPT</td></tr>" >> "$REPORT_FILE"
echo "            <tr><td>Shared Buffers</td><td>$SHBUF</td></tr>" >> "$REPORT_FILE"
echo "        </table></div>" >> "$REPORT_FILE"

echo "        <div class=\"footer\"><p>BLM4522 - Proje 2 | $CURRENT_YEAR</p></div>" >> "$REPORT_FILE"
echo "    </div></body></html>" >> "$REPORT_FILE"

echo -e "${GREEN}  HTML rapor olusturuldu${NC}"
echo -e "    Dosya: $REPORT_FILE"
echo -e "    Acmak icin: open \"$REPORT_FILE\""

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   RAPOR TAMAMLANDI${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Veritabani: $DB_NAME ($DB_SIZE)"
echo -e "  Toplam Yedek: $TOTAL_BACKUP_COUNT dosya ($TOTAL_BACKUP_SIZE)"
echo -e "  HTML Rapor: $REPORT_FILE"
echo -e "\n${GREEN}Yedekleme raporu olusturuldu!${NC}"
