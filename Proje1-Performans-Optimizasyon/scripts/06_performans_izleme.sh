#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="egitim_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

LOG_DIR="$PROJECT_DIR/logs"
REPORT_DIR="$PROJECT_DIR/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR" "$REPORT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   PERFORMANS IZLEME VE RAPORLAMA${NC}"
echo -e "${CYAN}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}[1/8] Veritabani Genel Bilgileri${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT pg_size_pretty(pg_database_size('$DB_NAME')) AS db_boyutu,
       (SELECT COUNT(*) FROM pg_stat_user_tables) AS tablo_sayisi,
       (SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public') AS indeks_sayisi,
       (SELECT SUM(n_live_tup) FROM pg_stat_user_tables) AS toplam_kayit;
" 2>/dev/null

echo -e "\n${YELLOW}[2/8] Tablo Boyutlari ve Kayit Sayilari${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT relname AS tablo,
       pg_size_pretty(pg_total_relation_size(relid)) AS toplam_boyut,
       pg_size_pretty(pg_relation_size(relid)) AS veri_boyutu,
       pg_size_pretty(pg_indexes_size(relid)) AS indeks_boyutu,
       n_live_tup AS canli_kayit,
       n_dead_tup AS olu_kayit,
       CASE WHEN n_live_tup > 0
            THEN ROUND(n_dead_tup::NUMERIC * 100 / n_live_tup, 1)
            ELSE 0 END AS bloat_yuzde
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC;
" 2>/dev/null

echo -e "\n${YELLOW}[3/8] Indeks Kullanim Oranlari${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT relname AS tablo,
       seq_scan AS sirasal_tarama,
       idx_scan AS indeks_tarama,
       CASE WHEN (seq_scan + idx_scan) > 0
           THEN ROUND(idx_scan::NUMERIC * 100 / (seq_scan + idx_scan), 1)
           ELSE 0 END AS indeks_kullanim_yuzde,
       pg_size_pretty(pg_relation_size(relid)) AS tablo_boyutu
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY (seq_scan + idx_scan) DESC;
" 2>/dev/null

echo -e "\n${YELLOW}[4/8] Kullanilmayan/Az Kullanilan Indeksler${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT s.relname AS tablo,
       s.indexrelname AS indeks,
       s.idx_scan AS kullanim_sayisi,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS boyut
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan < 5 AND NOT i.indisunique
  AND s.schemaname = 'public'
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 15;
" 2>/dev/null

echo -e "\n${YELLOW}[5/8] Cache/Buffer Hit Orani${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 'Tablo Verileri' AS kategori,
       SUM(heap_blks_hit) AS cache_hit,
       SUM(heap_blks_read) AS disk_read,
       CASE WHEN SUM(heap_blks_hit) + SUM(heap_blks_read) > 0
           THEN ROUND(SUM(heap_blks_hit)::NUMERIC * 100 / (SUM(heap_blks_hit) + SUM(heap_blks_read)), 2)
           ELSE 0 END AS hit_orani_yuzde
FROM pg_statio_user_tables
UNION ALL
SELECT 'Indeks Verileri',
       SUM(idx_blks_hit), SUM(idx_blks_read),
       CASE WHEN SUM(idx_blks_hit) + SUM(idx_blks_read) > 0
           THEN ROUND(SUM(idx_blks_hit)::NUMERIC * 100 / (SUM(idx_blks_hit) + SUM(idx_blks_read)), 2)
           ELSE 0 END
FROM pg_statio_user_indexes;
" 2>/dev/null

echo -e "\n${YELLOW}[6/8] Table Bloat (Siskinlik) Analizi${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT relname AS tablo,
       n_live_tup AS canli,
       n_dead_tup AS olu,
       CASE WHEN n_live_tup > 0
           THEN ROUND(n_dead_tup::NUMERIC * 100 / n_live_tup, 1) ELSE 0 END AS bloat_pct,
       last_vacuum::TEXT,
       last_autovacuum::TEXT,
       last_analyze::TEXT
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC
LIMIT 10;
" 2>/dev/null

echo -e "\n${YELLOW}[7/8] Aktif Baglantilar${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT datname AS db, usename AS kullanici,
       state AS durum, COUNT(*) AS sayi
FROM pg_stat_activity
WHERE datname = '$DB_NAME'
GROUP BY datname, usename, state;
" 2>/dev/null

echo -e "\n${YELLOW}[8/8] Performans Parametreleri${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT name AS parametre, setting AS deger, unit AS birim, short_desc AS aciklama
FROM pg_settings
WHERE name IN ('shared_buffers','work_mem','maintenance_work_mem',
               'effective_cache_size','random_page_cost','seq_page_cost',
               'max_connections','checkpoint_completion_target',
               'wal_buffers','default_statistics_target')
ORDER BY name;
" 2>/dev/null

echo -e "\n${YELLOW}HTML Rapor olusturuluyor...${NC}"
HTML_FILE="$REPORT_DIR/performans_raporu_${TIMESTAMP}.html"

DB_SIZE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null)
TBL_CNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_stat_user_tables;" 2>/dev/null)
IDX_CNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public';" 2>/dev/null)
TOTAL_REC=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT SUM(n_live_tup) FROM pg_stat_user_tables;" 2>/dev/null)
CACHE_HIT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT CASE WHEN SUM(heap_blks_hit)+SUM(heap_blks_read)>0
        THEN ROUND(SUM(heap_blks_hit)*100.0/(SUM(heap_blks_hit)+SUM(heap_blks_read)),1) ELSE 0 END
    FROM pg_statio_user_tables;" 2>/dev/null)

