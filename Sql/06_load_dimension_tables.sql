/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 06_load_dimension_tables.sql
   Purpose       : Load and refresh all star-schema dimension tables.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   PREREQUISITES
   - 01_create_database.sql
   - 02_create_staging_table.sql
   - 03_load_csv.sql
   - 04_data_quality_check.sql
   - 05_create_dimension_tables.sql

   ETL CHARACTERISTICS
   - Idempotent: safe to rerun.
   - Latest staging record wins for customer/product/category attributes.
   - Existing members are updated with ON DUPLICATE KEY UPDATE.
   - Unknown members with surrogate key 0 are preserved.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = CONCAT_WS(',', @@SESSION.sql_mode, 'NO_AUTO_VALUE_ON_ZERO');
SET SESSION cte_max_recursion_depth = 10000;
SET @dimension_load_started_at = NOW(6);

INSERT INTO etl_run_log (
    pipeline_name,
    source_file_name,
    process_name,
    process_status,
    started_at
)
VALUES (
    'nexora_supply_chain_pipeline',
    'stg_supply_chain',
    'load_dimension_tables',
    'STARTED',
    @dimension_load_started_at
);

SET @etl_run_id = LAST_INSERT_ID();

START TRANSACTION;

/* ---------------------------------------------------------------------------
   1. LOAD DIM_CUSTOMER
   Latest staging row is used for descriptive and engineered attributes.
   --------------------------------------------------------------------------- */
INSERT INTO dim_customer (
    customer_id,
    customer_segment,
    customer_city,
    customer_state,
    customer_country,
    customer_zipcode,
    customer_order_count,
    customer_lifetime_sales,
    customer_average_item_sales,
    customer_lifetime_profit,
    customer_first_order_date,
    customer_last_order_date,
    customer_tenure_days,
    customer_frequency_segment,
    record_source
)
SELECT
    src.customer_id,
    src.customer_segment,
    src.customer_city,
    src.customer_state,
    src.customer_country,
    src.customer_zipcode,
    src.customer_order_count,
    src.customer_lifetime_sales,
    src.customer_average_item_sales,
    src.customer_lifetime_profit,
    src.customer_first_order_date,
    src.customer_last_order_date,
    src.customer_tenure_days,
    src.customer_frequency_segment,
    'DataCo'
FROM (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.customer_id
            ORDER BY s.loaded_at DESC, s.staging_row_id DESC
        ) AS rn
    FROM stg_supply_chain AS s
    WHERE s.customer_id IS NOT NULL
) AS src
WHERE src.rn = 1
ON DUPLICATE KEY UPDATE
    customer_segment = VALUES(customer_segment),
    customer_city = VALUES(customer_city),
    customer_state = VALUES(customer_state),
    customer_country = VALUES(customer_country),
    customer_zipcode = VALUES(customer_zipcode),
    customer_order_count = VALUES(customer_order_count),
    customer_lifetime_sales = VALUES(customer_lifetime_sales),
    customer_average_item_sales = VALUES(customer_average_item_sales),
    customer_lifetime_profit = VALUES(customer_lifetime_profit),
    customer_first_order_date = VALUES(customer_first_order_date),
    customer_last_order_date = VALUES(customer_last_order_date),
    customer_tenure_days = VALUES(customer_tenure_days),
    customer_frequency_segment = VALUES(customer_frequency_segment),
    record_source = VALUES(record_source),
    updated_at = CURRENT_TIMESTAMP(6);

SET @dim_customer_rows = ROW_COUNT();

/* ---------------------------------------------------------------------------
   2. LOAD DIM_CATEGORY
   --------------------------------------------------------------------------- */
INSERT INTO dim_category (
    category_id,
    category_name,
    department_id,
    department_name,
    record_source
)
SELECT
    src.category_id,
    src.category_name,
    src.department_id,
    src.department_name,
    'DataCo'
FROM (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.category_id
            ORDER BY s.loaded_at DESC, s.staging_row_id DESC
        ) AS rn
    FROM stg_supply_chain AS s
    WHERE s.category_id IS NOT NULL
) AS src
WHERE src.rn = 1
ON DUPLICATE KEY UPDATE
    category_name = VALUES(category_name),
    department_id = VALUES(department_id),
    department_name = VALUES(department_name),
    record_source = VALUES(record_source),
    updated_at = CURRENT_TIMESTAMP(6);

SET @dim_category_rows = ROW_COUNT();

/* ---------------------------------------------------------------------------
   3. LOAD DIM_PRODUCT
   --------------------------------------------------------------------------- */
