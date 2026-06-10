#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DB_USER=$(whoami)
PRIMARY_DB="sosyal_medya_db"
REPLICA_DB="sosyal_medya_replica"
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
export PATH="$PG_BIN:$PATH"

LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

write_query() {
    local desc=$1 query=$2
    local start=$(date +%s%N)
    psql -U "$DB_USER" -d "$PRIMARY_DB" -c "$query" > /dev/null 2>&1
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    echo -e "  ${RED}[WRITE→PRIMARY]${NC} $desc (${ms}ms)"
}

read_query() {
    local desc=$1 query=$2 target=$3
    local start=$(date +%s%N)
    local result=$(psql -U "$DB_USER" -d "$target" -t -A -c "$query" 2>/dev/null)
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    if [ "$target" = "$REPLICA_DB" ]; then
        echo -e "  ${GREEN}[READ→REPLICA]${NC}  $desc (${ms}ms) → $result"
    else
        echo -e "  ${BLUE}[READ→PRIMARY]${NC} $desc (${ms}ms) → $result"
    fi
}

echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  YUK DENGELEME SIMULASYONU                   ║${NC}"
echo -e "${MAGENTA}║  Read/Write Splitting Stratejisi             ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}[1/4] Yazma Islemleri (→ Primary)${NC}"
echo -e "  ${BLUE}Tum INSERT/UPDATE/DELETE islemleri Primary'ye gider${NC}\n"

write_query "Yeni kullanici ekleme" \
    "INSERT INTO kullanicilar (kullanici_adi, email, ad, soyad, sifre_hash, sehir)
     VALUES ('lb_test_user', 'lbtest@test.com', 'Test', 'User', md5('test'), 'Istanbul')
     ON CONFLICT (kullanici_adi) DO UPDATE SET son_giris = NOW();"

write_query "Yeni gonderi ekleme" \
    "INSERT INTO gonderiler (kullanici_id, icerik, medya_tipi)
     VALUES (1, 'Yuk dengeleme testi! 🔄 #loadbalancing', 'yok');"

write_query "Begeni ekleme" \
    "INSERT INTO begeniler (kullanici_id, gonderi_id)
     SELECT 2, MAX(gonderi_id) FROM gonderiler;"

write_query "Gonderi guncelleme" \
    "UPDATE gonderiler SET begeni_sayisi = begeni_sayisi + 1
     WHERE gonderi_id = (SELECT MAX(gonderi_id) FROM gonderiler);"

echo -e "\n  ${YELLOW}Replikasyon bekleniyor (2sn)...${NC}"
sleep 2

echo -e "\n${YELLOW}[2/4] Okuma Islemleri (→ Replica)${NC}"
echo -e "  ${BLUE}Tum SELECT islemleri Replica'ya yonlendirilir${NC}\n"

read_query "Kullanici sayisi" \
    "SELECT COUNT(*) FROM kullanicilar;" "$REPLICA_DB"

read_query "Gonderi sayisi" \
    "SELECT COUNT(*) FROM gonderiler;" "$REPLICA_DB"

read_query "Populer sehirler" \
    "SELECT sehir||':'||COUNT(*) FROM kullanicilar GROUP BY sehir ORDER BY COUNT(*) DESC LIMIT 3;" "$REPLICA_DB"

read_query "Son 5 gonderi" \
    "SELECT COUNT(*) FROM gonderiler WHERE olusturma_tarihi > NOW() - INTERVAL '1 hour';" "$REPLICA_DB"

read_query "Trend hashtagler" \
    "SELECT hashtag||':'||kullanim_sayisi FROM hashtagler ORDER BY kullanim_sayisi DESC LIMIT 3;" "$REPLICA_DB"

echo -e "\n${YELLOW}[3/4] Karsilastirmali Benchmark${NC}"
echo -e "  ${BLUE}Ayni sorgunun Primary ve Replica uzerindeki performansi${NC}\n"

