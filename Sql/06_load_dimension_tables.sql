/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 06_load_dimension_tables.sql
   Purpose       : Load and update all dimension tables from staging.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   Prerequisites:
   - stg_supply_chain contains the validated analytics-ready dataset.
   - 05_create_dimension_tables_complete.sql has completed successfully.

   Design:
   - Uses the latest load_batch_id from staging.
   - Preserves surrogate keys on reruns.
   - Updates existing natural keys and inserts only new members.
   - Keeps Unknown member at key 0.
   ============================================================================ */

USE nexora_supply_chain;

-- Disable Workbench safe-update restrictions for this ETL session.
SET @previous_sql_safe_updates = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,NO_AUTO_VALUE_ON_ZERO';

-- ============================================================================
-- 1. IDENTIFY LATEST STAGING BATCH
-- ============================================================================
SET @latest_batch_id = (
    SELECT load_batch_id
    FROM stg_supply_chain
    WHERE load_batch_id IS NOT NULL
    ORDER BY loaded_at DESC
    LIMIT 1
);

SELECT
    @latest_batch_id AS latest_batch_id,
    COUNT(*) AS latest_batch_rows
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- Stop manually if latest_batch_rows is 0.

-- ============================================================================
-- 2. LOAD DIM CUSTOMER
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_dim_customer;

CREATE TEMPORARY TABLE tmp_dim_customer AS
SELECT
    customer_id,
    MAX(customer_segment) AS customer_segment,
    MAX(customer_city) AS customer_city,
    MAX(customer_state) AS customer_state,
    MAX(customer_country) AS customer_country,
    MAX(customer_zipcode) AS customer_zipcode,
    MAX(customer_order_count) AS customer_order_count,
    MAX(customer_lifetime_sales) AS customer_lifetime_sales,
    MAX(customer_average_item_sales) AS customer_average_item_sales,
    MAX(customer_lifetime_profit) AS customer_lifetime_profit,
    MIN(customer_first_order_date) AS customer_first_order_date,
    MAX(customer_last_order_date) AS customer_last_order_date,
    MAX(customer_tenure_days) AS customer_tenure_days,
    MAX(customer_frequency_segment) AS customer_frequency_segment
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id
  AND customer_id IS NOT NULL
GROUP BY customer_id;

UPDATE dim_customer AS d
JOIN tmp_dim_customer AS s
  ON d.customer_id = s.customer_id
SET
    d.customer_segment = s.customer_segment,
    d.customer_city = s.customer_city,
    d.customer_state = s.customer_state,
    d.customer_country = s.customer_country,
    d.customer_zipcode = s.customer_zipcode,
    d.customer_order_count = s.customer_order_count,
    d.customer_lifetime_sales = s.customer_lifetime_sales,
    d.customer_average_item_sales = s.customer_average_item_sales,
    d.customer_lifetime_profit = s.customer_lifetime_profit,
    d.customer_first_order_date = s.customer_first_order_date,
    d.customer_last_order_date = s.customer_last_order_date,
    d.customer_tenure_days = s.customer_tenure_days,
    d.customer_frequency_segment = s.customer_frequency_segment,
    d.record_source = 'DataCo',
    d.updated_at = CURRENT_TIMESTAMP(6)
WHERE d.customer_key > 0;

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
    s.customer_id,
    s.customer_segment,
    s.customer_city,
    s.customer_state,
    s.customer_country,
    s.customer_zipcode,
    s.customer_order_count,
    s.customer_lifetime_sales,
    s.customer_average_item_sales,
    s.customer_lifetime_profit,
    s.customer_first_order_date,
    s.customer_last_order_date,
    s.customer_tenure_days,
    s.customer_frequency_segment,
    'DataCo'
FROM tmp_dim_customer AS s
LEFT JOIN dim_customer AS d
  ON d.customer_id = s.customer_id
WHERE d.customer_key IS NULL;

-- ============================================================================
-- 3. LOAD DIM CATEGORY
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_dim_category;

CREATE TEMPORARY TABLE tmp_dim_category AS
SELECT
    category_id,
    MAX(category_name) AS category_name,
    MAX(department_id) AS department_id,
    MAX(department_name) AS department_name
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id
  AND category_id IS NOT NULL