INSERT INTO dim_product (
    product_card_id,
    product_name,
    product_price,
    product_status,
    product_category_id,
    category_name,
    department_name,
    record_source
)
SELECT
    src.product_card_id,
    src.product_name,
    src.product_price,
    src.product_status,
    src.product_category_id,
    src.category_name,
    src.department_name,
    'DataCo'
FROM (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.product_card_id
            ORDER BY s.loaded_at DESC, s.staging_row_id DESC
        ) AS rn
    FROM stg_supply_chain AS s
    WHERE s.product_card_id IS NOT NULL
) AS src
WHERE src.rn = 1
ON DUPLICATE KEY UPDATE
    product_name = VALUES(product_name),
    product_price = VALUES(product_price),
    product_status = VALUES(product_status),
    product_category_id = VALUES(product_category_id),
    category_name = VALUES(category_name),
    department_name = VALUES(department_name),
    record_source = VALUES(record_source),
    updated_at = CURRENT_TIMESTAMP(6);

SET @dim_product_rows = ROW_COUNT();

/* ---------------------------------------------------------------------------
   4. LOAD DIM_SHIPPING_MODE
   --------------------------------------------------------------------------- */
INSERT INTO dim_shipping_mode (
    shipping_mode,
    service_level_group,
    record_source
)
SELECT DISTINCT
    TRIM(s.shipping_mode) AS shipping_mode,
    CASE
        WHEN LOWER(TRIM(s.shipping_mode)) LIKE '%same day%' THEN 'Express'
        WHEN LOWER(TRIM(s.shipping_mode)) LIKE '%first class%' THEN 'Priority'
        WHEN LOWER(TRIM(s.shipping_mode)) LIKE '%second class%' THEN 'Standard'
        WHEN LOWER(TRIM(s.shipping_mode)) LIKE '%standard class%' THEN 'Economy'
        ELSE 'Other'
    END AS service_level_group,
    'DataCo'
FROM stg_supply_chain AS s
WHERE NULLIF(TRIM(s.shipping_mode), '') IS NOT NULL
ON DUPLICATE KEY UPDATE
    service_level_group = VALUES(service_level_group),
    record_source = VALUES(record_source),
    updated_at = CURRENT_TIMESTAMP(6);

SET @dim_shipping_rows = ROW_COUNT();

/* ---------------------------------------------------------------------------
   5. LOAD DIM_GEOGRAPHY
   Geography is based on the order/delivery destination fields.
   --------------------------------------------------------------------------- */
INSERT INTO dim_geography (
    geography_hash,
    market,
    order_region,
    order_country,
    order_state,
    order_city,
    latitude,
    longitude,
    record_source
)
SELECT
    src.geography_hash,
    src.market,
    src.order_region,
    src.order_country,
    src.order_state,
    src.order_city,
    src.latitude,
    src.longitude,
    'DataCo'
FROM (
    SELECT
        SHA2(CONCAT_WS('|',
            COALESCE(NULLIF(TRIM(s.market), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(s.order_region), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(s.order_country), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(s.order_state), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(s.order_city), ''), 'Unknown')
        ), 256) AS geography_hash,
        NULLIF(TRIM(s.market), '') AS market,
        NULLIF(TRIM(s.order_region), '') AS order_region,
        NULLIF(TRIM(s.order_country), '') AS order_country,
        NULLIF(TRIM(s.order_state), '') AS order_state,
        NULLIF(TRIM(s.order_city), '') AS order_city,
        s.latitude,
        s.longitude,
        ROW_NUMBER() OVER (
            PARTITION BY
                COALESCE(NULLIF(TRIM(s.market), ''), 'Unknown'),
                COALESCE(NULLIF(TRIM(s.order_region), ''), 'Unknown'),
                COALESCE(NULLIF(TRIM(s.order_country), ''), 'Unknown'),
                COALESCE(NULLIF(TRIM(s.order_state), ''), 'Unknown'),
                COALESCE(NULLIF(TRIM(s.order_city), ''), 'Unknown')
            ORDER BY s.loaded_at DESC, s.staging_row_id DESC
        ) AS rn
    FROM stg_supply_chain AS s
    WHERE NULLIF(TRIM(s.market), '') IS NOT NULL
       OR NULLIF(TRIM(s.order_region), '') IS NOT NULL
       OR NULLIF(TRIM(s.order_country), '') IS NOT NULL
       OR NULLIF(TRIM(s.order_state), '') IS NOT NULL
       OR NULLIF(TRIM(s.order_city), '') IS NOT NULL
) AS src
WHERE src.rn = 1
ON DUPLICATE KEY UPDATE
    market = VALUES(market),
    order_region = VALUES(order_region),
    order_country = VALUES(order_country),
    order_state = VALUES(order_state),
    order_city = VALUES(order_city),
    latitude = VALUES(latitude),
    longitude = VALUES(longitude),
    record_source = VALUES(record_source),
    updated_at = CURRENT_TIMESTAMP(6);

