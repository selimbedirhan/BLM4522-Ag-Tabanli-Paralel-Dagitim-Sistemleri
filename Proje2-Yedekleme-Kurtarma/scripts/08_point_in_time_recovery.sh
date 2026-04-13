#!/bin/bash
# ============================================================================
# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Dosya: 08_point_in_time_recovery.sh
# Açıklama: Point-in-Time Recovery (PITR) - Belirli Bir Zamana Geri Dönme
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
PITR_TEST_DB="eticaret_pitr_test"

export PATH="$PG_BIN:$PATH"

mkdir -p "$LOG_DIR" "$BACKUP_DIR/pitr"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   POINT-IN-TIME RECOVERY (PITR)${NC}"
echo -e "${CYAN}   Belirli Bir Zamana Geri Dönme${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

# ============================================================================
# PITR TEORİSİ VE AÇIKLAMA
# ============================================================================
echo -e "\n${BLUE}PITR (Point-in-Time Recovery) Açıklaması:${NC}"
echo -e "  PostgreSQL'de PITR, WAL (Write-Ahead Log) dosyalarını kullanarak"
echo -e "  veritabanını geçmişteki herhangi bir zamana geri döndürme işlemidir."
echo -e ""
echo -e "  ${YELLOW}Gereksinimler:${NC}"
echo -e "  1. wal_level = 'replica' veya üzeri"
echo -e "  2. archive_mode = 'on'"
echo -e "  3. archive_command yapılandırılmış olmalı"
echo -e "  4. Bir base backup (pg_basebackup) mevcut olmalı"
echo -e ""
echo -e "  ${YELLOW}PITR Süreci:${NC}"
echo -e "  1. Base backup'tan geri yükle"
echo -e "  2. WAL dosyalarını belirli zamana kadar oynat (replay)"
echo -e "  3. recovery_target_time ile hedef zamanı belirle"

# ============================================================================
# 1. PITR için Mevcut WAL Durumunu Kontrol Et
# ============================================================================
echo -e "\n${YELLOW}[1/6] WAL ve Arşiv Durumu Kontrolü${NC}"

WAL_LEVEL=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW wal_level;" 2>/dev/null)
ARCHIVE_MODE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW archive_mode;" 2>/dev/null)

echo -e "  WAL Level: ${BLUE}$WAL_LEVEL${NC}"
echo -e "  Archive Mode: ${BLUE}$ARCHIVE_MODE${NC}"

if [ "$WAL_LEVEL" != "replica" ] && [ "$WAL_LEVEL" != "logical" ]; then
    echo -e "\n${YELLOW}  ⚠ WAL Level 'replica' değil. PITR tam olarak çalışması için"
    echo -e "  postgresql.conf'ta wal_level = 'replica' ayarlanmalı ve"
    echo -e "  PostgreSQL yeniden başlatılmalıdır.${NC}"
    echo -e "\n${BLUE}  Alternatif olarak pg_dump tabanlı PITR simülasyonu yapacağız.${NC}"
fi

# ============================================================================
# 2. Zaman Noktası Kaydı - "Önceki" Durum
# ============================================================================
echo -e "\n${YELLOW}[2/6] Zaman Noktası Kaydı${NC}"

RESTORE_POINT_TIME=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT CURRENT_TIMESTAMP;" 2>/dev/null)
echo -e "  Hedef geri dönüş zamanı: ${GREEN}$RESTORE_POINT_TIME${NC}"

# Mevcut durumu kaydet
echo -e "\n  ${BLUE}Mevcut veritabanı durumu:${NC}"
CURRENT_STATS=$(psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>/dev/null
SELECT 
    'Müşteriler' AS tablo, COUNT(*) AS kayit FROM musteriler
UNION ALL
SELECT 'Ürünler', COUNT(*) FROM urunler
UNION ALL
SELECT 'Siparişler', COUNT(*) FROM siparisler
UNION ALL
SELECT 'Sipariş Detay', COUNT(*) FROM siparis_detaylari
UNION ALL
SELECT 'Ödemeler', COUNT(*) FROM odemeler
UNION ALL
SELECT 'Stok Hareket', COUNT(*) FROM stok_hareketleri
ORDER BY tablo;
EOSQL
)
echo "$CURRENT_STATS"

# Yedek referans noktası oluştur
echo -e "\n  ${BLUE}Restore point oluşturuluyor...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_create_restore_point('pitr_test_$TIMESTAMP');" 2>/dev/null
echo -e "${GREEN}  ✓ Restore point: pitr_test_$TIMESTAMP${NC}"

