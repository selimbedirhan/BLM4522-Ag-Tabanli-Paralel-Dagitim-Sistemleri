#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_DIR/config/yedekleme_ayar.conf" 2>/dev/null

BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
REPORT_DIR="$PROJECT_DIR/reports"
export PATH="${PG_BIN:-/opt/homebrew/opt/postgresql@14/bin}:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$REPORT_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   YEDEKLEME RAPORLAMA SISTEMI${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}[1/4] Yedekleme Istatistikleri${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM fn_yedekleme_istatistik();" 2>/dev/null

echo -e "\n${YELLOW}[2/4] Son 7 Gun Yedekleme Raporu${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM fn_yedekleme_rapor(7);" 2>/dev/null

echo -e "\n${YELLOW}[3/4] Uyari Kontrolleri${NC}"
UYARI_SONUC=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT uyari_tipi, mesaj FROM fn_yedekleme_uyari_kontrol();" 2>/dev/null)
if echo "$UYARI_SONUC" | grep -q "NORMAL"; then
    echo -e "  ${GREEN}Tum yedeklemeler normal${NC}"
else
    echo -e "  ${RED}UYARILAR:${NC}"
    echo "$UYARI_SONUC" | while IFS='|' read tip mesaj; do
        echo -e "    ${YELLOW}[$tip]${NC} $mesaj"
    done
fi

echo -e "\n${YELLOW}[4/4] Disk Kullanim Raporu${NC}"