SET @dim_geography_rows = ROW_COUNT();

/* ---------------------------------------------------------------------------
   6. LOAD DIM_DATE
   Generates every calendar date between the earliest and latest order/shipping
   date. This guarantees a continuous date dimension for Tableau trend charts.
   --------------------------------------------------------------------------- */
SET @minimum_source_date = (
    SELECT MIN(source_date)
    FROM (
        SELECT MIN(DATE(order_date)) AS source_date
        FROM stg_supply_chain
        WHERE order_date IS NOT NULL
        UNION ALL
        SELECT MIN(DATE(shipping_date)) AS source_date
        FROM stg_supply_chain
        WHERE shipping_date IS NOT NULL
    ) AS minimum_dates
);

SET @maximum_source_date = (
    SELECT MAX(source_date)
    FROM (
        SELECT MAX(DATE(order_date)) AS source_date
        FROM stg_supply_chain
        WHERE order_date IS NOT NULL
        UNION ALL
        SELECT MAX(DATE(shipping_date)) AS source_date
        FROM stg_supply_chain
        WHERE shipping_date IS NOT NULL
    ) AS maximum_dates
);

INSERT INTO dim_date (
    date_key,
    full_date,
    calendar_year,
    calendar_quarter,
    quarter_name,
    calendar_month,
    month_name,
    month_short_name,
    year_month,
    week_of_year,
    day_of_month,
    day_of_week_number,
    day_name,
    is_weekend
)
WITH RECURSIVE calendar AS (
    SELECT @minimum_source_date AS full_date
    WHERE @minimum_source_date IS NOT NULL

    UNION ALL

    SELECT DATE_ADD(full_date, INTERVAL 1 DAY)
    FROM calendar
    WHERE full_date < @maximum_source_date
)
SELECT
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    full_date,
    YEAR(full_date) AS calendar_year,
    QUARTER(full_date) AS calendar_quarter,
    CONCAT('Q', QUARTER(full_date)) AS quarter_name,
    MONTH(full_date) AS calendar_month,
    MONTHNAME(full_date) AS month_name,
    DATE_FORMAT(full_date, '%b') AS month_short_name,
    DATE_FORMAT(full_date, '%Y-%m') AS year_month,
    WEEK(full_date, 3) AS week_of_year,
    DAY(full_date) AS day_of_month,
    WEEKDAY(full_date) + 1 AS day_of_week_number,
    DAYNAME(full_date) AS day_name,
    CASE WHEN WEEKDAY(full_date) IN (5, 6) THEN 1 ELSE 0 END AS is_weekend
FROM calendar
ON DUPLICATE KEY UPDATE
    full_date = VALUES(full_date),
    calendar_year = VALUES(calendar_year),
    calendar_quarter = VALUES(calendar_quarter),
    quarter_name = VALUES(quarter_name),
    calendar_month = VALUES(calendar_month),
    month_name = VALUES(month_name),
    month_short_name = VALUES(month_short_name),
    year_month = VALUES(year_month),
    week_of_year = VALUES(week_of_year),
    day_of_month = VALUES(day_of_month),
    day_of_week_number = VALUES(day_of_week_number),
    day_name = VALUES(day_name),
    is_weekend = VALUES(is_weekend);

SET @dim_date_rows = ROW_COUNT();

COMMIT;

/* ---------------------------------------------------------------------------
   ETL AUDIT COMPLETION
   ROW_COUNT() values count inserted rows as 1 and updated rows as 2; therefore
   they are activity counts, not final table row counts.
   --------------------------------------------------------------------------- */
SET @final_dimension_rows =
      (SELECT COUNT(*) FROM dim_customer)
    + (SELECT COUNT(*) FROM dim_category)
    + (SELECT COUNT(*) FROM dim_product)
    + (SELECT COUNT(*) FROM dim_date)
    + (SELECT COUNT(*) FROM dim_shipping_mode)
    + (SELECT COUNT(*) FROM dim_geography);