cat > "$HTML_FILE" << 'HTMLEOF'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<title>Performans Raporu</title>
<style>
body{font-family:'Segoe UI',sans-serif;background:#0a0a1a;color:#e0e0e0;margin:0;padding:20px}
.container{max-width:1100px;margin:0 auto}
h1{color:#00d4ff;text-align:center;font-size:28px}
.sub{text-align:center;color:#888;margin-bottom:25px}
h2{color:#f39c12;border-left:4px solid #f39c12;padding-left:12px;margin-top:35px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:20px 0}
.card{background:linear-gradient(135deg,#1a1a3e,#16213e);border-radius:12px;padding:18px;text-align:center;border:1px solid #ffffff10}
.card .v{font-size:28px;font-weight:700;color:#00d4ff}
.card .l{font-size:12px;color:#aaa;margin-top:5px}
table{width:100%;border-collapse:collapse;margin:12px 0;background:#16213e;border-radius:8px;overflow:hidden}
th{background:#0f3460;color:#00d4ff;padding:10px 12px;text-align:left;font-size:12px;text-transform:uppercase}
td{padding:8px 12px;border-bottom:1px solid #ffffff08;font-size:13px}
tr:hover td{background:#1a1a4e}
.good{color:#2ecc71}.warn{color:#f39c12}.bad{color:#e74c3c}
.footer{text-align:center;color:#555;margin-top:40px;font-size:12px}
</style></head><body><div class="container">
<h1>Performans Izleme Raporu</h1>
HTMLEOF

echo "<p class='sub'>$(date '+%Y-%m-%d %H:%M:%S') | egitim_db | PostgreSQL 14</p>" >> "$HTML_FILE"
echo '<div class="grid">' >> "$HTML_FILE"
echo "<div class='card'><div class='v'>$DB_SIZE</div><div class='l'>DB Boyutu</div></div>" >> "$HTML_FILE"
echo "<div class='card'><div class='v'>$TBL_CNT</div><div class='l'>Tablo</div></div>" >> "$HTML_FILE"
echo "<div class='card'><div class='v'>$IDX_CNT</div><div class='l'>Indeks</div></div>" >> "$HTML_FILE"
echo "<div class='card'><div class='v'>$TOTAL_REC</div><div class='l'>Toplam Kayit</div></div>" >> "$HTML_FILE"
echo "<div class='card'><div class='v'>%$CACHE_HIT</div><div class='l'>Cache Hit</div></div>" >> "$HTML_FILE"
echo '</div>' >> "$HTML_FILE"

echo '<h2>Tablo Boyutlari</h2><table><tr><th>Tablo</th><th>Boyut</th><th>Kayit</th><th>Indeks</th><th>Bloat%</th></tr>' >> "$HTML_FILE"
psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT relname, pg_size_pretty(pg_total_relation_size(relid)),
           n_live_tup, pg_size_pretty(pg_indexes_size(relid)),
           CASE WHEN n_live_tup>0 THEN ROUND(n_dead_tup*100.0/n_live_tup,1) ELSE 0 END
    FROM pg_stat_user_tables WHERE schemaname='public' ORDER BY pg_total_relation_size(relid) DESC;
" 2>/dev/null | while IFS='|' read tbl sz rec idx bl; do
    echo "<tr><td>$tbl</td><td>$sz</td><td>$rec</td><td>$idx</td><td>$bl%</td></tr>" >> "$HTML_FILE"
done
echo '</table>' >> "$HTML_FILE"

echo '<h2>Indeks Kullanim Oranlari</h2><table><tr><th>Tablo</th><th>Seq Scan</th><th>Idx Scan</th><th>Kullanim%</th></tr>' >> "$HTML_FILE"
psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT relname, seq_scan, idx_scan,
           CASE WHEN (seq_scan+idx_scan)>0 THEN ROUND(idx_scan*100.0/(seq_scan+idx_scan),1) ELSE 0 END
    FROM pg_stat_user_tables WHERE schemaname='public' ORDER BY (seq_scan+idx_scan) DESC;
" 2>/dev/null | while IFS='|' read tbl ss is pct; do
    cls="good"
    [ "$(echo "$pct < 50" | bc)" = "1" ] 2>/dev/null && cls="bad"
    [ "$(echo "$pct < 80" | bc)" = "1" ] 2>/dev/null && [ "$(echo "$pct >= 50" | bc)" = "1" ] 2>/dev/null && cls="warn"
    echo "<tr><td>$tbl</td><td>$ss</td><td>$is</td><td class='$cls'>%$pct</td></tr>" >> "$HTML_FILE"
done
echo '</table>' >> "$HTML_FILE"

echo "<div class='footer'><p>BLM4522 - Proje 1: Performans Optimizasyonu | $(date '+%Y')</p></div>" >> "$HTML_FILE"
echo '</div></body></html>' >> "$HTML_FILE"

echo -e "  ${GREEN}HTML rapor olusturuldu${NC}: $(basename $HTML_FILE)"
echo -e "\n${GREEN}Performans izleme tamamlandi!${NC}"
