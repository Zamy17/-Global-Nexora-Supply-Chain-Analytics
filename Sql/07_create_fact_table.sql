/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 07_create_fact_table.sql
   Purpose       : Create the central fact table for the supply-chain star schema.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   FACT GRAIN
   One row = one order item.

   REQUIRED DIMENSIONS
   - dim_customer
   - dim_product
   - dim_category
   - dim_date
   - dim_shipping_mode
   - dim_geography

   DESIGN NOTES
   - fact_order_item_key is the technical surrogate primary key.
   - order_item_id is the source business key and must remain unique.
   - Unknown dimension members use surrogate key 0.
   - order_id is retained as a degenerate dimension for order-level analysis.
   - The script recreates the fact table for development use.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

/* ---------------------------------------------------------------------------
   PRE-CREATION CHECK
   All required dimension tables must exist.
   --------------------------------------------------------------------------- */
SELECT
    required_table.table_name,
    CASE
        WHEN actual_table.table_name IS NOT NULL THEN 'FOUND'
        ELSE 'MISSING'
    END AS table_status
FROM (
    SELECT 'dim_customer' AS table_name
    UNION ALL SELECT 'dim_product'
    UNION ALL SELECT 'dim_category'
    UNION ALL SELECT 'dim_date'
    UNION ALL SELECT 'dim_shipping_mode'
    UNION ALL SELECT 'dim_geography'
) AS required_table
LEFT JOIN information_schema.tables AS actual_table
    ON actual_table.table_schema = DATABASE()
   AND actual_table.table_name = required_table.table_name
ORDER BY required_table.table_name;

/* Development rebuild.
   Do not run this DROP statement in production without an approved migration. */
DROP TABLE IF EXISTS fact_order_item;

