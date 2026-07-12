/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File        : 01_create_database.sql
   Purpose     : Create the MySQL 8 database and establish safe session defaults.
   Compatibility: MySQL 8.0+ / MySQL Workbench
   ============================================================================ */

-- Create the database only when it does not already exist.
CREATE DATABASE IF NOT EXISTS nexora_supply_chain
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE nexora_supply_chain;

-- Recommended session settings for reliable analytical development.
SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+00:00';
SET SESSION group_concat_max_len = 1000000;

-- Metadata table used to document the warehouse build.
CREATE TABLE IF NOT EXISTS etl_run_log (
    etl_run_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    pipeline_name       VARCHAR(100) NOT NULL,
    source_file_name    VARCHAR(255) NULL,
    process_name        VARCHAR(100) NOT NULL,
    process_status      ENUM('STARTED','SUCCESS','FAILED','WARNING') NOT NULL,
    rows_read           BIGINT UNSIGNED NULL,
    rows_inserted       BIGINT UNSIGNED NULL,
    rows_rejected       BIGINT UNSIGNED NULL,
    started_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    completed_at        DATETIME(6) NULL,
    error_message       TEXT NULL,
    created_by          VARCHAR(100) NOT NULL DEFAULT 'nexora_project',
    PRIMARY KEY (etl_run_id),
    INDEX idx_etl_run_log_status (process_status),
    INDEX idx_etl_run_log_started_at (started_at)
) ENGINE=InnoDB;

-- Confirm the active database and server configuration.
SELECT DATABASE() AS active_database;
SELECT VERSION() AS mysql_version;
SHOW VARIABLES LIKE 'character_set_database';
SHOW VARIABLES LIKE 'collation_database';
SHOW VARIABLES LIKE 'local_infile';