TOTAL_BACKUPS=$(find "$BACKUP_DIR" -type f \( -name "*.dump" -o -name "*.sql.gz" \) 2>/dev/null | wc -l | tr -d ' ')
DAILY_COUNT=$(find "$BACKUP_DIR/daily" -type f 2>/dev/null | wc -l | tr -d ' ')
WEEKLY_COUNT=$(find "$BACKUP_DIR/weekly" -type f 2>/dev/null | wc -l | tr -d ' ')
MONTHLY_COUNT=$(find "$BACKUP_DIR/monthly" -type f 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')

echo -e "  Toplam yedek: ${BLUE}$TOTAL_BACKUPS${NC} ($TOTAL_SIZE)"
echo -e "  Gunluk: $DAILY_COUNT | Haftalik: $WEEKLY_COUNT | Aylik: $MONTHLY_COUNT"

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
echo -e "  Veritabani boyutu: ${BLUE}$DB_SIZE${NC}"

echo -e "\n${YELLOW}HTML Rapor olusturuluyor...${NC}"
HTML_FILE="$REPORT_DIR/yedekleme_raporu_${TIMESTAMP}.html"

TOPLAM=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM yedekleme_log;" 2>/dev/null)
BASARILI=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM yedekleme_log WHERE durum='basarili';" 2>/dev/null)
BASARISIZ=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM yedekleme_log WHERE durum='basarisiz';" 2>/dev/null)
ORT_SURE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COALESCE(ROUND(AVG(sure_saniye)::NUMERIC,1),0) FROM yedekleme_log WHERE durum='basarili';" 2>/dev/null)
BASARI_ORAN=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COALESCE(ROUND(COUNT(*) FILTER (WHERE durum='basarili')*100.0/NULLIF(COUNT(*),0),1),0) FROM yedekleme_log;" 2>/dev/null)

cat > "$HTML_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<title>Yedekleme Raporu</title>
<style>
body{font-family:'Segoe UI',sans-serif;background:#0f0f23;color:#e0e0e0;margin:0;padding:20px}
.container{max-width:1100px;margin:0 auto}
h1{color:#00d4ff;text-align:center;font-size:28px;margin-bottom:5px}
.subtitle{text-align:center;color:#888;margin-bottom:25px}
h2{color:#ffa500;border-left:4px solid #ffa500;padding-left:12px;margin-top:35px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:15px;margin:20px 0}
.card{background:linear-gradient(135deg,#1a1a3e,#16213e);border-radius:12px;padding:20px;text-align:center;border:1px solid #ffffff10;box-shadow:0 8px 32px rgba(0,0,0,.3)}
.card .val{font-size:32px;font-weight:700;color:#00d4ff}
.card .lbl{font-size:13px;color:#aaa;margin-top:6px}
.card.ok .val{color:#2ecc71}
.card.warn .val{color:#f39c12}
.card.err .val{color:#e74c3c}
table{width:100%;border-collapse:collapse;margin:15px 0;background:#16213e;border-radius:8px;overflow:hidden}
th{background:#0f3460;color:#00d4ff;padding:12px 15px;text-align:left;font-size:13px;text-transform:uppercase;letter-spacing:.5px}
td{padding:10px 15px;border-bottom:1px solid #ffffff08;font-size:14px}
tr:hover td{background:#1a1a4e}
.badge{padding:3px 10px;border-radius:12px;font-size:12px;font-weight:600}
.badge-ok{background:#2ecc7133;color:#2ecc71}
.badge-err{background:#e74c3c33;color:#e74c3c}
.badge-warn{background:#f39c1233;color:#f39c12}
.footer{text-align:center;color:#555;margin-top:40px;padding:20px;border-top:1px solid #ffffff10}
</style>
</head>
<body>
<div class="container">
<h1>Yedekleme Otomasyon Raporu</h1>
HTMLEOF

echo "<p class='subtitle'>$(date '+%Y-%m-%d %H:%M:%S') | $DB_NAME | PostgreSQL 14</p>" >> "$HTML_FILE"

echo '<div class="grid">' >> "$HTML_FILE"
echo "<div class='card'><div class='val'>$DB_SIZE</div><div class='lbl'>Veritabani Boyutu</div></div>" >> "$HTML_FILE"
echo "<div class='card'><div class='val'>$TOPLAM</div><div class='lbl'>Toplam Yedek</div></div>" >> "$HTML_FILE"
echo "<div class='card ok'><div class='val'>$BASARILI</div><div class='lbl'>Basarili</div></div>" >> "$HTML_FILE"
echo "<div class='card err'><div class='val'>$BASARISIZ</div><div class='lbl'>Basarisiz</div></div>" >> "$HTML_FILE"
echo "<div class='card'><div class='val'>${ORT_SURE}sn</div><div class='lbl'>Ort. Sure</div></div>" >> "$HTML_FILE"
echo "<div class='card ok'><div class='val'>%$BASARI_ORAN</div><div class='lbl'>Basari Orani</div></div>" >> "$HTML_FILE"
echo '</div>' >> "$HTML_FILE"

echo '<h2>Son Yedekleme Kayitlari</h2>' >> "$HTML_FILE"
echo '<table><tr><th>#</th><th>Tarih</th><th>Tip</th><th>Dosya</th><th>Boyut</th><th>Sure</th><th>Durum</th></tr>' >> "$HTML_FILE"

psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT log_id, TO_CHAR(yedek_tarihi,'YYYY-MM-DD HH24:MI'), yedek_tipi, dosya_adi,
           pg_size_pretty(dosya_boyutu), sure_saniye||'sn', durum
    FROM yedekleme_log ORDER BY log_id DESC LIMIT 20;
" 2>/dev/null | while IFS='|' read id tarih tip dosya boyut sure durum; do
    badge="badge-ok"
    [ "$durum" = "basarisiz" ] && badge="badge-err"
    [ "$durum" = "uyari" ] && badge="badge-warn"
    echo "<tr><td>$id</td><td>$tarih</td><td>$tip</td><td>$dosya</td><td>$boyut</td><td>$sure</td><td><span class='badge $badge'>$durum</span></td></tr>" >> "$HTML_FILE"
done

echo '</table>' >> "$HTML_FILE"

echo '<h2>Disk Kullanimi</h2>' >> "$HTML_FILE"
echo '<table><tr><th>Kategori</th><th>Dosya Sayisi</th><th>Boyut</th></tr>' >> "$HTML_FILE"
DAILY_SIZE=$(du -sh "$BACKUP_DIR/daily" 2>/dev/null | awk '{print $1}')
WEEKLY_SIZE=$(du -sh "$BACKUP_DIR/weekly" 2>/dev/null | awk '{print $1}')
MONTHLY_SIZE=$(du -sh "$BACKUP_DIR/monthly" 2>/dev/null | awk '{print $1}')
echo "<tr><td>Gunluk</td><td>$DAILY_COUNT</td><td>${DAILY_SIZE:-0}</td></tr>" >> "$HTML_FILE"
echo "<tr><td>Haftalik</td><td>$WEEKLY_COUNT</td><td>${WEEKLY_SIZE:-0}</td></tr>" >> "$HTML_FILE"
echo "<tr><td>Aylik</td><td>$MONTHLY_COUNT</td><td>${MONTHLY_SIZE:-0}</td></tr>" >> "$HTML_FILE"
echo "<tr><td><strong>Toplam</strong></td><td><strong>$TOTAL_BACKUPS</strong></td><td><strong>$TOTAL_SIZE</strong></td></tr>" >> "$HTML_FILE"
echo '</table>' >> "$HTML_FILE"

echo "<div class='footer'><p>BLM4522 - Proje 7: Yedekleme ve Otomasyon | $(date '+%Y')</p></div>" >> "$HTML_FILE"
echo '</div></body></html>' >> "$HTML_FILE"

echo -e "  ${GREEN}HTML rapor olusturuldu${NC}: $(basename $HTML_FILE)"
echo -e "  Acmak icin: ${BLUE}open \"$HTML_FILE\"${NC}"

echo -e "\n${GREEN}Raporlama tamamlandi!${NC}"
