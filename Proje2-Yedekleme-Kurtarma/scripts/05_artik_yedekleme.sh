#!/bin/bash
# ============================================================================
# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Dosya: 05_artik_yedekleme.sh
# Açıklama: Artık (Incremental) Yedekleme - WAL Arşivleme
# PostgreSQL'de artık yedekleme WAL (Write-Ahead Logging) üzerinden sağlanır.
# ============================================================================

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Değişkenler
DB_NAME="eticaret_db"
DB_USER=$(whoami)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
WAL_ARCHIVE_DIR="$BACKUP_DIR/wal_archive"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_BIN="/opt/homebrew/opt/postgresql@14/bin"
PG_DATA=$(eval "$PG_BIN/psql" -U "$DB_USER" -d postgres -t -A -c "SHOW data_directory;" 2>/dev/null)

export PATH="$PG_BIN:$PATH"

mkdir -p "$WAL_ARCHIVE_DIR" "$LOG_DIR" "$BACKUP_DIR/incremental"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   ARTIK (INCREMENTAL) YEDEKLEME${NC}"
echo -e "${CYAN}   WAL Arşivleme Yapılandırması${NC}"
echo -e "${CYAN}   Tarih: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${BLUE}PostgreSQL Veri Dizini: $PG_DATA${NC}"

# ============================================================================
# 1. WAL Durumunu Kontrol Et
# ============================================================================
echo -e "\n${YELLOW}[1/5] WAL Durumu Kontrolü${NC}"

WAL_LEVEL=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW wal_level;" 2>/dev/null)
ARCHIVE_MODE=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW archive_mode;" 2>/dev/null)
ARCHIVE_COMMAND=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW archive_command;" 2>/dev/null)

echo -e "  WAL Level: ${BLUE}$WAL_LEVEL${NC}"
echo -e "  Archive Mode: ${BLUE}$ARCHIVE_MODE${NC}"
echo -e "  Archive Command: ${BLUE}${ARCHIVE_COMMAND:-'(ayarlanmamış)'}${NC}"

# ============================================================================
# 2. WAL Yapılandırma Dosyası Oluştur
# ============================================================================
echo -e "\n${YELLOW}[2/5] WAL Yapılandırma Ayarları${NC}"

WAL_CONFIG_FILE="$PROJECT_DIR/config/wal_settings.sql"
cat > "$WAL_CONFIG_FILE" << EOSQL
-- ============================================================================
-- WAL (Write-Ahead Logging) Yapılandırma Ayarları
-- Bu ayarlar postgresql.conf dosyasına eklenmeli veya ALTER SYSTEM ile uygulanmalıdır
-- ============================================================================

-- WAL seviyesini replica olarak ayarla (archive veya logical da kullanılabilir)
-- Bu ayar PITR (Point-in-Time Recovery) için gereklidir
ALTER SYSTEM SET wal_level = 'replica';

-- Arşiv modunu etkinleştir
ALTER SYSTEM SET archive_mode = 'on';

-- WAL dosyalarını arşiv dizinine kopyala
ALTER SYSTEM SET archive_command = 'cp %p $WAL_ARCHIVE_DIR/%f';

-- WAL dosya boyutu (varsayılan 16MB)
-- ALTER SYSTEM SET wal_segment_size = '16MB';  -- Derleme zamanında ayarlanır

-- Checkpoint sıklığı
ALTER SYSTEM SET checkpoint_timeout = '5min';

-- Maksimum WAL boyutu
ALTER SYSTEM SET max_wal_size = '1GB';
ALTER SYSTEM SET min_wal_size = '80MB';

-- WAL sıkıştırma
ALTER SYSTEM SET wal_compression = 'on';

-- Konfigürasyonu yeniden yükle
SELECT pg_reload_conf();
EOSQL

echo -e "${GREEN}  ✓ WAL yapılandırma dosyası oluşturuldu${NC}"
echo -e "    Dosya: $WAL_CONFIG_FILE"

# ============================================================================
# 3. WAL Ayarlarını Uygula (Dikkatli!)
# ============================================================================
echo -e "\n${YELLOW}[3/5] WAL Ayarlarını Uygulama${NC}"

# wal_level ve archive_mode değiştirmek sunucu restart gerektirir
# Burada güvenli ayarları uyguluyoruz
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL 2>> "$LOG_DIR/artik_yedekleme_${TIMESTAMP}.log"
-- WAL sıkıştırma etkinleştir (restart gerektirmez)
ALTER SYSTEM SET wal_compression = 'on';

-- Checkpoint ayarları (restart gerektirmez)
ALTER SYSTEM SET checkpoint_timeout = '5min';

-- Konfigürasyonu yeniden yükle
SELECT pg_reload_conf();

-- Mevcut WAL konumunu göster
SELECT pg_current_wal_lsn() AS mevcut_wal_konum;

-- WAL istatistikleri
SELECT 
    pg_current_wal_lsn() as wal_konum,
    pg_walfile_name(pg_current_wal_lsn()) as wal_dosya,
    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') as toplam_wal_bytes;
EOSQL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ WAL ayarları uygulandı${NC}"
else
    echo -e "${RED}  ✗ WAL ayarları uygulanamadı!${NC}"
fi

# ============================================================================
# 4. Manuel WAL Checkpoint ve Arşivleme Simülasyonu
# ============================================================================
echo -e "\n${YELLOW}[4/5] Checkpoint & WAL Simülasyonu${NC}"

