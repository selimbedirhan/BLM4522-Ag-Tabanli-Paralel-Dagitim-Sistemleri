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

PASS=0; FAIL=0

test_r() {
    local name=$1 result=$2
    if [ "$result" -eq 0 ]; then
        echo -e "  ${GREEN}GECTI${NC}: $name"; PASS=$((PASS+1))
    else
        echo -e "  ${RED}KALDI${NC}: $name"; FAIL=$((FAIL+1))
    fi
}

echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  FAILOVER ve REPLIKASYON TESTI              ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}[Test 1] Replikasyon Altyapi Kontrolu${NC}"

WAL=$(psql -U "$DB_USER" -d postgres -t -A -c "SHOW wal_level;" 2>/dev/null)
[ "$WAL" = "logical" ] && test_r "WAL level = logical" 0 || test_r "WAL level = logical (mevcut: $WAL)" 1

PUB=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "SELECT COUNT(*) FROM pg_publication WHERE pubname='pub_sosyal_medya';" 2>/dev/null)
[ "$PUB" = "1" ] && test_r "Publication mevcut" 0 || test_r "Publication mevcut" 1

SUB=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "SELECT COUNT(*) FROM pg_subscription WHERE subname='sub_sosyal_medya';" 2>/dev/null)
[ "$SUB" = "1" ] && test_r "Subscription mevcut" 0 || test_r "Subscription mevcut" 1

SLOT=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "SELECT COUNT(*) FROM pg_replication_slots WHERE active;" 2>/dev/null)
[ "${SLOT:-0}" -gt 0 ] && test_r "Replication slot aktif" 0 || test_r "Replication slot aktif (mevcut: ${SLOT:-0})" 1

echo -e "\n${YELLOW}[Test 2] Canli Veri Replikasyon Testi${NC}"

echo -e "  ${BLUE}Primary'ye test verisi ekleniyor...${NC}"
TEST_ID="failover_test_${TIMESTAMP}"
psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    INSERT INTO kullanicilar (kullanici_adi, email, ad, soyad, sifre_hash, sehir)
    VALUES ('$TEST_ID', '${TEST_ID}@test.com', 'Failover', 'Test', md5('test'), 'Ankara')
    ON CONFLICT (kullanici_adi) DO NOTHING;
" > /dev/null 2>&1

echo -e "  ${YELLOW}Replikasyon bekleniyor...${NC}"
sleep 3

REP_EXISTS=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "
    SELECT COUNT(*) FROM kullanicilar WHERE kullanici_adi = '$TEST_ID';
" 2>/dev/null)
[ "${REP_EXISTS:-0}" -gt 0 ] && test_r "Yeni kayit replikalandi" 0 || test_r "Yeni kayit replikalandi" 1

psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    UPDATE kullanicilar SET sehir = 'Istanbul', dogrulanmis = TRUE
    WHERE kullanici_adi = '$TEST_ID';
" > /dev/null 2>&1
sleep 2

REP_CITY=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "
    SELECT sehir FROM kullanicilar WHERE kullanici_adi = '$TEST_ID';
" 2>/dev/null)
[ "$REP_CITY" = "Istanbul" ] && test_r "UPDATE replikalandi (sehir=$REP_CITY)" 0 || test_r "UPDATE replikasyonu (sehir=$REP_CITY)" 1

echo -e "\n${YELLOW}[Test 3] Tablo Bazli Esitleme${NC}"

for tbl in kullanicilar gonderiler yorumlar begeniler takipler mesajlar bildirimler hashtagler gonderi_hashtag; do
    P=$(psql -U "$DB_USER" -d "$PRIMARY_DB" -t -A -c "SELECT COUNT(*) FROM $tbl;" 2>/dev/null)
    R=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "SELECT COUNT(*) FROM $tbl;" 2>/dev/null)
    [ "$P" = "$R" ] && test_r "$tbl: Primary=$P = Replica=$R" 0 || test_r "$tbl: Primary=$P != Replica=$R" 1
done

echo -e "\n${YELLOW}[Test 4] Replica Read-Only Kontrolu${NC}"

psql -U "$DB_USER" -d "$REPLICA_DB" -c "SELECT COUNT(*) FROM kullanicilar;" > /dev/null 2>&1
test_r "Replica'dan SELECT basarili" $?

echo -e "  ${BLUE}[BILGI] Logical replication subscriber yazilabilir ama best practice: sadece okuma${NC}"

echo -e "\n${YELLOW}[Test 5] Failover Senaryo Analizi${NC}"

echo -e "  ${BLUE}Failover proseduru (Primary cokerse):${NC}"
echo -e "    1. Primary ariza tespiti"
echo -e "    2. Subscription durdur (ALTER SUBSCRIPTION ... DISABLE)"
echo -e "    3. Uygulama Replica'ya yonlendir"
echo -e "    4. Replica'yi yeni Primary olarak kullan"
echo -e "    5. Subscription sil ve yeni publication olustur"
echo -e "    6. Eski Primary kurtarilinca yeni Replica olarak ekle"

echo -e "\n  ${YELLOW}Failover simulasyonu...${NC}"

psql -U "$DB_USER" -d "$REPLICA_DB" -c "ALTER SUBSCRIPTION sub_sosyal_medya DISABLE;" > /dev/null 2>&1
test_r "Subscription durduruldu (failover basladi)" $?

sleep 1

echo -e "  ${BLUE}Replica bagimsiz calisiyor (Primary bagimsilandı)${NC}"

R_OK=$(psql -U "$DB_USER" -d "$REPLICA_DB" -t -A -c "SELECT COUNT(*) FROM gonderiler;" 2>/dev/null)
[ "${R_OK:-0}" -gt 0 ] && test_r "Replica bagimsiz sorgu basarili ($R_OK gonderi)" 0 || test_r "Replica bagimsiz sorgu" 1

psql -U "$DB_USER" -d "$REPLICA_DB" -c "ALTER SUBSCRIPTION sub_sosyal_medya ENABLE;" > /dev/null 2>&1
test_r "Subscription tekrar baslatildi (recovery)" $?
sleep 2

TOTAL=$((PASS + FAIL))
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   TEST SONUCLARI${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Toplam: $TOTAL | Gecti: ${GREEN}$PASS${NC} | Kaldi: ${RED}$FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}TUM TESTLER BASARILI!${NC}"
else
    echo -e "  ${YELLOW}$FAIL test basarisiz - replikasyon durumunu kontrol edin${NC}"
fi

psql -U "$DB_USER" -d "$PRIMARY_DB" -c "
    DELETE FROM kullanicilar WHERE kullanici_adi LIKE 'failover_test_%';
    DELETE FROM kullanicilar WHERE kullanici_adi = 'lb_test_user';
" > /dev/null 2>&1

echo -e "\n${GREEN}Failover testi tamamlandi!${NC}"