GROUP BY category_id;

UPDATE dim_category AS d
JOIN tmp_dim_category AS s
  ON d.category_id = s.category_id
SET
    d.category_name = s.category_name,
    d.department_id = s.department_id,
    d.department_name = s.department_name,
    d.record_source = 'DataCo',
    d.updated_at = CURRENT_TIMESTAMP(6)
WHERE d.category_key > 0;

INSERT INTO dim_category (
    category_id,
    category_name,
    department_id,
    department_name,
    record_source
)
SELECT
    s.category_id,
    s.category_name,
    s.department_id,
    s.department_name,
    'DataCo'
FROM tmp_dim_category AS s
LEFT JOIN dim_category AS d
  ON d.category_id = s.category_id
WHERE d.category_key IS NULL;

-- ============================================================================
-- 4. LOAD DIM PRODUCT
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_dim_product;

CREATE TEMPORARY TABLE tmp_dim_product AS
SELECT
    product_card_id,
    MAX(product_name) AS product_name,
    MAX(product_price) AS product_price,
    MAX(product_status) AS product_status,
    MAX(product_category_id) AS product_category_id,
    MAX(category_name) AS category_name,
    MAX(department_name) AS department_name
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id
  AND product_card_id IS NOT NULL
GROUP BY product_card_id;

UPDATE dim_product AS d
JOIN tmp_dim_product AS s
  ON d.product_card_id = s.product_card_id
SET
    d.product_name = s.product_name,
    d.product_price = s.product_price,
    d.product_status = s.product_status,
    d.product_category_id = s.product_category_id,
    d.category_name = s.category_name,
    d.department_name = s.department_name,
    d.record_source = 'DataCo',
    d.updated_at = CURRENT_TIMESTAMP(6)
WHERE d.product_key > 0;

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
    s.product_card_id,
    s.product_name,
    s.product_price,
    s.product_status,
    s.product_category_id,
    s.category_name,
    s.department_name,
    'DataCo'
FROM tmp_dim_product AS s
LEFT JOIN dim_product AS d
  ON d.product_card_id = s.product_card_id
WHERE d.product_key IS NULL;

-- ============================================================================
-- 5. LOAD DIM DATE
-- Includes all distinct order and shipping dates in staging.
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_dim_date;

CREATE TEMPORARY TABLE tmp_dim_date AS
SELECT DISTINCT
    DATE(source_date) AS full_date
FROM (
    SELECT order_date AS source_date
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
      AND order_date IS NOT NULL

    UNION

    SELECT shipping_date AS source_date
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
      AND shipping_date IS NOT NULL

    UNION

    SELECT customer_first_order_date AS source_date
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
      AND customer_first_order_date IS NOT NULL

    UNION

    SELECT customer_last_order_date AS source_date
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
      AND customer_last_order_date IS NOT NULL
) AS dates_source;

