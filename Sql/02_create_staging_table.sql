/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File        : 02_create_staging_table.sql
   Purpose     : Create a wide staging table for the analytics-ready CSV.
   Grain       : One row = one order item.
   Compatibility: MySQL 8.0+ / MySQL Workbench

   DESIGN NOTES
   1. No business primary key or foreign key is enforced in staging.
   2. This allows duplicate and invalid source rows to be audited before loading
      dimension and fact tables.
   3. staging_row_id is a technical ingestion key.
   4. Data types are sized for the DataCo dataset and engineered features.
   ============================================================================ */

USE nexora_supply_chain;

DROP TABLE IF EXISTS stg_supply_chain;

CREATE TABLE stg_supply_chain (
    /* Technical ingestion metadata */
    staging_row_id                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    source_file_name                   VARCHAR(255) NULL,
    load_batch_id                      VARCHAR(64) NULL,
    loaded_at                          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),

    /* Original cleaned transaction fields */
    payment_type                       VARCHAR(50) NULL,
    days_for_shipping_real             SMALLINT NULL,
    days_for_shipment_scheduled        SMALLINT NULL,
    order_profit                       DECIMAL(18,4) NULL,
    sales_per_customer                 DECIMAL(18,4) NULL,
    delivery_status                    VARCHAR(50) NULL,
    late_delivery_risk                 TINYINT NULL,

    category_id                        INT NULL,
    category_name                      VARCHAR(150) NULL,

    customer_city                      VARCHAR(150) NULL,
    customer_country                   VARCHAR(100) NULL,
    customer_id                        BIGINT NULL,
    customer_segment                   VARCHAR(50) NULL,
    customer_state                     VARCHAR(100) NULL,
    customer_zipcode                   VARCHAR(30) NULL,

    department_id                      INT NULL,
    department_name                    VARCHAR(150) NULL,

    latitude                           DECIMAL(10,7) NULL,
    longitude                          DECIMAL(10,7) NULL,
    market                             VARCHAR(100) NULL,

    order_city                         VARCHAR(150) NULL,
    order_country                      VARCHAR(100) NULL,
    order_customer_id                  BIGINT NULL,
    order_date                         DATETIME NULL,
    order_id                           BIGINT NULL,
    order_item_cardprod_id             BIGINT NULL,
    order_item_discount                DECIMAL(18,4) NULL,
    order_item_discount_rate           DECIMAL(12,6) NULL,
    order_item_id                      BIGINT NULL,
    order_item_product_price           DECIMAL(18,4) NULL,
    order_item_profit_ratio            DECIMAL(18,6) NULL,
    order_item_quantity                INT NULL,
    sales                              DECIMAL(18,4) NULL,
    order_item_total                   DECIMAL(18,4) NULL,
    order_profit_per_order             DECIMAL(18,4) NULL,
    order_region                       VARCHAR(100) NULL,
    order_state                        VARCHAR(100) NULL,
    order_status                       VARCHAR(50) NULL,
    shipping_date                      DATETIME NULL,
    shipping_mode                      VARCHAR(50) NULL,

    product_card_id                    BIGINT NULL,
    product_category_id                INT NULL,
    product_name                       VARCHAR(255) NULL,
    product_price                      DECIMAL(18,4) NULL,
    product_status                     TINYINT NULL,

    /* Cleaning-stage engineered fields */
    shipping_delay_days                SMALLINT NULL,
    delivery_performance               VARCHAR(30) NULL,
    is_late_delivery                   TINYINT NULL,
    profit_margin_pct                  DECIMAL(18,6) NULL,
    gross_sales_before_discount        DECIMAL(18,4) NULL,
    profitability_status               VARCHAR(30) NULL,
    order_year                         SMALLINT NULL,
    order_quarter                      VARCHAR(10) NULL,
    order_month                        TINYINT NULL,
    order_month_name                   VARCHAR(20) NULL,
    order_week                         TINYINT NULL,
    order_day_name                     VARCHAR(20) NULL,
    order_date_key                     INT NULL,
    shipping_date_key                  INT NULL,

    /* Feature-engineering calendar fields */
    order_quarter_number               TINYINT NULL,
    order_year_month                   CHAR(7) NULL,
    order_day                          TINYINT NULL,
    is_weekend_order                   TINYINT NULL,
    shipping_year_month                CHAR(7) NULL,

    /* Feature-engineering delivery fields */
    absolute_schedule_variance_days    SMALLINT NULL,
    is_on_time_delivery                TINYINT NULL,
    shipping_efficiency_ratio          DECIMAL(18,6) NULL,
    delivery_delay_severity            VARCHAR(30) NULL,
    shipping_speed_segment             VARCHAR(30) NULL,

    /* Feature-engineering financial fields */
    discount_pct_calculated            DECIMAL(18,6) NULL,
    discount_rate_pct                  DECIMAL(18,6) NULL,
    is_profitable_item                 TINYINT NULL,
    is_loss_item                       TINYINT NULL,
    sales_value_tier                   VARCHAR(20) NULL,
    margin_band                        VARCHAR(20) NULL,
    discount_band                      VARCHAR(20) NULL,

    /* Order-level aggregate features mapped to each order item */
    order_total_sales                  DECIMAL(20,4) NULL,
    order_total_profit                 DECIMAL(20,4) NULL,
    order_total_quantity               INT NULL,
    order_item_count                   INT NULL,
    order_profit_margin_pct            DECIMAL(18,6) NULL,

    /* Customer-level aggregate features mapped to each order item */
    customer_order_count               INT NULL,
    customer_lifetime_sales            DECIMAL(20,4) NULL,
    customer_average_item_sales        DECIMAL(18,4) NULL,
    customer_lifetime_profit           DECIMAL(20,4) NULL,
    customer_first_order_date          DATETIME NULL,
    customer_last_order_date           DATETIME NULL,
    customer_tenure_days               INT NULL,
    customer_frequency_segment         VARCHAR(30) NULL,

    /* Risk and exception-management fields */
    requires_management_attention      TINYINT NULL,
    operational_risk_segment           VARCHAR(30) NULL,

    PRIMARY KEY (staging_row_id),

    INDEX idx_stg_order_item_id (order_item_id),
    INDEX idx_stg_order_id (order_id),
    INDEX idx_stg_customer_id (customer_id),
    INDEX idx_stg_product_card_id (product_card_id),
    INDEX idx_stg_order_date (order_date),
    INDEX idx_stg_shipping_date (shipping_date),
    INDEX idx_stg_category_id (category_id),
    INDEX idx_stg_market (market),
    INDEX idx_stg_load_batch_id (load_batch_id)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Staging layer for the DataCo analytics-ready order-item dataset';

/* ---------------------------------------------------------------------------
   POST-CREATION VERIFICATION
   --------------------------------------------------------------------------- */

SHOW CREATE TABLE stg_supply_chain;

SELECT
    table_schema,
    table_name,
    engine,
    table_rows,
    table_collation
FROM information_schema.tables
WHERE table_schema = 'nexora_supply_chain'
  AND table_name = 'stg_supply_chain';

SELECT
    ordinal_position,
    column_name,
    column_type,
    is_nullable,
    column_key
FROM information_schema.columns
WHERE table_schema = 'nexora_supply_chain'
  AND table_name = 'stg_supply_chain'
ORDER BY ordinal_position;
