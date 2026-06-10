#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_USER=$(whoami)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  BLM4522 - Proje 4                           ║${NC}"
echo -e "${MAGENTA}║  Replikasyon ve Yuk Dengeleme                ║${NC}"
echo -e "${MAGENTA}║  PostgreSQL 14 | $(date '+%Y-%m-%d %H:%M:%S')            ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

run_step() {
    echo -e "\n${MAGENTA}━━━ ADIM $1: $2 ━━━${NC}\n"
}

run_step 1 "Primary Veritabani Olusturma"
psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/01_veritabani_olustur.sql" 2>&1 | tail -5
sleep 1

run_step 2 "Replikasyon Altyapi Kurulumu (WAL Level)"
bash "$SCRIPT_DIR/03_replikasyon_altyapi.sh" 2>&1
sleep 1

run_step 3 "Logical Replication Kurulumu (Publisher/Subscriber)"
psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/04_replikasyon_kurulum.sql" 2>&1 | tail -15
echo -e "\n  ${YELLOW}Replikasyon baslatildi. Simdi veriler eklenecek...${NC}"
sleep 1

run_step 4 "Ornek Veri Yukleme (80.000+ satir)"
echo -e "  ${BLUE}Veriler Primary'ye yuklenirken ayni anda Replica'ya akar...${NC}"
psql -U "$DB_USER" -d postgres -f "$SCRIPT_DIR/02_ornek_veri_yukle.sql" 2>&1 | tail -15
echo -e "  ${YELLOW}Replikasyon icin bekleniyor (5sn)...${NC}"
sleep 5

run_step 5 "Replikasyon Izleme Raporu"
bash "$SCRIPT_DIR/05_replikasyon_izleme.sh" 2>&1
sleep 1

run_step 6 "Yuk Dengeleme Simulasyonu"
bash "$SCRIPT_DIR/06_yuk_dengeleme.sh" 2>&1
sleep 1

run_step 7 "Failover Testi"
bash "$SCRIPT_DIR/07_failover_test.sh" 2>&1

echo -e "\n${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         DEMO TAMAMLANDI                       ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Gosterilen Konular:${NC}"
echo -e "  ${GREEN}1.${NC} Sosyal Medya DB olusturma (80.000+ kayit)"
echo -e "  ${GREEN}2.${NC} WAL level konfigurasyonu (replica → logical)"
echo -e "  ${GREEN}3.${NC} Logical Replication (Publication/Subscription)"
echo -e "  ${GREEN}4.${NC} Replikasyon izleme (slot, WAL sender, gecikme)"
echo -e "  ${GREEN}5.${NC} Veri esitleme kontrolu (Primary vs Replica)"
echo -e "  ${GREEN}6.${NC} Yuk dengeleme (Read/Write splitting)"
echo -e "  ${GREEN}7.${NC} Failover simulasyonu ve recovery"

echo -e "\n${GREEN}Proje 4 demo tamamlandi!${NC}"