CREATE TABLE fact_order_item (
    /* Technical fact key */
    fact_order_item_key               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    /* Foreign keys to conformed dimensions */
    customer_key                      INT UNSIGNED NOT NULL DEFAULT 0,
    product_key                       INT UNSIGNED NOT NULL DEFAULT 0,
    category_key                      INT UNSIGNED NOT NULL DEFAULT 0,
    order_date_key                    INT NOT NULL DEFAULT 0,
    shipping_date_key                 INT NOT NULL DEFAULT 0,
    shipping_mode_key                 SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    geography_key                     INT UNSIGNED NOT NULL DEFAULT 0,

    /* Degenerate/source transaction identifiers */
    order_item_id                     BIGINT NOT NULL,
    order_id                          BIGINT NULL,
    order_customer_id                 BIGINT NULL,
    order_item_cardprod_id            BIGINT NULL,

    /* Transaction descriptors */
    payment_type                      VARCHAR(50) NULL,
    order_status                      VARCHAR(50) NULL,
    delivery_status                   VARCHAR(50) NULL,
    delivery_performance              VARCHAR(30) NULL,
    profitability_status              VARCHAR(30) NULL,
    operational_risk_segment          VARCHAR(30) NULL,

    /* Quantity and financial measures */
    order_item_quantity               INT NULL,
    sales                             DECIMAL(18,4) NULL,
    gross_sales_before_discount       DECIMAL(18,4) NULL,
    order_item_discount               DECIMAL(18,4) NULL,
    order_item_discount_rate          DECIMAL(12,6) NULL,
    discount_rate_pct                 DECIMAL(18,6) NULL,
    discount_pct_calculated           DECIMAL(18,6) NULL,
    order_item_product_price          DECIMAL(18,4) NULL,
    order_item_total                  DECIMAL(18,4) NULL,
    order_profit                      DECIMAL(18,4) NULL,
    order_profit_per_order            DECIMAL(18,4) NULL,
    order_item_profit_ratio           DECIMAL(18,6) NULL,
    profit_margin_pct                 DECIMAL(18,6) NULL,

    /* Shipping and service-level measures */
    days_for_shipping_real            SMALLINT NULL,
    days_for_shipment_scheduled       SMALLINT NULL,
    shipping_delay_days               SMALLINT NULL,
    absolute_schedule_variance_days   SMALLINT NULL,
    shipping_efficiency_ratio         DECIMAL(18,6) NULL,

    /* Binary performance flags */
    late_delivery_risk                TINYINT NULL,
    is_late_delivery                  TINYINT NULL,
    is_on_time_delivery               TINYINT NULL,
    is_profitable_item                TINYINT NULL,
    is_loss_item                      TINYINT NULL,
    requires_management_attention     TINYINT NULL,

    /* Analytical segmentation attributes */
    delivery_delay_severity           VARCHAR(30) NULL,
    shipping_speed_segment            VARCHAR(30) NULL,
    sales_value_tier                  VARCHAR(20) NULL,
    margin_band                       VARCHAR(20) NULL,
    discount_band                     VARCHAR(20) NULL,

    /* Order-level engineered measures repeated at item grain */
    order_total_sales                 DECIMAL(20,4) NULL,
    order_total_profit                DECIMAL(20,4) NULL,
    order_total_quantity              INT NULL,
    order_item_count                  INT NULL,
    order_profit_margin_pct           DECIMAL(18,6) NULL,

    /* ETL lineage */
    source_staging_row_id             BIGINT UNSIGNED NULL,
    source_file_name                  VARCHAR(255) NULL,
    load_batch_id                     VARCHAR(64) NULL,
    warehouse_loaded_at               DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    warehouse_updated_at              DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                                   ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (fact_order_item_key),
    UNIQUE KEY uk_fact_order_item_id (order_item_id),

    KEY idx_fact_order_id (order_id),
    KEY idx_fact_customer_key (customer_key),
    KEY idx_fact_product_key (product_key),
    KEY idx_fact_category_key (category_key),
    KEY idx_fact_order_date_key (order_date_key),
    KEY idx_fact_shipping_date_key (shipping_date_key),
    KEY idx_fact_shipping_mode_key (shipping_mode_key),
    KEY idx_fact_geography_key (geography_key),
    KEY idx_fact_load_batch_id (load_batch_id),
    KEY idx_fact_order_date_customer (order_date_key, customer_key),
    KEY idx_fact_category_product (category_key, product_key),
    KEY idx_fact_delivery_flags (is_late_delivery, is_on_time_delivery),
    KEY idx_fact_profit_flags (is_profitable_item, is_loss_item),

    CONSTRAINT fk_fact_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer (customer_key),

    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_key)
        REFERENCES dim_product (product_key),

    CONSTRAINT fk_fact_category
        FOREIGN KEY (category_key)
        REFERENCES dim_category (category_key),

    CONSTRAINT fk_fact_order_date
        FOREIGN KEY (order_date_key)
        REFERENCES dim_date (date_key),

    CONSTRAINT fk_fact_shipping_date
        FOREIGN KEY (shipping_date_key)
        REFERENCES dim_date (date_key),

    CONSTRAINT fk_fact_shipping_mode
        FOREIGN KEY (shipping_mode_key)
        REFERENCES dim_shipping_mode (shipping_mode_key),

    CONSTRAINT fk_fact_geography
        FOREIGN KEY (geography_key)
        REFERENCES dim_geography (geography_key),

    CONSTRAINT chk_fact_quantity
        CHECK (order_item_quantity IS NULL OR order_item_quantity > 0),

    CONSTRAINT chk_fact_shipping_days_real
        CHECK (days_for_shipping_real IS NULL OR days_for_shipping_real >= 0),

    CONSTRAINT chk_fact_shipping_days_scheduled
        CHECK (
            days_for_shipment_scheduled IS NULL
            OR days_for_shipment_scheduled >= 0
        ),

    CONSTRAINT chk_fact_late_delivery_risk
        CHECK (late_delivery_risk IS NULL OR late_delivery_risk IN (0, 1)),

    CONSTRAINT chk_fact_is_late
        CHECK (is_late_delivery IS NULL OR is_late_delivery IN (0, 1)),

    CONSTRAINT chk_fact_is_on_time
        CHECK (is_on_time_delivery IS NULL OR is_on_time_delivery IN (0, 1)),

    CONSTRAINT chk_fact_is_profitable
        CHECK (is_profitable_item IS NULL OR is_profitable_item IN (0, 1)),

    CONSTRAINT chk_fact_is_loss
        CHECK (is_loss_item IS NULL OR is_loss_item IN (0, 1)),

    CONSTRAINT chk_fact_management_attention
        CHECK (
            requires_management_attention IS NULL
            OR requires_management_attention IN (0, 1)
        )
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci
COMMENT = 'Central order-item fact table for Nexora supply-chain analytics';

/* ---------------------------------------------------------------------------
   POST-CREATION VERIFICATION
   --------------------------------------------------------------------------- */
SHOW CREATE TABLE fact_order_item;

SELECT
    table_schema,
    table_name,
    engine,
    table_rows,
    table_collation
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name = 'fact_order_item';

SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = DATABASE()
  AND table_name = 'fact_order_item'
ORDER BY constraint_type, constraint_name;