# Checkpoint yap
echo -e "  ${BLUE}Checkpoint yapılıyor...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" -c "CHECKPOINT;" 2>> "$LOG_DIR/artik_yedekleme_${TIMESTAMP}.log"

# WAL konumunu kaydet (artık yedekleme referans noktası)
WAL_START=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_current_wal_lsn();" 2>/dev/null)
echo -e "  WAL Başlangıç Noktası: ${BLUE}$WAL_START${NC}"

# Test verileri ekle (WAL üretmek için)
echo -e "  ${BLUE}Test verileri ekleniyor (WAL üretmek için)...${NC}"
psql -U "$DB_USER" -d "$DB_NAME" << EOSQL >> "$LOG_DIR/artik_yedekleme_${TIMESTAMP}.log" 2>&1
-- Artık yedekleme test verileri
INSERT INTO stok_hareketleri (urun_id, hareket_tipi, miktar, aciklama, kullanici_adi)
SELECT 
    1 + (i % 200),
    'giris',
    (random() * 100)::INTEGER,
    'WAL test - artık yedekleme verisi #' || i,
    'wal_test'
FROM generate_series(1, 100) AS s(i);

-- Bazı verileri güncelle
UPDATE musteriler SET son_giris_tarihi = CURRENT_TIMESTAMP 
WHERE musteri_id <= 50;

-- Checkpoint
CHECKPOINT;
EOSQL

# WAL bitiş konumunu al
WAL_END=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_current_wal_lsn();" 2>/dev/null)
WAL_DIFF=$(psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_wal_lsn_diff('$WAL_END', '$WAL_START');" 2>/dev/null)

echo -e "  WAL Bitiş Noktası: ${BLUE}$WAL_END${NC}"
echo -e "  WAL Farkı: ${GREEN}$WAL_DIFF bytes${NC}"

# WAL bilgilerini kaydet
WAL_INFO_FILE="$BACKUP_DIR/incremental/wal_info_${TIMESTAMP}.txt"
cat > "$WAL_INFO_FILE" << EOF
# WAL Artık Yedekleme Bilgileri
# Tarih: $(date '+%Y-%m-%d %H:%M:%S')
WAL_START=$WAL_START
WAL_END=$WAL_END
WAL_DIFF_BYTES=$WAL_DIFF
DB_NAME=$DB_NAME
EOF

echo -e "${GREEN}  ✓ WAL bilgileri kaydedildi: $WAL_INFO_FILE${NC}"

# ============================================================================
# 5. pg_basebackup ile Baz Yedekleme (PITR için gerekli)
# ============================================================================
echo -e "\n${YELLOW}[5/5] pg_basebackup ile Baz Yedekleme${NC}"
BASE_BACKUP_DIR="$BACKUP_DIR/incremental/base_${TIMESTAMP}"

echo -e "  ${BLUE}pg_basebackup başlıyor...${NC}"
echo -e "  ${BLUE}(Bu işlem birkaç dakika sürebilir)${NC}"

START_TIME=$(date +%s)
pg_basebackup -U "$DB_USER" -D "$BASE_BACKUP_DIR" \
    -Ft -z -P \
    --checkpoint=fast \
    --label="eticaret_base_${TIMESTAMP}" \
    2>> "$LOG_DIR/artik_yedekleme_${TIMESTAMP}.log"

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    BACKUP_SIZE=$(du -sh "$BASE_BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN}  ✓ pg_basebackup başarılı${NC}"
    echo -e "    Dizin: $BASE_BACKUP_DIR"
    echo -e "    Boyut: $BACKUP_SIZE"
    echo -e "    Süre: ${DURATION} saniye"
    
    # Baz yedek içeriğini göster
    echo -e "\n  ${BLUE}Baz yedek dosyaları:${NC}"
    ls -lh "$BASE_BACKUP_DIR/" 2>/dev/null | while read line; do
        echo -e "    $line"
    done
else
    echo -e "${RED}  ✗ pg_basebackup BAŞARISIZ!${NC}"
    echo -e "${YELLOW}  Not: pg_basebackup için replication izni gerekebilir.${NC}"
    echo -e "${YELLOW}  pg_hba.conf dosyasında replication satırı olmalıdır.${NC}"
fi

# ============================================================================
# ÖZET
# ============================================================================
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}   ARTIK YEDEKLEME ÖZETİ${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  WAL Seviyesi: $WAL_LEVEL"
echo -e "  Arşiv Modu: $ARCHIVE_MODE"
echo -e "  WAL Aralığı: $WAL_START → $WAL_END"
echo -e "  WAL Farkı: $WAL_DIFF bytes"
echo -e "  Log: $LOG_DIR/artik_yedekleme_${TIMESTAMP}.log"
echo -e "\n${GREEN}Artık yedekleme işlemleri tamamlandı!${NC}"
echo -e "\n${YELLOW}NOT: WAL tabanlı artık yedekleme için:${NC}"
echo -e "  1. wal_level = 'replica' olmalı (restart gerekir)"
echo -e "  2. archive_mode = 'on' olmalı (restart gerekir)"
echo -e "  3. archive_command ayarlanmalı"
echo -e "  Bu ayarlar config/ dizinindeki dosyalarda belgelenmiştir."