QUERIES=(
    "SELECT COUNT(*) FROM gonderiler g JOIN kullanicilar k ON g.kullanici_id = k.kullanici_id"
    "SELECT sehir, COUNT(*) FROM kullanicilar GROUP BY sehir ORDER BY COUNT(*) DESC LIMIT 10"
    "SELECT k.kullanici_adi, COUNT(g.gonderi_id) FROM kullanicilar k LEFT JOIN gonderiler g ON k.kullanici_id = g.kullanici_id GROUP BY k.kullanici_adi ORDER BY COUNT(g.gonderi_id) DESC LIMIT 5"
)
QUERY_NAMES=(
    "Gonderi-Kullanici JOIN"
    "Sehir bazli gruplama"
    "En aktif kullanicilar"
)

printf "\n  ${BLUE}%-30s %12s %12s${NC}\n" "Sorgu" "Primary" "Replica"
printf "  %-30s %12s %12s\n" "──────────────────────────────" "────────────" "────────────"

for i in "${!QUERIES[@]}"; do
    PS=$(date +%s%N)
    psql -U "$DB_USER" -d "$PRIMARY_DB" -c "${QUERIES[$i]}" > /dev/null 2>&1
    PE=$(date +%s%N)
    P_MS=$(( (PE - PS) / 1000000 ))

    RS=$(date +%s%N)
    psql -U "$DB_USER" -d "$REPLICA_DB" -c "${QUERIES[$i]}" > /dev/null 2>&1
    RE=$(date +%s%N)
    R_MS=$(( (RE - RS) / 1000000 ))

    printf "  %-30s %10s ms %10s ms\n" "${QUERY_NAMES[$i]}" "$P_MS" "$R_MS"
done

echo -e "\n${YELLOW}[4/4] Yuk Dengeleme Stratejisi Ozeti${NC}"

echo -e "\n  ${MAGENTA}┌──────────────────────────────────────────┐${NC}"
echo -e "  ${MAGENTA}│        YUK DENGELEME MIMARISI            │${NC}"
echo -e "  ${MAGENTA}├──────────────────────────────────────────┤${NC}"
echo -e "  ${MAGENTA}│                                          │${NC}"
echo -e "  ${MAGENTA}│    Uygulama Katmani                      │${NC}"
echo -e "  ${MAGENTA}│         │                                │${NC}"
echo -e "  ${MAGENTA}│    ┌────┴────┐                           │${NC}"
echo -e "  ${MAGENTA}│    │ Router  │  (Connection Pool)        │${NC}"
echo -e "  ${MAGENTA}│    └────┬────┘                           │${NC}"
echo -e "  ${MAGENTA}│    ┌────┴─────────────┐                  │${NC}"
echo -e "  ${MAGENTA}│    │                  │                  │${NC}"
echo -e "  ${MAGENTA}│ ${RED}WRITE${MAGENTA}              ${GREEN}READ${MAGENTA}                │${NC}"
echo -e "  ${MAGENTA}│ (INSERT/UPDATE)    (SELECT)              │${NC}"
echo -e "  ${MAGENTA}│    │                  │                  │${NC}"
echo -e "  ${MAGENTA}│    ▼                  ▼                  │${NC}"
echo -e "  ${MAGENTA}│ ${RED}[PRIMARY]${MAGENTA}          ${GREEN}[REPLICA]${MAGENTA}             │${NC}"
echo -e "  ${MAGENTA}│ sosyal_medya_db   sosyal_medya_replica   │${NC}"
echo -e "  ${MAGENTA}│         │                  ▲             │${NC}"
echo -e "  ${MAGENTA}│         └──── Replikasyon ─┘             │${NC}"
echo -e "  ${MAGENTA}│              (Logical)                   │${NC}"
echo -e "  ${MAGENTA}└──────────────────────────────────────────┘${NC}"

echo -e "\n  ${BLUE}Avantajlar:${NC}"
echo -e "    • Okuma yuku dagitilir (Primary uzerinden yuklenir)"
echo -e "    • Primary sadece yazma islemleriyle ilgilenir"
echo -e "    • Replica read-only oldugu icin daha hizli SELECT"
echo -e "    • Birden fazla replica eklenebilir (scale-out)"

echo -e "\n${GREEN}Yuk dengeleme simulasyonu tamamlandi!${NC}"
