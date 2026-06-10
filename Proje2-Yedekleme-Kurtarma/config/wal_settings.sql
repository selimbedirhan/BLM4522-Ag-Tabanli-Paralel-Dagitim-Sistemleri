
ALTER SYSTEM SET wal_level = 'replica';

ALTER SYSTEM SET archive_mode = 'on';

ALTER SYSTEM SET archive_command = 'cp %p /Users/selimbedirhanozturk/Desktop/DERSLER/BLM4522 Ağ Tabanlı Paralel Dağıtım Sistemleri/Proje2-Yedekleme-Kurtarma/backups/wal_archive/%f';

ALTER SYSTEM SET checkpoint_timeout = '5min';

ALTER SYSTEM SET max_wal_size = '1GB';
ALTER SYSTEM SET min_wal_size = '80MB';

ALTER SYSTEM SET wal_compression = 'on';

SELECT pg_reload_conf();
