/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 03_load_csv_header_aligned.sql
   Purpose       : Load the 85-column analytics-ready CSV into staging.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   IMPORTANT
   - Mapping follows the exact CSV header order supplied by the user.
   - order_zipcode is read but not stored because stg_supply_chain has no
     order_zipcode column.
   - Delivery features absent from the CSV are calculated during loading.
   - Full-refresh mode prevents duplicate staging rows on reruns.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+00:00';

SHOW VARIABLES LIKE 'local_infile';

-- ---------------------------------------------------------------------------
-- LOAD SETTINGS
-- ---------------------------------------------------------------------------
SET @source_file_name = 'dataco_supply_chain_analytics_ready.csv';
SET @load_batch_id =
    CONCAT('DATACO_', DATE_FORMAT(NOW(6), '%Y%m%d_%H%i%s_%f'));
SET @expected_rows = 180519;
SET @started_at = NOW(6);

INSERT INTO etl_run_log (
    pipeline_name,
    source_file_name,
    process_name,
    process_status,
    started_at
)
VALUES (
    'nexora_supply_chain_pipeline',
    @source_file_name,
    'load_staging_csv',
    'STARTED',
    @started_at
);

SET @etl_run_id = LAST_INSERT_ID();

-- Full refresh: prevents duplicate imports.
TRUNCATE TABLE stg_supply_chain;

