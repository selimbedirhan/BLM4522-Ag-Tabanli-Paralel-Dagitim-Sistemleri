#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_NAME="kutuphane_db"
DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

show_version() {
    local ver=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT version_no FROM schema_version WHERE durum='basarili' ORDER BY version_id DESC LIMIT 1;
    " 2>/dev/null)
    local tbls=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';
    " 2>/dev/null)
    local cols=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public';
    " 2>/dev/null)
    echo -e "  Surum: ${BLUE}$ver${NC} | Tablo: $tbls | Kolon: $cols"
}

echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Proje 6: Surum Yonetimi Tam Demo           ║${NC}"
echo -e "${MAGENTA}║  v1.0 -> v2.0 -> v3.0 -> rollback -> v3.0   ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${MAGENTA}━━━ ADIM 1: v1.0 Temel Kurulum ━━━${NC}"

psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/01_v1_temel_sema.sql" > /dev/null 2>&1
psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/02_v1_veri_yukle.sql" > /dev/null 2>&1
echo -e "  ${GREEN}v1.0 olusturuldu ve veriler yuklendi${NC}"
show_version
sleep 1

echo -e "\n${MAGENTA}━━━ ADIM 2: Yukseltme Oncesi Kontrol ━━━${NC}"
bash "$SCRIPT_DIR/03_yukseltme_oncesi_kontrol.sh" 2>&1 | tail -5
sleep 1

echo -e "\n${MAGENTA}━━━ ADIM 3: v1.0 -> v2.0 Yukseltme ━━━${NC}"
psql -U "$DB_USER" -d postgres -f "$PROJECT_DIR/migrations/v1_to_v2_migration.sql" > /dev/null 2>&1
echo -e "  ${GREEN}v2.0 migration tamamlandi${NC}"
show_version
sleep 1

echo -e "\n${MAGENTA}━━━ ADIM 4: v2.0 -> v3.0 Yukseltme ━━━${NC}"
psql -U "$DB_USER" -d postgres -f "$PROJECT_DIR/migrations/v2_to_v3_migration.sql" > /dev/null 2>&1
echo -e "  ${GREEN}v3.0 migration tamamlandi${NC}"
show_version
sleep 1

echo -e "\n${MAGENTA}━━━ ADIM 5: Yukseltme Sonrasi Kontrol ━━━${NC}"
bash "$SCRIPT_DIR/05_yukseltme_sonrasi_kontrol.sh" 2>&1 | grep -E "GECTI|KALDI|Surum|Toplam|BASARILI|BASARISIZ"
sleep 1

echo -e "\n${MAGENTA}━━━ ADIM 6: Rollback Testi (v3.0 -> v2.0) ━━━${NC}"
echo -e "  ${YELLOW}v3.0 geri aliniyor...${NC}"
psql -U "$DB_USER" -d postgres -f "$PROJECT_DIR/rollback/v3_to_v2_rollback.sql" > /dev/null 2>&1
echo -e "  ${GREEN}Rollback tamamlandi${NC}"
show_version

for tbl in dijital_kitaplar etkinlikler bildirimler; do
    EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
        SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$tbl';
    " 2>/dev/null)
    if [ "$EXISTS" = "0" ]; then
        echo -e "  ${GREEN}[OK]${NC} $tbl tablosu silindi"
    else
        echo -e "  ${RED}[FAIL]${NC} $tbl tablosu hala mevcut"
    fi
done
sleep 1

echo -e "\n${MAGENTA}━━━ ADIM 7: Tekrar v3.0 Yukseltme ━━━${NC}"

psql -U "$DB_USER" -d "$DB_NAME" -c "
    UPDATE schema_version SET durum='basarili' WHERE version_no='2.0.0' AND durum='basarili';
    DELETE FROM schema_version WHERE version_no='2.0.0-rollback';
" > /dev/null 2>&1

psql -U "$DB_USER" -d postgres -f "$PROJECT_DIR/migrations/v2_to_v3_migration.sql" > /dev/null 2>&1
echo -e "  ${GREEN}v3.0 tekrar uygulandı${NC}"
show_version
sleep 1

echo -e "\n${MAGENTA}━━━ Surum Karsilastirma Tablosu ━━━${NC}"

echo -e "\n  ${BLUE}Surum Gecmisi:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT version_no AS surum, LEFT(aciklama,45) AS aciklama,
           TO_CHAR(uygulama_tarihi,'MM-DD HH24:MI') AS tarih, durum
    FROM schema_version ORDER BY version_id;
" 2>/dev/null

echo -e "\n  ${BLUE}v3.0 Tablo Listesi:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT relname AS tablo, n_live_tup AS kayit,
           pg_size_pretty(pg_total_relation_size(relid)) AS boyut
    FROM pg_stat_user_tables WHERE schemaname='public'
    ORDER BY n_live_tup DESC;
" 2>/dev/null

echo -e "\n  ${BLUE}Kutuphane Istatistik:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM v_kutuphane_istatistik;" 2>/dev/null

echo -e "\n${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║       DEMO TAMAMLANDI                        ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Gosterilen islemler:${NC}"
echo -e "  ${GREEN}1.${NC} v1.0 temel sema olusturma"
echo -e "  ${GREEN}2.${NC} Yukseltme oncesi kontrol"
echo -e "  ${GREEN}3.${NC} v1.0 -> v2.0 migration"
echo -e "  ${GREEN}4.${NC} v2.0 -> v3.0 migration"
echo -e "  ${GREEN}5.${NC} Yukseltme sonrasi uyumluluk testleri"
echo -e "  ${GREEN}6.${NC} Rollback (v3.0 -> v2.0)"
echo -e "  ${GREEN}7.${NC} Tekrar yukseltme (v2.0 -> v3.0)"
echo -e "\n${GREEN}Proje 6 demo tamamlandi!${NC}"
