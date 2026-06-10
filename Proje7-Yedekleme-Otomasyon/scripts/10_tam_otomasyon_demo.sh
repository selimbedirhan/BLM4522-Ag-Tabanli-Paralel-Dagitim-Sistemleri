#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_DIR/config/yedekleme_ayar.conf" 2>/dev/null

export PATH="${PG_BIN:-/opt/homebrew/opt/postgresql@14/bin}:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

clear
echo -e "${MAGENTA}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  BLM4522 - Proje 7                               ║${NC}"
echo -e "${MAGENTA}║  Veritabani Yedekleme ve Otomasyon Calismasi     ║${NC}"
echo -e "${MAGENTA}║  PostgreSQL 14 | $(date '+%Y-%m-%d %H:%M:%S')            ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════╝${NC}"

echo -e "\n${CYAN}Bu demo, otomasyon sisteminin tum adimlarini sirayla calistirir.${NC}"
echo -e "${CYAN}Her adim arasinda kisa bir bekleme yapilir.${NC}\n"

run_step() {
    local num=$1 title=$2 script=$3
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  ADIM $num: $title${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    bash "$SCRIPT_DIR/$script" 2>&1
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo -e "\n  ${GREEN}Adim $num tamamlandi${NC}"
    else
        echo -e "\n  ${YELLOW}Adim $num tamamlandi (bazi uyarilar olabilir)${NC}"
    fi
    
    sleep 1
}

run_step 1 "Otomasyon Altyapi Kontrolu" "03_otomasyon_altyapi.sh"

run_step 2 "Otomatik Yedekleme" "04_otomatik_yedekleme.sh"

echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  ADIM 3: Denetim Sorgulari${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Yedekleme Istatistikleri:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM fn_yedekleme_istatistik();" 2>/dev/null

echo -e "\n${YELLOW}Uyari Kontrolleri:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM fn_yedekleme_uyari_kontrol();" 2>/dev/null

echo -e "\n${YELLOW}Yedekleme Trend Analizi:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM v_yedekleme_trend;" 2>/dev/null

echo -e "\n  ${GREEN}Adim 3 tamamlandi${NC}"
sleep 1

run_step 4 "Uyari Sistemi Kontrolu" "07_basarisizlik_uyari.sh"

run_step 5 "Yedek Rotasyon" "08_yedek_rotasyon.sh"

run_step 6 "Otomatik Yedek Dogrulama" "09_yedek_dogrulama.sh"

run_step 7 "Yedekleme Raporlama" "06_yedekleme_raporlama.sh"

echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  ADIM 8: Zamanlayici (Cron) Bilgisi${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "  ${BLUE}Tanimli Zamanlanmis Gorevler:${NC}"
echo -e "    ${CYAN}Gunluk 02:00${NC} -> Otomatik yedekleme"
echo -e "    ${CYAN}Gunluk 02:30${NC} -> Yedek dogrulama"
echo -e "    ${CYAN}Gunluk 03:00${NC} -> Uyari kontrolu"
echo -e "    ${CYAN}Pazar  03:30${NC} -> Haftalik yedekleme"
echo -e "    ${CYAN}Ayin 1 04:00${NC} -> Aylik yedekleme + rotasyon"
echo ""
echo -e "  ${BLUE}Cron kurmak icin:${NC}"
echo -e "    crontab $PROJECT_DIR/config/crontab_jobs.txt"
echo -e "\n  ${GREEN}Adim 8 tamamlandi${NC}"

echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║            DEMO TAMAMLANDI                       ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Calisan Moduller:${NC}"
echo -e "  ${GREEN}1.${NC} Otomasyon Altyapi  -> Ayar ve baglanti kontrolu"
echo -e "  ${GREEN}2.${NC} Otomatik Yedekleme -> pg_dump + cron entegrasyonu"
echo -e "  ${GREEN}3.${NC} Denetim Sistemi    -> DB icinde yedek kayitlari"
echo -e "  ${GREEN}4.${NC} Uyari Sistemi      -> Basarisizlik bildirimleri"
echo -e "  ${GREEN}5.${NC} Rotasyon           -> Eski yedek temizligi"
echo -e "  ${GREEN}6.${NC} Dogrulama          -> Yedek butunluk testleri"
echo -e "  ${GREEN}7.${NC} Raporlama          -> Terminal + HTML raporlar"
echo -e "  ${GREEN}8.${NC} Zamanlayici        -> Cron / launchd kurulumu"

echo -e "\n${YELLOW}Olusturulan Dosyalar:${NC}"
echo -e "  ${BLUE}Yedekler:${NC} $PROJECT_DIR/backups/"
echo -e "  ${BLUE}Loglar:${NC}   $PROJECT_DIR/logs/"
echo -e "  ${BLUE}Raporlar:${NC} $PROJECT_DIR/reports/"

echo -e "\n${GREEN}Proje 7: Veritabani Yedekleme ve Otomasyon calismasi tamamlandi!${NC}"
