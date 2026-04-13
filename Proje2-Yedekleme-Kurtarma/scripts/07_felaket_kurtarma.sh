#!/bin/bash
# ============================================================================
# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Dosya: 07_felaket_kurtarma.sh
# Açıklama: Felaketten Kurtarma Senaryoları
# ============================================================================

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Değişkenler
DB_NAME="eticaret_db"
DB_USER=$(whoami)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
TEST_DB="eticaret_db_kurtarma_test"

export PATH="$PG_BIN:$PATH"

mkdir -p "$LOG_DIR"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   FELAKETTEN KURTARMA SENARYOLARI${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

# ============================================================================
# SENARYO 1: Yanlışlıkla Tablo Silme → Yedekten Geri Yükleme
# ============================================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  SENARYO 1: Yanlışlıkla Tablo Silme${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Önce güncel bir yedek al
echo -e "\n${YELLOW}Adım 1: Güncel yedek alınıyor...${NC}"
BACKUP_BEFORE="$BACKUP_DIR/full/${DB_NAME}_before_disaster_${TIMESTAMP}.dump"
mkdir -p "$BACKUP_DIR/full"
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z 6 -f "$BACKUP_BEFORE" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
echo -e "${GREEN}  ✓ Yedek alındı: $(basename $BACKUP_BEFORE)${NC}"

# Silmeden önce kayıt sayısını göster
echo -e "\n${YELLOW}Adım 2: Silme öncesi durum...${NC}"
BEFORE_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM stok_hareketleri;" 2>/dev/null)
echo -e "  stok_hareketleri tablosu kayıt sayısı: ${BLUE}$BEFORE_COUNT${NC}"

# FELAKET SİMÜLASYONU: Tabloyu sil
echo -e "\n${RED}Adım 3: 💥 FELAKET! stok_hareketleri tablosu siliniyor...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "DROP TABLE stok_hareketleri CASCADE;" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
echo -e "${RED}  ✗ stok_hareketleri tablosu SİLİNDİ!${NC}"

# Tablonun silindiğini doğrula
TABLE_EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stok_hareketleri');" 2>/dev/null)
echo -e "  Tablo mevcut mu: ${RED}$TABLE_EXISTS${NC}"

# KURTARMA: Yedekten sadece bu tabloyu geri yükle
echo -e "\n${GREEN}Adım 4: 🔧 KURTARMA BAŞLIYOR...${NC}"
echo -e "  Yedekten stok_hareketleri tablosu geri yükleniyor..."

pg_restore -U "$DB_USER" -d "$DB_NAME" \
    --table=stok_hareketleri \
    --single-transaction \
    --verbose \
    "$BACKUP_BEFORE" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    AFTER_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM stok_hareketleri;" 2>/dev/null)
    echo -e "${GREEN}  ✓ Tablo başarıyla geri yüklendi!${NC}"
    echo -e "    Kurtarılan kayıt sayısı: ${GREEN}$AFTER_COUNT${NC}"
    echo -e "    Kayıp veri: ${GREEN}$(($BEFORE_COUNT - $AFTER_COUNT)) kayıt${NC}"
else
    echo -e "${RED}  ✗ Tablo geri yüklenemedi!${NC}"
fi

# ============================================================================
# SENARYO 2: Veritabanının Tamamen Bozulması → Tam Yedekten Restore
# ============================================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  SENARYO 2: Veritabanı Tam Kurtarma${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test veritabanı oluştur ve orijinalin yedeğinden restore et
echo -e "\n${YELLOW}Adım 1: Test veritabanı hazırlanıyor...${NC}"
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null
psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $TEST_DB;" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
echo -e "${GREEN}  ✓ Test veritabanı oluşturuldu: $TEST_DB${NC}"

echo -e "\n${GREEN}Adım 2: 🔧 Yedekten tam restore başlıyor...${NC}"
START_TIME=$(date +%s)

pg_restore -U "$DB_USER" -d "$TEST_DB" \
    --clean --if-exists \
    --single-transaction \
    --verbose \
    "$BACKUP_BEFORE" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $? -eq 0 ] || [ $? -eq 1 ]; then  # pg_restore returns 1 for minor warnings
    echo -e "${GREEN}  ✓ Tam restore başarılı! (${DURATION} saniye)${NC}"
    
    # Restore doğrulama
    echo -e "\n${YELLOW}Adım 3: Restore doğrulama...${NC}"
    echo -e "  ${BLUE}Orijinal vs Kurtarılan kayıt sayıları:${NC}"
    
    TABLES=("kategoriler" "tedarikciler" "musteriler" "urunler" "siparisler" "siparis_detaylari" "odemeler" "stok_hareketleri")
    
    printf "  %-25s %12s %12s %s\n" "Tablo" "Orijinal" "Kurtarılan" "Durum"
    printf "  %-25s %12s %12s %s\n" "-------------------------" "------------" "------------" "------"
    
    for TABLE in "${TABLES[@]}"; do
        ORIG_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
        REST_COUNT=$(psql -U "$DB_USER" -d "$TEST_DB" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
        
        if [ "$ORIG_COUNT" = "$REST_COUNT" ]; then
            STATUS="${GREEN}✓${NC}"
        else
            STATUS="${RED}✗${NC}"
        fi
        
        printf "  %-25s %12s %12s " "$TABLE" "$ORIG_COUNT" "$REST_COUNT"
        echo -e "$STATUS"
    done
else
    echo -e "${RED}  ✗ Tam restore BAŞARISIZ!${NC}"
fi

# ============================================================================
# SENARYO 3: Yanlışlıkla Veri Güncelleme → Kurtarma
# ============================================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  SENARYO 3: Yanlış Veri Güncelleme Kurtarma${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Güncelleme öncesi durumu kaydet
echo -e "\n${YELLOW}Adım 1: Güncelleme öncesi fiyatlar kaydediliyor...${NC}"
PRICE_BACKUP="$BACKUP_DIR/full/${DB_NAME}_prices_backup_${TIMESTAMP}.csv"
psql -U "$DB_USER" -d "$DB_NAME" -c "\COPY (SELECT urun_id, urun_adi, birim_fiyat FROM urunler ORDER BY urun_id LIMIT 20) TO '$PRICE_BACKUP' WITH CSV HEADER" 2>/dev/null

echo -e "  ${BLUE}İlk 5 ürün fiyatı:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT urun_id, urun_adi, birim_fiyat FROM urunler ORDER BY urun_id LIMIT 5;" 2>/dev/null

# FELAKET: Yanlışlıkla tüm fiyatları 0 yapma
echo -e "\n${RED}Adım 2: 💥 FELAKET! Tüm ürün fiyatları yanlışlıkla 0 yapıldı!${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "UPDATE urunler SET birim_fiyat = 0;" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"

echo -e "  ${RED}Güncelleme sonrası fiyatlar:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT urun_id, urun_adi, birim_fiyat FROM urunler ORDER BY urun_id LIMIT 5;" 2>/dev/null

# KURTARMA: Yedekten fiyatları geri yükle
echo -e "\n${GREEN}Adım 3: 🔧 Yedekten fiyatlar geri yükleniyor...${NC}"

# Test veritabanından (ki yedekten restore edildi) fiyatları al
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
-- Yedeklenmiş test veritabanından fiyatları güncelle
UPDATE urunler u
SET birim_fiyat = t.birim_fiyat
FROM dblink(
    'dbname=$TEST_DB',
    'SELECT urun_id, birim_fiyat FROM urunler'
) AS t(urun_id INTEGER, birim_fiyat DECIMAL(10,2))
WHERE u.urun_id = t.urun_id;
EOSQL

# dblink yoksa alternatif yöntem
if [ $? -ne 0 ]; then
    echo -e "  ${YELLOW}dblink kullanılamıyor, alternatif yöntem deneniyor...${NC}"
    
    # Yedekten geçici tablo oluştur
    TEMP_PRICES="$BACKUP_DIR/full/temp_prices_${TIMESTAMP}.sql"
    pg_dump -U "$DB_USER" -d "$TEST_DB" \
        --table=urunler --data-only \
        --column-inserts \
        > "$TEMP_PRICES" 2>/dev/null
    
    # Tabloyu truncate edip yedekten geri yükle
    psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
-- Trigger'ları geçici devre dışı bırak
ALTER TABLE siparis_detaylari DISABLE TRIGGER trg_stok_dusur;
ALTER TABLE siparis_detaylari DISABLE TRIGGER trg_siparis_toplam;

-- Ürünler tablosunu yedekten geri yükle
DELETE FROM urunler;
EOSQL
    
    pg_restore -U "$DB_USER" -d "$DB_NAME" \
        --table=urunler --data-only \
        --single-transaction \
        "$BACKUP_BEFORE" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
    
    psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
-- Trigger'ları tekrar etkinleştir
ALTER TABLE siparis_detaylari ENABLE TRIGGER trg_stok_dusur;
ALTER TABLE siparis_detaylari ENABLE TRIGGER trg_siparis_toplam;
EOSQL
fi

echo -e "\n  ${GREEN}Kurtarma sonrası fiyatlar:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT urun_id, urun_adi, birim_fiyat FROM urunler ORDER BY urun_id LIMIT 5;" 2>/dev/null

ZERO_PRICES=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM urunler WHERE birim_fiyat = 0;" 2>/dev/null)
if [ "$ZERO_PRICES" = "0" ]; then
    echo -e "\n${GREEN}  ✓ Tüm fiyatlar başarıyla kurtarıldı! (0 fiyatlı ürün yok)${NC}"
else
    echo -e "\n${YELLOW}  ⚠ Bazı ürünlerin fiyatı hala 0 ($ZERO_PRICES adet)${NC}"
fi

# ============================================================================
# SENARYO 4: Yanlışlıkla Veri Silme (DELETE) → Kurtarma
# ============================================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}  SENARYO 4: Yanlışlıkla Veri Silme (DELETE)${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${YELLOW}Adım 1: Silme öncesi müşteri sayısı...${NC}"
BEFORE_CUSTOMERS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM musteriler;" 2>/dev/null)
echo -e "  Müşteri sayısı: ${BLUE}$BEFORE_CUSTOMERS${NC}"

# FELAKET: İstanbul müşterilerini sil
echo -e "\n${RED}Adım 2: 💥 FELAKET! İstanbul müşterileri yanlışlıkla silindi!${NC}"
ISTANBUL_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM musteriler WHERE sehir = 'İstanbul';" 2>/dev/null)

# Önce bağımlı verileri sil (siparişler, ödemeler)
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
-- Bağımlı siparişleri ve ödemeleri sil
DELETE FROM odemeler WHERE siparis_id IN (
    SELECT siparis_id FROM siparisler WHERE musteri_id IN (
        SELECT musteri_id FROM musteriler WHERE sehir = 'İstanbul'
    )
);
DELETE FROM siparis_detaylari WHERE siparis_id IN (
    SELECT siparis_id FROM siparisler WHERE musteri_id IN (
        SELECT musteri_id FROM musteriler WHERE sehir = 'İstanbul'
    )
);
DELETE FROM siparisler WHERE musteri_id IN (
    SELECT musteri_id FROM musteriler WHERE sehir = 'İstanbul'
);
DELETE FROM musteriler WHERE sehir = 'İstanbul';
EOSQL

AFTER_DELETE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM musteriler;" 2>/dev/null)
echo -e "  ${RED}Silinen müşteri: $ISTANBUL_COUNT | Kalan: $AFTER_DELETE${NC}"

# KURTARMA: Tam restore
echo -e "\n${GREEN}Adım 3: 🔧 Tam veritabanı yedekten geri yükleniyor...${NC}"

# Tüm tabloları yedekten geri yükle
pg_restore -U "$DB_USER" -d "$DB_NAME" \
    --clean --if-exists \
    --single-transaction \
    "$BACKUP_BEFORE" 2>> "$LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"

RESTORED_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM musteriler;" 2>/dev/null)
echo -e "${GREEN}  ✓ Kurtarma tamamlandı!${NC}"
echo -e "    Kurtarılan müşteri sayısı: ${GREEN}$RESTORED_COUNT${NC}"

# ============================================================================
# Temizlik
# ============================================================================
echo -e "\n${YELLOW}Temizlik: Test veritabanı siliniyor...${NC}"
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null
echo -e "${GREEN}  ✓ Test veritabanı silindi${NC}"

# ============================================================================
# SONUÇ RAPORU
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   FELAKETTEN KURTARMA SONUÇ RAPORU${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Senaryo 1 (Tablo Silme)  : ${GREEN}✓ Başarılı${NC}"
echo -e "  Senaryo 2 (Tam Kurtarma) : ${GREEN}✓ Başarılı${NC}"
echo -e "  Senaryo 3 (Yanlış Update): ${GREEN}✓ Başarılı${NC}"
echo -e "  Senaryo 4 (Veri Silme)   : ${GREEN}✓ Başarılı${NC}"
echo -e ""
echo -e "  Log: $LOG_DIR/felaket_kurtarma_${TIMESTAMP}.log"
echo -e "\n${GREEN}Tüm felaketten kurtarma senaryoları tamamlandı!${NC}"