-- ---------------------------------------------------------------------------
-- CSV LOAD
-- Exact CSV header order: 85 columns
-- ---------------------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/Users/USER/Downloads/dataco_supply_chain_analytics_ready.csv'
INTO TABLE stg_supply_chain
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @payment_type,
    @days_for_shipping,
    @days_for_shipment,
    @order_profit,
    @sales_per_customer,
    @delivery_status,
    @late_delivery_risk,
    @category_id,
    @category_name,
    @customer_city,
    @customer_country,
    @customer_id,
    @customer_segment,
    @customer_state,
    @customer_zipcode,
    @department_id,
    @department_name,
    @latitude,
    @longitude,
    @market,
    @order_city,
    @order_country,
    @order_customer_id,
    @order_date,
    @order_id,
    @order_item_cardprod_id,
    @order_item_discount,
    @order_item_discount_rate,
    @order_item_id,
    @order_item_product_price,
    @order_item_profit_ratio,
    @order_item_quantity,
    @sales,
    @order_item_total,
    @order_profit_per_order,
    @order_region,
    @order_state,
    @order_status,
    @order_zipcode,
    @product_card_id,
    @product_category_id,
    @product_name,
    @product_price,
    @product_status,
    @shipping_date,
    @shipping_mode,
    @is_late_delivery,
    @profit_margin_pct,
    @gross_sales_before_discount,
    @profitability_status,
    @order_year,
    @order_quarter,
    @order_month,
    @order_month_name,
    @order_week,
    @order_day,
    @order_day_name,
    @order_date_key,
    @shipping_date_key,
    @order_quarter_number,
    @order_year_month,
    @is_weekend_order,
    @shipping_year_month,
    @discount_pct_calculated,
    @discount_rate_pct,
    @is_profitable_item,
    @is_loss_item,
    @sales_value_tier,
    @margin_band,
    @discount_band,
    @order_total_sales,
    @order_total_profit,
    @order_total_quantity,
    @order_item_count,
    @order_profit_margin_pct,
    @customer_order_count,
    @customer_lifetime_sales,
    @customer_average_item_sales,
    @customer_lifetime_profit,
    @customer_first_order_date,
    @customer_last_order_date,
    @customer_tenure_days,
    @customer_frequency_segment,
    @requires_management_attention,
    @operational_risk_segment
)
SET
    source_file_name = @source_file_name,
    load_batch_id = @load_batch_id,
    loaded_at = NOW(6),

    payment_type = NULLIF(TRIM(@payment_type), ''),
    days_for_shipping_real =
        CAST(NULLIF(TRIM(@days_for_shipping), '') AS SIGNED),
    days_for_shipment_scheduled =
        CAST(NULLIF(TRIM(@days_for_shipment), '') AS SIGNED),
    order_profit = NULLIF(TRIM(@order_profit), ''),
    sales_per_customer = NULLIF(TRIM(@sales_per_customer), ''),
    delivery_status = NULLIF(TRIM(@delivery_status), ''),
    late_delivery_risk = NULLIF(TRIM(@late_delivery_risk), ''),

    category_id = NULLIF(TRIM(@category_id), ''),
    category_name = NULLIF(TRIM(@category_name), ''),

    customer_city = NULLIF(TRIM(@customer_city), ''),
    customer_country = NULLIF(TRIM(@customer_country), ''),
    customer_id = NULLIF(TRIM(@customer_id), ''),
    customer_segment = NULLIF(TRIM(@customer_segment), ''),
    customer_state = NULLIF(TRIM(@customer_state), ''),
    customer_zipcode = NULLIF(TRIM(@customer_zipcode), ''),

    department_id = NULLIF(TRIM(@department_id), ''),
    department_name = NULLIF(TRIM(@department_name), ''),

    latitude = NULLIF(TRIM(@latitude), ''),
    longitude = NULLIF(TRIM(@longitude), ''),
    market = NULLIF(TRIM(@market), ''),

    order_city = NULLIF(TRIM(@order_city), ''),
    order_country = NULLIF(TRIM(@order_country), ''),
    order_customer_id = NULLIF(TRIM(@order_customer_id), ''),

    order_date = CASE
        WHEN NULLIF(TRIM(@order_date), '') IS NULL THEN NULL
        WHEN TRIM(@order_date) REGEXP
             '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@order_date), '%c/%e/%Y %k:%i')
        WHEN TRIM(@order_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@order_date), '%Y-%m-%d %H:%i:%s')
        WHEN TRIM(@order_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@order_date), '%Y-%m-%d')
        ELSE NULL
    END,

    order_id = NULLIF(TRIM(@order_id), ''),
    order_item_cardprod_id = NULLIF(TRIM(@order_item_cardprod_id), ''),
    order_item_discount = NULLIF(TRIM(@order_item_discount), ''),
    order_item_discount_rate =
        NULLIF(TRIM(@order_item_discount_rate), ''),
    order_item_id = NULLIF(TRIM(@order_item_id), ''),
    order_item_product_price =
        NULLIF(TRIM(@order_item_product_price), ''),
    order_item_profit_ratio =
        NULLIF(TRIM(@order_item_profit_ratio), ''),
    order_item_quantity = NULLIF(TRIM(@order_item_quantity), ''),
    sales = NULLIF(TRIM(@sales), ''),
    order_item_total = NULLIF(TRIM(@order_item_total), ''),
    order_profit_per_order =
        NULLIF(TRIM(@order_profit_per_order), ''),
    order_region = NULLIF(TRIM(@order_region), ''),
    order_state = NULLIF(TRIM(@order_state), ''),
    order_status = NULLIF(TRIM(@order_status), ''),

    -- @order_zipcode is intentionally ignored because the staging table
    -- does not currently contain an order_zipcode field.

    product_card_id = NULLIF(TRIM(@product_card_id), ''),
    product_category_id = NULLIF(TRIM(@product_category_id), ''),
    product_name = NULLIF(TRIM(@product_name), ''),
    product_price = NULLIF(TRIM(@product_price), ''),
    product_status = NULLIF(TRIM(@product_status), ''),

    shipping_date = CASE
        WHEN NULLIF(TRIM(@shipping_date), '') IS NULL THEN NULL
        WHEN TRIM(@shipping_date) REGEXP
             '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@shipping_date), '%c/%e/%Y %k:%i')
        WHEN TRIM(@shipping_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@shipping_date), '%Y-%m-%d %H:%i:%s')
        WHEN TRIM(@shipping_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@shipping_date), '%Y-%m-%d')
        ELSE NULL
    END,

    shipping_mode = NULLIF(TRIM(@shipping_mode), ''),

    -- Delivery features calculated because they are absent from this CSV.
    shipping_delay_days =
        CAST(NULLIF(TRIM(@days_for_shipping), '') AS SIGNED)
        - CAST(NULLIF(TRIM(@days_for_shipment), '') AS SIGNED),

    delivery_performance = CASE
        WHEN NULLIF(TRIM(@days_for_shipping), '') IS NULL
          OR NULLIF(TRIM(@days_for_shipment), '') IS NULL
            THEN 'Unknown'
        WHEN CAST(@days_for_shipping AS SIGNED)
           > CAST(@days_for_shipment AS SIGNED)
            THEN 'Late'
        WHEN CAST(@days_for_shipping AS SIGNED)
           = CAST(@days_for_shipment AS SIGNED)
            THEN 'On Schedule'
        ELSE 'Early'
    END,

    is_late_delivery = NULLIF(TRIM(@is_late_delivery), ''),

    absolute_schedule_variance_days = ABS(
        CAST(NULLIF(TRIM(@days_for_shipping), '') AS SIGNED)
        - CAST(NULLIF(TRIM(@days_for_shipment), '') AS SIGNED)
    ),

    is_on_time_delivery = CASE
        WHEN NULLIF(TRIM(@days_for_shipping), '') IS NULL
          OR NULLIF(TRIM(@days_for_shipment), '') IS NULL
            THEN NULL
        WHEN CAST(@days_for_shipping AS SIGNED)
          <= CAST(@days_for_shipment AS SIGNED)
            THEN 1
        ELSE 0
    END,

    shipping_efficiency_ratio = CASE
        WHEN CAST(NULLIF(TRIM(@days_for_shipment), '') AS DECIMAL(18,6)) > 0
            THEN
                CAST(NULLIF(TRIM(@days_for_shipping), '') AS DECIMAL(18,6))
                /
                CAST(NULLIF(TRIM(@days_for_shipment), '') AS DECIMAL(18,6))
        ELSE NULL
    END,

    delivery_delay_severity = CASE
        WHEN NULLIF(TRIM(@days_for_shipping), '') IS NULL
          OR NULLIF(TRIM(@days_for_shipment), '') IS NULL
            THEN 'Unknown'
        WHEN CAST(@days_for_shipping AS SIGNED)
           - CAST(@days_for_shipment AS SIGNED) < 0
            THEN 'Early'
        WHEN CAST(@days_for_shipping AS SIGNED)
           - CAST(@days_for_shipment AS SIGNED) = 0
            THEN 'On Schedule'
        WHEN CAST(@days_for_shipping AS SIGNED)
           - CAST(@days_for_shipment AS SIGNED) = 1
            THEN '1 Day Late'
        WHEN CAST(@days_for_shipping AS SIGNED)
           - CAST(@days_for_shipment AS SIGNED) BETWEEN 2 AND 3
            THEN '2–3 Days Late'
        ELSE '4+ Days Late'
    END,

    shipping_speed_segment = CASE
        WHEN NULLIF(TRIM(@days_for_shipping), '') IS NULL
            THEN 'Unknown'
        WHEN CAST(@days_for_shipping AS SIGNED) <= 2
            THEN 'Express'
        WHEN CAST(@days_for_shipping AS SIGNED) <= 4
            THEN 'Standard'
        WHEN CAST(@days_for_shipping AS SIGNED) <= 6
            THEN 'Slow'
        ELSE 'Very Slow'
    END,

    profit_margin_pct = NULLIF(TRIM(@profit_margin_pct), ''),
    gross_sales_before_discount =
        NULLIF(TRIM(@gross_sales_before_discount), ''),
    profitability_status =
        NULLIF(TRIM(@profitability_status), ''),

    order_year = NULLIF(TRIM(@order_year), ''),
    order_quarter = NULLIF(TRIM(@order_quarter), ''),
    order_month = NULLIF(TRIM(@order_month), ''),
    order_month_name = NULLIF(TRIM(@order_month_name), ''),
    order_week = NULLIF(TRIM(@order_week), ''),
    order_day = NULLIF(TRIM(@order_day), ''),
    order_day_name = NULLIF(TRIM(@order_day_name), ''),
    order_date_key = NULLIF(TRIM(@order_date_key), ''),
    shipping_date_key = NULLIF(TRIM(@shipping_date_key), ''),
    order_quarter_number =
        NULLIF(TRIM(@order_quarter_number), ''),
    order_year_month = NULLIF(TRIM(@order_year_month), ''),
    is_weekend_order = NULLIF(TRIM(@is_weekend_order), ''),
    shipping_year_month =
        NULLIF(TRIM(@shipping_year_month), ''),

    discount_pct_calculated =
        NULLIF(TRIM(@discount_pct_calculated), ''),
    discount_rate_pct = NULLIF(TRIM(@discount_rate_pct), ''),
    is_profitable_item = NULLIF(TRIM(@is_profitable_item), ''),
    is_loss_item = NULLIF(TRIM(@is_loss_item), ''),
    sales_value_tier = NULLIF(TRIM(@sales_value_tier), ''),
    margin_band = NULLIF(TRIM(@margin_band), ''),
    discount_band = NULLIF(TRIM(@discount_band), ''),

    order_total_sales = NULLIF(TRIM(@order_total_sales), ''),
    order_total_profit = NULLIF(TRIM(@order_total_profit), ''),
    order_total_quantity =
        NULLIF(TRIM(@order_total_quantity), ''),
    order_item_count = NULLIF(TRIM(@order_item_count), ''),
    order_profit_margin_pct =
        NULLIF(TRIM(@order_profit_margin_pct), ''),

    customer_order_count =
        NULLIF(TRIM(@customer_order_count), ''),
    customer_lifetime_sales =
        NULLIF(TRIM(@customer_lifetime_sales), ''),
    customer_average_item_sales =
        NULLIF(TRIM(@customer_average_item_sales), ''),
    customer_lifetime_profit =
        NULLIF(TRIM(@customer_lifetime_profit), ''),

    customer_first_order_date = CASE
        WHEN NULLIF(TRIM(@customer_first_order_date), '') IS NULL THEN NULL
        WHEN TRIM(@customer_first_order_date) REGEXP
             '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(
                TRIM(@customer_first_order_date),
                '%c/%e/%Y %k:%i'
            )
        WHEN TRIM(@customer_first_order_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(
                TRIM(@customer_first_order_date),
                '%Y-%m-%d %H:%i:%s'
            )
        ELSE NULL
    END,

    customer_last_order_date = CASE
        WHEN NULLIF(TRIM(@customer_last_order_date), '') IS NULL THEN NULL
        WHEN TRIM(@customer_last_order_date) REGEXP
             '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(
                TRIM(@customer_last_order_date),
                '%c/%e/%Y %k:%i'
            )
        WHEN TRIM(@customer_last_order_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(
                TRIM(@customer_last_order_date),
                '%Y-%m-%d %H:%i:%s'
            )
        ELSE NULL
    END,

    customer_tenure_days =
        NULLIF(TRIM(@customer_tenure_days), ''),
    customer_frequency_segment =
        NULLIF(TRIM(@customer_frequency_segment), ''),
    requires_management_attention =
        NULLIF(TRIM(@requires_management_attention), ''),
    operational_risk_segment =
        NULLIF(TRIM(TRAILING '\r' FROM @operational_risk_segment), '');

-- ---------------------------------------------------------------------------
-- LOAD RECONCILIATION
-- ---------------------------------------------------------------------------
SET @rows_inserted = (
    SELECT COUNT(*)
    FROM stg_supply_chain
    WHERE load_batch_id = @load_batch_id
);

SET @distinct_order_items = (
    SELECT COUNT(DISTINCT order_item_id)
    FROM stg_supply_chain
    WHERE load_batch_id = @load_batch_id
);

SET @duplicate_rows = @rows_inserted - @distinct_order_items;

SET @valid_order_dates = (
    SELECT COUNT(order_date)
    FROM stg_supply_chain
    WHERE load_batch_id = @load_batch_id
);

SET @valid_shipping_dates = (
    SELECT COUNT(shipping_date)
    FROM stg_supply_chain
    WHERE load_batch_id = @load_batch_id
);

SET @load_status = CASE
    WHEN @rows_inserted = @expected_rows
     AND @duplicate_rows = 0
     AND @valid_order_dates = @expected_rows
     AND @valid_shipping_dates = @expected_rows
        THEN 'SUCCESS'
    WHEN @rows_inserted > 0
        THEN 'WARNING'
    ELSE 'FAILED'
END;

UPDATE etl_run_log
SET
    process_status = @load_status,
    rows_read = @rows_inserted,
    rows_inserted = @rows_inserted,
    rows_rejected = 0,
    completed_at = NOW(6),
    error_message = CASE
        WHEN @load_status = 'SUCCESS' THEN NULL
        ELSE CONCAT(
            'Rows=', @rows_inserted,
            '; duplicates=', @duplicate_rows,
            '; valid_order_dates=', @valid_order_dates,
            '; valid_shipping_dates=', @valid_shipping_dates
        )
    END
WHERE etl_run_id = @etl_run_id;

-- ---------------------------------------------------------------------------
-- FINAL VALIDATION
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_item_id) AS unique_order_item_ids,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicate_rows,
    COUNT(order_date) AS valid_order_dates,
    SUM(order_date IS NULL) AS null_order_dates,
    COUNT(shipping_date) AS valid_shipping_dates,
    SUM(shipping_date IS NULL) AS null_shipping_dates,
    MIN(order_date) AS minimum_order_date,
    MAX(order_date) AS maximum_order_date,
    MIN(shipping_date) AS minimum_shipping_date,
    MAX(shipping_date) AS maximum_shipping_date,
    CASE
        WHEN COUNT(*) = @expected_rows
         AND COUNT(*) = COUNT(DISTINCT order_item_id)
         AND COUNT(order_date) = @expected_rows
         AND COUNT(shipping_date) = @expected_rows
            THEN 'READY'
        ELSE 'REVIEW REQUIRED'
    END AS staging_status
FROM stg_supply_chain;

SELECT
    order_status,
    shipping_date,
    shipping_mode,
    product_card_id,
    product_name
FROM stg_supply_chain
ORDER BY staging_row_id
LIMIT 20;

SELECT *
FROM etl_run_log
WHERE etl_run_id = @etl_run_id;

SHOW WARNINGS LIMIT 100;