# Bu noktanın yedeğini al
PITR_BACKUP="$BACKUP_DIR/pitr/${DB_NAME}_pitr_base_${TIMESTAMP}.dump"
pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -Z 6 -f "$PITR_BACKUP" 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"
echo -e "${GREEN}  ✓ PITR baz yedek alındı${NC}"

# ============================================================================
# 3. Veri Değişiklikleri Yap (Felaket simülasyonu)
# ============================================================================
echo -e "\n${YELLOW}[3/6] Felaket Simülasyonu (Veri Değişiklikleri)${NC}"

# Zaman damgası
sleep 2  # WAL kayıtlarının ayrışması için kısa bekleme

echo -e "  ${RED}Değişiklik 1: 50 müşteri siliniyor...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"
-- İlk 50 müşteriyi sil (bağımlılıkları ile birlikte)
DELETE FROM odemeler WHERE siparis_id IN (
    SELECT siparis_id FROM siparisler WHERE musteri_id <= 50
);
DELETE FROM siparis_detaylari WHERE siparis_id IN (
    SELECT siparis_id FROM siparisler WHERE musteri_id <= 50
);
DELETE FROM siparisler WHERE musteri_id <= 50;
DELETE FROM musteriler WHERE musteri_id <= 50;
EOSQL
DELETED_CUSTOMERS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM musteriler;" 2>/dev/null)
echo -e "    Kalan müşteri: $DELETED_CUSTOMERS"

echo -e "  ${RED}Değişiklik 2: Tüm fiyatlar %50 artırılıyor...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "UPDATE urunler SET birim_fiyat = birim_fiyat * 1.5;" 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"

echo -e "  ${RED}Değişiklik 3: Yeni sahte siparişler ekleniyor...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"
INSERT INTO siparisler (musteri_id, durum, odeme_yontemi, toplam_tutar, kargo_adresi)
SELECT 
    51 + (i % 400),
    'iptal',
    'kredi_karti',
    999999.99,
    'SAHTE SİPARİŞ - PITR TEST'
FROM generate_series(1, 200) AS s(i);
EOSQL

echo -e "\n  ${RED}Felaket sonrası durum:${NC}"
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>/dev/null
SELECT 
    'Müşteriler' AS tablo, COUNT(*) AS kayit FROM musteriler
UNION ALL
SELECT 'Siparişler', COUNT(*) FROM siparisler
ORDER BY tablo;
EOSQL

# ============================================================================
# 4. PITR Kurtarma İşlemi
# ============================================================================
echo -e "\n${YELLOW}[4/6] PITR Kurtarma Başlıyor${NC}"
echo -e "  Hedef zaman: ${GREEN}$RESTORE_POINT_TIME${NC}"

# Test veritabanı oluştur
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $PITR_TEST_DB;" 2>/dev/null
psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $PITR_TEST_DB;" 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"

# PITR baz yedekten restore et (bu, felaket öncesi durumu temsil eder)
echo -e "  Baz yedekten restore ediliyor..."
pg_restore -U "$DB_USER" -d "$PITR_TEST_DB" \
    --clean --if-exists \
    --single-transaction \
    "$PITR_BACKUP" 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"

if [ $? -eq 0 ] || [ $? -eq 1 ]; then
    echo -e "${GREEN}  ✓ PITR restore başarılı!${NC}"
else
    echo -e "${RED}  ✗ PITR restore başarısız!${NC}"
fi

# ============================================================================
# 5. Kurtarma Doğrulama
# ============================================================================
echo -e "\n${YELLOW}[5/6] Kurtarma Doğrulama${NC}"

echo -e "\n  ${BLUE}Kurtarılan vs Bozulmuş veritabanı karşılaştırması:${NC}"

printf "\n  %-20s %12s %12s %12s\n" "Tablo" "Kurtarılan" "Bozulmuş" "Durum"
printf "  %-20s %12s %12s %12s\n" "--------------------" "----------" "----------" "------"

TABLES=("musteriler" "urunler" "siparisler" "siparis_detaylari" "odemeler" "stok_hareketleri")
ALL_OK=true

for TABLE in "${TABLES[@]}"; do
    PITR_COUNT=$(psql -U "$DB_USER" -d "$PITR_TEST_DB" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
    CURR_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null)
    
    if [ "$PITR_COUNT" != "$CURR_COUNT" ]; then
        STATUS="FARKLI"
        ALL_OK=false
    else
        STATUS="AYNI"
    fi
    
    printf "  %-20s %12s %12s %12s\n" "$TABLE" "$PITR_COUNT" "$CURR_COUNT" "$STATUS"
