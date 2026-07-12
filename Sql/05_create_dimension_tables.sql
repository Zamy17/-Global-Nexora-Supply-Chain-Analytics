/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 05_create_dimension_tables.sql
   Purpose       : Create conformed dimension tables for the star schema.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   STAR-SCHEMA DIMENSIONS
   1. dim_customer
   2. dim_product
   3. dim_category
   4. dim_date
   5. dim_shipping_mode
   6. dim_geography

   DESIGN PRINCIPLES
   - Surrogate integer keys are used by the fact table.
   - Natural/business keys remain unique where available.
   - Key 0 is reserved for Unknown / Not Available members.
   - Tables are recreated by this development script. Do not use DROP TABLE in
     production without an approved migration and backup procedure.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = CONCAT_WS(',', @@SESSION.sql_mode, 'NO_AUTO_VALUE_ON_ZERO');

-- Fact table must be dropped first if this script is rerun after fact creation.
DROP TABLE IF EXISTS fact_order_item;

DROP TABLE IF EXISTS dim_geography;
DROP TABLE IF EXISTS dim_shipping_mode;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_category;
DROP TABLE IF EXISTS dim_customer;

/* ---------------------------------------------------------------------------
   1. CUSTOMER DIMENSION
   Grain: one row per source customer_id.
   --------------------------------------------------------------------------- */
