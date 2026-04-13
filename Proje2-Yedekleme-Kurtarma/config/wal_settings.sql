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
ALTER SYSTEM SET archive_command = 'cp %p /Users/selimbedirhanozturk/Desktop/DERSLER/BLM4522 Ağ Tabanlı Paralel Dağıtım Sistemleri/Proje2-Yedekleme-Kurtarma/backups/wal_archive/%f';

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