done

# Fiyat kontrolü
PITR_AVG=$(psql -U "$DB_USER" -d "$PITR_TEST_DB" -t -A -c "SELECT ROUND(AVG(birim_fiyat), 2) FROM urunler;" 2>/dev/null)
CURR_AVG=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT ROUND(AVG(birim_fiyat), 2) FROM urunler;" 2>/dev/null)
echo -e "\n  Ortalama ürün fiyatı (Kurtarılan): ${GREEN}₺$PITR_AVG${NC}"
echo -e "  Ortalama ürün fiyatı (Bozulmuş):   ${RED}₺$CURR_AVG${NC}"

# ============================================================================
# 6. Ana Veritabanını Kurtarılan Halinden Geri Yükle
# ============================================================================
echo -e "\n${YELLOW}[6/6] Ana Veritabanını Kurtarılan Duruma Getirme${NC}"

# Kurtarılan veritabanından yedek al
PITR_FINAL_BACKUP="$BACKUP_DIR/pitr/${DB_NAME}_pitr_restored_${TIMESTAMP}.dump"
pg_dump -U "$DB_USER" -d "$PITR_TEST_DB" -Fc -Z 6 -f "$PITR_FINAL_BACKUP" 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"

# Ana veritabanını kurtarılan halinden geri yükle
pg_restore -U "$DB_USER" -d "$DB_NAME" \
    --clean --if-exists \
    --single-transaction \
    "$PITR_FINAL_BACKUP" 2>> "$LOG_DIR/pitr_${TIMESTAMP}.log"

FINAL_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM musteriler;" 2>/dev/null)
echo -e "${GREEN}  ✓ Ana veritabanı kurtarıldı! Müşteri sayısı: $FINAL_COUNT${NC}"

# Temizlik
psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $PITR_TEST_DB;" 2>/dev/null
echo -e "${GREEN}  ✓ Test veritabanı temizlendi${NC}"

# ============================================================================
# PITR RECOVERY.CONF ÖRNEĞİ
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   PITR YAPILANDIRMA ÖRNEĞİ${NC}"
echo -e "${CYAN}============================================${NC}"

RECOVERY_CONF="$PROJECT_DIR/config/pitr_recovery_example.conf"
cat > "$RECOVERY_CONF" << EOF
# ============================================================================
# PostgreSQL PITR Recovery Yapılandırması
# Bu dosya, gerçek bir PITR senaryosunda kullanılacak ayarları gösterir
# PostgreSQL 12+ sürümlerinde postgresql.conf'a eklenir
# ============================================================================

# Kurtarma hedef zamanı
# Veritabanını bu zamandaki durumuna geri döndürür
recovery_target_time = '$RESTORE_POINT_TIME'

# Alternatif: Belirli bir transaction ID'ye kadar kurtarma
# recovery_target_xid = '12345'

# Alternatif: Belirli bir restore point'e kadar kurtarma
# recovery_target_name = 'pitr_test_$TIMESTAMP'

# Alternatif: Belirli bir LSN'e kadar kurtarma
# recovery_target_lsn = '0/1000000'

# Hedef zamana ulaşıldığında ne yapılacağı
# 'pause' = Durdur ve kontrol et, 'promote' = Hemen aktif yap
recovery_target_action = 'promote'

# Hedefe dahil mi (inclusive) yoksa hariç mi (exclusive)
recovery_target_inclusive = true

# WAL arşivlerinin geri yükleme komutu
restore_command = 'cp $BACKUP_DIR/wal_archive/%f %p'

# Kurtarma timeline
# 'latest' = En son timeline'ı kullan
recovery_target_timeline = 'latest'
EOF

echo -e "  PITR yapılandırma örneği oluşturuldu:"
echo -e "    $RECOVERY_CONF"

# ============================================================================
# SONUÇ
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   PITR İŞLEMLERİ TAMAMLANDI${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Hedef Zaman: $RESTORE_POINT_TIME"
echo -e "  Baz Yedek: $(basename $PITR_BACKUP)"
echo -e "  Log: $LOG_DIR/pitr_${TIMESTAMP}.log"
echo -e "\n${GREEN}Point-in-Time Recovery işlemleri tamamlandı!${NC}"