UPDATE etl_run_log
SET process_status = 'SUCCESS',
    rows_read = (SELECT COUNT(*) FROM stg_supply_chain),
    rows_inserted = @final_dimension_rows,
    rows_rejected = 0,
    completed_at = NOW(6),
    error_message = NULL
WHERE etl_run_id = @etl_run_id;

/* ---------------------------------------------------------------------------
   POST-LOAD VALIDATION
   --------------------------------------------------------------------------- */
SELECT 'dim_customer' AS dimension_name,
       COUNT(*) AS total_rows,
       COUNT(*) - 1 AS business_members
FROM dim_customer
UNION ALL
SELECT 'dim_category', COUNT(*), COUNT(*) - 1 FROM dim_category
UNION ALL
SELECT 'dim_product', COUNT(*), COUNT(*) - 1 FROM dim_product
UNION ALL
SELECT 'dim_date', COUNT(*), COUNT(*) - 1 FROM dim_date
UNION ALL
SELECT 'dim_shipping_mode', COUNT(*), COUNT(*) - 1 FROM dim_shipping_mode
UNION ALL
SELECT 'dim_geography', COUNT(*), COUNT(*) - 1 FROM dim_geography;

-- Natural-key uniqueness should return zero duplicate groups.
SELECT 'customer_id' AS key_checked, COUNT(*) AS duplicate_groups
FROM (
    SELECT customer_id
    FROM dim_customer
    WHERE customer_key <> 0
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) AS duplicate_customer
UNION ALL
SELECT 'category_id', COUNT(*)
FROM (
    SELECT category_id
    FROM dim_category
    WHERE category_key <> 0
    GROUP BY category_id
    HAVING COUNT(*) > 1
) AS duplicate_category
UNION ALL
SELECT 'product_card_id', COUNT(*)
FROM (
    SELECT product_card_id
    FROM dim_product
    WHERE product_key <> 0
    GROUP BY product_card_id
    HAVING COUNT(*) > 1
) AS duplicate_product
UNION ALL
SELECT 'shipping_mode', COUNT(*)
FROM (
    SELECT shipping_mode
    FROM dim_shipping_mode
    WHERE shipping_mode_key <> 0
    GROUP BY shipping_mode
    HAVING COUNT(*) > 1
) AS duplicate_shipping
UNION ALL
SELECT 'geography_hash', COUNT(*)
FROM (
    SELECT geography_hash
    FROM dim_geography
    WHERE geography_key <> 0
    GROUP BY geography_hash
    HAVING COUNT(*) > 1
) AS duplicate_geography;

-- Coverage checks: valid staging natural keys should resolve to dimensions.
SELECT
    'customer' AS dimension_name,
    COUNT(*) AS unresolved_staging_rows
FROM stg_supply_chain AS s
LEFT JOIN dim_customer AS d
    ON d.customer_id = s.customer_id
WHERE s.customer_id IS NOT NULL
  AND d.customer_key IS NULL

UNION ALL

SELECT
    'category',
    COUNT(*)
FROM stg_supply_chain AS s
LEFT JOIN dim_category AS d
    ON d.category_id = s.category_id
WHERE s.category_id IS NOT NULL
  AND d.category_key IS NULL

UNION ALL

SELECT
    'product',
    COUNT(*)
FROM stg_supply_chain AS s
LEFT JOIN dim_product AS d
    ON d.product_card_id = s.product_card_id
WHERE s.product_card_id IS NOT NULL
  AND d.product_key IS NULL

UNION ALL

SELECT
    'shipping_mode',
    COUNT(*)
FROM stg_supply_chain AS s
LEFT JOIN dim_shipping_mode AS d
    ON d.shipping_mode = TRIM(s.shipping_mode)
WHERE NULLIF(TRIM(s.shipping_mode), '') IS NOT NULL
  AND d.shipping_mode_key IS NULL

UNION ALL

SELECT
    'order_date',
    COUNT(*)
FROM stg_supply_chain AS s
LEFT JOIN dim_date AS d
    ON d.date_key = CAST(DATE_FORMAT(s.order_date, '%Y%m%d') AS UNSIGNED)
WHERE s.order_date IS NOT NULL
  AND d.date_key IS NULL

UNION ALL

SELECT
    'shipping_date',
    COUNT(*)
FROM stg_supply_chain AS s
LEFT JOIN dim_date AS d
    ON d.date_key = CAST(DATE_FORMAT(s.shipping_date, '%Y%m%d') AS UNSIGNED)
WHERE s.shipping_date IS NOT NULL
  AND d.date_key IS NULL;

SELECT *
FROM etl_run_log
WHERE etl_run_id = @etl_run_id;