INSERT INTO dim_date (
    date_key,
    full_date,
    calendar_year,
    calendar_quarter,
    quarter_name,
    calendar_month,
    month_name,
    calendar_year_month,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
)
SELECT
    CAST(DATE_FORMAT(t.full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    t.full_date,
    YEAR(t.full_date) AS calendar_year,
    QUARTER(t.full_date) AS calendar_quarter,
    CONCAT('Q', QUARTER(t.full_date)) AS quarter_name,
    MONTH(t.full_date) AS calendar_month,
    MONTHNAME(t.full_date) AS month_name,
    DATE_FORMAT(t.full_date, '%Y-%m') AS calendar_year_month,
    WEEK(t.full_date, 3) AS week_of_year,
    DAY(t.full_date) AS day_of_month,
    WEEKDAY(t.full_date) + 1 AS day_of_week,
    DAYNAME(t.full_date) AS day_name,
    CASE
        WHEN WEEKDAY(t.full_date) IN (5, 6) THEN 1
        ELSE 0
    END AS is_weekend
FROM tmp_dim_date AS t
LEFT JOIN dim_date AS d
  ON d.full_date = t.full_date
WHERE d.date_key IS NULL;

-- ============================================================================
-- 6. LOAD DIM SHIPPING MODE
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_dim_shipping_mode;

CREATE TEMPORARY TABLE tmp_dim_shipping_mode AS
SELECT
    shipping_mode,
    CASE
        WHEN LOWER(shipping_mode) LIKE '%same day%' THEN 'Same Day'
        WHEN LOWER(shipping_mode) LIKE '%first class%' THEN 'Expedited'
        WHEN LOWER(shipping_mode) LIKE '%second class%' THEN 'Standard Plus'
        WHEN LOWER(shipping_mode) LIKE '%standard%' THEN 'Standard'
        ELSE 'Other'
    END AS service_level_group,
    ROUND(AVG(days_for_shipment_scheduled), 2) AS default_scheduled_days
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id
  AND shipping_mode IS NOT NULL
GROUP BY shipping_mode;

UPDATE dim_shipping_mode AS d
JOIN tmp_dim_shipping_mode AS s
  ON d.shipping_mode = s.shipping_mode
SET
    d.service_level_group = s.service_level_group,
    d.default_scheduled_days = s.default_scheduled_days,
    d.record_source = 'DataCo',
    d.updated_at = CURRENT_TIMESTAMP(6)
WHERE d.shipping_mode_key > 0;

INSERT INTO dim_shipping_mode (
    shipping_mode,
    service_level_group,
    default_scheduled_days,
    record_source
)
SELECT
    s.shipping_mode,
    s.service_level_group,
    s.default_scheduled_days,
    'DataCo'
FROM tmp_dim_shipping_mode AS s
LEFT JOIN dim_shipping_mode AS d
  ON d.shipping_mode = s.shipping_mode
WHERE d.shipping_mode_key IS NULL;

-- ============================================================================
-- 7. LOAD DIM GEOGRAPHY
-- Natural key is a SHA-256 hash of location attributes.
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_dim_geography;

CREATE TEMPORARY TABLE tmp_dim_geography AS
SELECT DISTINCT
    SHA2(
        CONCAT_WS(
            '|',
            COALESCE(TRIM(market), 'Unknown'),
            COALESCE(TRIM(order_region), 'Unknown'),
            COALESCE(TRIM(order_country), 'Unknown'),
            COALESCE(TRIM(order_state), 'Unknown'),
            COALESCE(TRIM(order_city), 'Unknown'),
            COALESCE(CAST(ROUND(latitude, 6) AS CHAR), 'Unknown'),
            COALESCE(CAST(ROUND(longitude, 6) AS CHAR), 'Unknown')
        ),
        256
    ) AS geography_natural_key,
    COALESCE(TRIM(market), 'Unknown') AS market,
    COALESCE(TRIM(order_region), 'Unknown') AS order_region,
    COALESCE(TRIM(order_country), 'Unknown') AS order_country,
    COALESCE(TRIM(order_state), 'Unknown') AS order_state,
    COALESCE(TRIM(order_city), 'Unknown') AS order_city,
    ROUND(latitude, 6) AS latitude,
    ROUND(longitude, 6) AS longitude
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

UPDATE dim_geography AS d
JOIN tmp_dim_geography AS s
  ON d.geography_natural_key = s.geography_natural_key
SET
    d.market = s.market,
    d.order_region = s.order_region,
    d.order_country = s.order_country,
    d.order_state = s.order_state,
    d.order_city = s.order_city,
    d.latitude = s.latitude,
    d.longitude = s.longitude,
    d.record_source = 'DataCo',
    d.updated_at = CURRENT_TIMESTAMP(6)
WHERE d.geography_key > 0;

INSERT INTO dim_geography (
    geography_natural_key,
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
    s.geography_natural_key,
    s.market,
    s.order_region,
    s.order_country,
    s.order_state,
    s.order_city,
    s.latitude,
    s.longitude,
    'DataCo'
FROM tmp_dim_geography AS s
LEFT JOIN dim_geography AS d
  ON d.geography_natural_key = s.geography_natural_key
WHERE d.geography_key IS NULL;

-- ============================================================================
-- 8. DIMENSION ROW-COUNT VALIDATION
-- ============================================================================
SELECT
    'dim_customer' AS dimension_name,
    COUNT(*) AS total_rows,
    COUNT(*) - 1 AS business_members
FROM dim_customer

UNION ALL

SELECT
    'dim_category',
    COUNT(*),
    COUNT(*) - 1
FROM dim_category

UNION ALL

SELECT
    'dim_product',
    COUNT(*),
    COUNT(*) - 1
FROM dim_product

UNION ALL

SELECT
    'dim_date',
    COUNT(*),
    COUNT(*) - 1
FROM dim_date

UNION ALL

SELECT
    'dim_shipping_mode',
    COUNT(*),
    COUNT(*) - 1
FROM dim_shipping_mode

UNION ALL

SELECT
    'dim_geography',
    COUNT(*),
    COUNT(*) - 1
FROM dim_geography;

-- ============================================================================
-- 9. NATURAL-KEY UNIQUENESS VALIDATION
-- ============================================================================
SELECT
    'dim_customer' AS dimension_name,
    COUNT(*) AS business_rows,
    COUNT(DISTINCT customer_id) AS distinct_natural_keys,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS'
        ELSE 'FAIL'
    END AS uniqueness_status
FROM dim_customer
WHERE customer_key <> 0

UNION ALL

SELECT
    'dim_category',
    COUNT(*),
    COUNT(DISTINCT category_id),
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT category_id) THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dim_category
WHERE category_key <> 0

UNION ALL

SELECT
    'dim_product',
    COUNT(*),
    COUNT(DISTINCT product_card_id),
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT product_card_id) THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dim_product
WHERE product_key <> 0;

-- ============================================================================
-- 10. STAGING-TO-DIMENSION RESOLUTION CHECK
-- ============================================================================
SELECT
    SUM(c.customer_key IS NULL) AS unresolved_customers,
    SUM(cat.category_key IS NULL) AS unresolved_categories,
    SUM(p.product_key IS NULL) AS unresolved_products,
    SUM(od.date_key IS NULL) AS unresolved_order_dates,
    SUM(sd.date_key IS NULL) AS unresolved_shipping_dates,
    SUM(sm.shipping_mode_key IS NULL) AS unresolved_shipping_modes,
    SUM(g.geography_key IS NULL) AS unresolved_geographies,
    CASE
        WHEN
            SUM(c.customer_key IS NULL) = 0
            AND SUM(cat.category_key IS NULL) = 0
            AND SUM(p.product_key IS NULL) = 0
            AND SUM(od.date_key IS NULL) = 0
            AND SUM(sd.date_key IS NULL) = 0
            AND SUM(sm.shipping_mode_key IS NULL) = 0
            AND SUM(g.geography_key IS NULL) = 0
        THEN 'READY FOR FACT LOAD'
        ELSE 'REVIEW UNRESOLVED MEMBERS'
    END AS dimension_readiness
FROM stg_supply_chain AS s
LEFT JOIN dim_customer AS c
  ON c.customer_id = s.customer_id
LEFT JOIN dim_category AS cat
  ON cat.category_id = s.category_id
LEFT JOIN dim_product AS p
  ON p.product_card_id = s.product_card_id
LEFT JOIN dim_date AS od
  ON od.full_date = DATE(s.order_date)
LEFT JOIN dim_date AS sd
  ON sd.full_date = DATE(s.shipping_date)
LEFT JOIN dim_shipping_mode AS sm
  ON sm.shipping_mode = s.shipping_mode
LEFT JOIN dim_geography AS g
  ON g.geography_natural_key = SHA2(
      CONCAT_WS(
          '|',
          COALESCE(TRIM(s.market), 'Unknown'),
          COALESCE(TRIM(s.order_region), 'Unknown'),
          COALESCE(TRIM(s.order_country), 'Unknown'),
          COALESCE(TRIM(s.order_state), 'Unknown'),
          COALESCE(TRIM(s.order_city), 'Unknown'),
          COALESCE(CAST(ROUND(s.latitude, 6) AS CHAR), 'Unknown'),
          COALESCE(CAST(ROUND(s.longitude, 6) AS CHAR), 'Unknown')
      ),
      256
  )
WHERE s.load_batch_id = @latest_batch_id;


-- Restore the previous SQL safe-update setting.
SET SQL_SAFE_UPDATES = @previous_sql_safe_updates;