CREATE TABLE dim_customer (
    customer_key                   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id                    BIGINT NULL,
    customer_segment               VARCHAR(50) NULL,
    customer_city                  VARCHAR(150) NULL,
    customer_state                 VARCHAR(100) NULL,
    customer_country               VARCHAR(100) NULL,
    customer_zipcode               VARCHAR(30) NULL,
    customer_order_count           INT NULL,
    customer_lifetime_sales        DECIMAL(20,4) NULL,
    customer_average_item_sales    DECIMAL(18,4) NULL,
    customer_lifetime_profit       DECIMAL(20,4) NULL,
    customer_first_order_date      DATETIME NULL,
    customer_last_order_date       DATETIME NULL,
    customer_tenure_days           INT NULL,
    customer_frequency_segment     VARCHAR(30) NULL,
    record_source                  VARCHAR(100) NOT NULL DEFAULT 'DataCo',
    created_at                     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at                     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                               ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (customer_key),
    UNIQUE KEY uk_dim_customer_id (customer_id),
    KEY idx_dim_customer_segment (customer_segment),
    KEY idx_dim_customer_country_state (customer_country, customer_state)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Customer dimension; one row per source customer';

/* ---------------------------------------------------------------------------
   2. CATEGORY DIMENSION
   Grain: one row per category_id.
   --------------------------------------------------------------------------- */
CREATE TABLE dim_category (
    category_key       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    category_id        INT NULL,
    category_name      VARCHAR(150) NULL,
    department_id      INT NULL,
    department_name    VARCHAR(150) NULL,
    record_source      VARCHAR(100) NOT NULL DEFAULT 'DataCo',
    created_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                   ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (category_key),
    UNIQUE KEY uk_dim_category_id (category_id),
    KEY idx_dim_category_name (category_name),
    KEY idx_dim_category_department (department_id)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Product category and department dimension';

/* ---------------------------------------------------------------------------
   3. PRODUCT DIMENSION
   Grain: one row per product_card_id.
   Category is retained as a business attribute for usability; the fact table
   also references dim_category directly for a clean star-schema path.
   --------------------------------------------------------------------------- */
CREATE TABLE dim_product (
    product_key            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_card_id        BIGINT NULL,
    product_name           VARCHAR(255) NULL,
    product_price          DECIMAL(18,4) NULL,
    product_status         TINYINT NULL,
    product_category_id    INT NULL,
    category_name          VARCHAR(150) NULL,
    department_name        VARCHAR(150) NULL,
    record_source          VARCHAR(100) NOT NULL DEFAULT 'DataCo',
    created_at             DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at             DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                        ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (product_key),
    UNIQUE KEY uk_dim_product_card_id (product_card_id),
    KEY idx_dim_product_name (product_name),
    KEY idx_dim_product_category_id (product_category_id),
    CONSTRAINT chk_dim_product_status
        CHECK (product_status IS NULL OR product_status IN (0, 1))
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Product dimension; one row per product card ID';

/* ---------------------------------------------------------------------------
   4. DATE DIMENSION
   Grain: one row per calendar date.
   date_key uses YYYYMMDD. Key 0 is the Unknown member.
   --------------------------------------------------------------------------- */
CREATE TABLE dim_date (
    date_key              INT NOT NULL,
    full_date             DATE NULL,
    calendar_year         SMALLINT NULL,
    calendar_quarter      TINYINT NULL,
    quarter_name          CHAR(2) NULL,
    calendar_month        TINYINT NULL,
    month_name            VARCHAR(20) NULL,
    month_short_name      CHAR(3) NULL,
    year_month            CHAR(7) NULL,
    week_of_year          TINYINT NULL,
    day_of_month          TINYINT NULL,
    day_of_week_number    TINYINT NULL,
    day_name              VARCHAR(20) NULL,
    is_weekend            TINYINT NOT NULL DEFAULT 0,
    created_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),

    PRIMARY KEY (date_key),
    UNIQUE KEY uk_dim_date_full_date (full_date),
    KEY idx_dim_date_year_month (calendar_year, calendar_month),
    CONSTRAINT chk_dim_date_month
        CHECK (calendar_month IS NULL OR calendar_month BETWEEN 1 AND 12),
    CONSTRAINT chk_dim_date_quarter
        CHECK (calendar_quarter IS NULL OR calendar_quarter BETWEEN 1 AND 4),
    CONSTRAINT chk_dim_date_weekend
        CHECK (is_weekend IN (0, 1))
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Conformed calendar date dimension';

/* ---------------------------------------------------------------------------
   5. SHIPPING MODE DIMENSION
   Grain: one row per shipping-mode name.
   --------------------------------------------------------------------------- */
CREATE TABLE dim_shipping_mode (
    shipping_mode_key     SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    shipping_mode         VARCHAR(50) NULL,
    service_level_group   VARCHAR(30) NULL,
    record_source         VARCHAR(100) NOT NULL DEFAULT 'DataCo',
    created_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                       ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (shipping_mode_key),
    UNIQUE KEY uk_dim_shipping_mode (shipping_mode)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Shipping mode dimension';

/* ---------------------------------------------------------------------------
   6. GEOGRAPHY DIMENSION
   Grain: one row per unique order-location combination.
   A SHA-256 business key avoids nullable multi-column uniqueness problems.
   --------------------------------------------------------------------------- */
CREATE TABLE dim_geography (
    geography_key       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    geography_hash      CHAR(64) NOT NULL,
    market              VARCHAR(100) NULL,
    order_region        VARCHAR(100) NULL,
    order_country       VARCHAR(100) NULL,
    order_state         VARCHAR(100) NULL,
    order_city          VARCHAR(150) NULL,
    latitude            DECIMAL(10,7) NULL,
    longitude           DECIMAL(10,7) NULL,
    record_source       VARCHAR(100) NOT NULL DEFAULT 'DataCo',
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                     ON UPDATE CURRENT_TIMESTAMP(6),

    PRIMARY KEY (geography_key),
    UNIQUE KEY uk_dim_geography_hash (geography_hash),
    KEY idx_dim_geography_market (market),
    KEY idx_dim_geography_country_region (order_country, order_region),
    KEY idx_dim_geography_state_city (order_state, order_city),
    CONSTRAINT chk_dim_geography_latitude
        CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_dim_geography_longitude
        CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci
  COMMENT='Order destination geography dimension';

/* ---------------------------------------------------------------------------
   UNKNOWN MEMBERS — surrogate key 0
   --------------------------------------------------------------------------- */
INSERT INTO dim_customer (
    customer_key, customer_id, customer_segment, customer_city,
    customer_state, customer_country, customer_zipcode,
    customer_frequency_segment, record_source
)
VALUES (
    0, NULL, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown',
    'Unknown', 'System'
);

INSERT INTO dim_category (
    category_key, category_id, category_name,
    department_id, department_name, record_source
)
VALUES (0, NULL, 'Unknown', NULL, 'Unknown', 'System');

INSERT INTO dim_product (
    product_key, product_card_id, product_name, product_price,
    product_status, product_category_id, category_name,
    department_name, record_source
)
VALUES (
    0, NULL, 'Unknown', NULL, NULL, NULL, 'Unknown', 'Unknown', 'System'
);

INSERT INTO dim_date (
    date_key, full_date, calendar_year, calendar_quarter,
    quarter_name, calendar_month, month_name, month_short_name,
    year_month, week_of_year, day_of_month, day_of_week_number,
    day_name, is_weekend
)
VALUES (
    0, NULL, NULL, NULL, 'NA', NULL, 'Unknown', 'UNK',
    '0000-00', NULL, NULL, NULL, 'Unknown', 0
);

INSERT INTO dim_shipping_mode (
    shipping_mode_key, shipping_mode, service_level_group, record_source
)
VALUES (0, 'Unknown', 'Unknown', 'System');

INSERT INTO dim_geography (
    geography_key, geography_hash, market, order_region,
    order_country, order_state, order_city, latitude, longitude,
    record_source
)
VALUES (
    0, REPEAT('0', 64), 'Unknown', 'Unknown',
    'Unknown', 'Unknown', 'Unknown', NULL, NULL, 'System'
);

/* ---------------------------------------------------------------------------
   POST-CREATION VERIFICATION
   --------------------------------------------------------------------------- */
SELECT table_name, engine, table_rows, table_collation
FROM information_schema.tables
WHERE table_schema = 'nexora_supply_chain'
  AND table_name LIKE 'dim\_%' ESCAPE '\\'
ORDER BY table_name;

SELECT 'dim_customer' AS dimension_name, COUNT(*) AS row_count FROM dim_customer
UNION ALL
SELECT 'dim_category', COUNT(*) FROM dim_category
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'dim_shipping_mode', COUNT(*) FROM dim_shipping_mode
UNION ALL
SELECT 'dim_geography', COUNT(*) FROM dim_geography;
