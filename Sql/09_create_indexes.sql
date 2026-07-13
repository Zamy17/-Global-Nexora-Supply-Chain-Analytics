/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 09_create_indexes.sql
   Purpose       : Create analytical and performance indexes for the warehouse.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   IMPORTANT
   - Run after 08_load_fact_table.sql completes successfully.
   - This script is idempotent: it checks index existence before creating it.
   - Existing primary, unique, and foreign-key indexes are preserved.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

-- ============================================================================
-- 1. HELPER PROCEDURE FOR IDEMPOTENT INDEX CREATION
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_create_index_if_missing;

DELIMITER $$

CREATE PROCEDURE sp_create_index_if_missing (
    IN p_table_name VARCHAR(128),
    IN p_index_name VARCHAR(128),
    IN p_index_ddl TEXT
)
BEGIN
    DECLARE v_index_exists INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_index_exists
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = p_table_name
      AND index_name = p_index_name;

    IF v_index_exists = 0 THEN
        SET @ddl = p_index_ddl;
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- 2. FACT TABLE ANALYTICAL INDEXES
-- ============================================================================

-- Monthly sales, profit, order count, and trend analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_order_date_sales',
    'CREATE INDEX idx_fact_order_date_sales
     ON fact_order_item (order_date_key, sales, order_profit_per_order)'
);

-- Shipping-date and delivery analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_shipping_date_late',
    'CREATE INDEX idx_fact_shipping_date_late
     ON fact_order_item (shipping_date_key, is_late_delivery)'
);

-- Category sales and profitability.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_category_sales_profit',
    'CREATE INDEX idx_fact_category_sales_profit
     ON fact_order_item (category_key, sales, order_profit_per_order)'
);

-- Product performance ranking.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_product_sales_profit',
    'CREATE INDEX idx_fact_product_sales_profit
     ON fact_order_item (product_key, sales, order_profit_per_order)'
);

-- Customer lifetime and segment analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_customer_sales_profit',
    'CREATE INDEX idx_fact_customer_sales_profit
     ON fact_order_item (customer_key, sales, order_profit_per_order)'
);

-- Shipping mode service performance.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_shipping_mode_late_delay',
    'CREATE INDEX idx_fact_shipping_mode_late_delay
     ON fact_order_item (
         shipping_mode_key,
         is_late_delivery,
         shipping_delay_days
     )'
);

-- Geography-market dashboard analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_geography_sales_profit',
    'CREATE INDEX idx_fact_geography_sales_profit
     ON fact_order_item (geography_key, sales, order_profit_per_order)'
);

-- Order-level detail and basket analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_order_id_item',
    'CREATE INDEX idx_fact_order_id_item
     ON fact_order_item (order_id, order_item_id)'
);

-- Profitability filtering.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_profitability_margin',
    'CREATE INDEX idx_fact_profitability_margin
     ON fact_order_item (profitability_status, profit_margin_pct)'
);

-- Operational exception and management-priority analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_management_risk',
    'CREATE INDEX idx_fact_management_risk
     ON fact_order_item (
         requires_management_attention,
         operational_risk_segment
     )'
);

-- Discount analysis.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_discount_band_rate',
    'CREATE INDEX idx_fact_discount_band_rate
     ON fact_order_item (discount_band, discount_rate_pct)'
);

-- Sales-value segmentation.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_sales_value_tier',
    'CREATE INDEX idx_fact_sales_value_tier
     ON fact_order_item (sales_value_tier, sales)'
);

-- ETL audit and batch troubleshooting.
CALL sp_create_index_if_missing(
    'fact_order_item',
    'idx_fact_batch_loaded_at',
    'CREATE INDEX idx_fact_batch_loaded_at
     ON fact_order_item (load_batch_id, loaded_at)'
);

-- ============================================================================
-- 3. DIMENSION INDEXES
-- ============================================================================

-- Customer dashboard filtering.
CALL sp_create_index_if_missing(
    'dim_customer',
    'idx_dim_customer_frequency_segment',
    'CREATE INDEX idx_dim_customer_frequency_segment
     ON dim_customer (customer_frequency_segment, customer_order_count)'
);

CALL sp_create_index_if_missing(
    'dim_customer',
    'idx_dim_customer_lifetime_sales',
    'CREATE INDEX idx_dim_customer_lifetime_sales
     ON dim_customer (customer_lifetime_sales)'
);

-- Product/category filtering.
CALL sp_create_index_if_missing(
    'dim_product',
    'idx_dim_product_category_department',
    'CREATE INDEX idx_dim_product_category_department
     ON dim_product (product_category_id, department_name)'
);

CALL sp_create_index_if_missing(
    'dim_product',
    'idx_dim_product_price',
    'CREATE INDEX idx_dim_product_price
     ON dim_product (product_price)'
);

-- Date drill-down.
CALL sp_create_index_if_missing(
    'dim_date',
    'idx_dim_date_year_month_day',
    'CREATE INDEX idx_dim_date_year_month_day
     ON dim_date (calendar_year, calendar_month, day_of_month)'
);

CALL sp_create_index_if_missing(
    'dim_date',
    'idx_dim_date_year_week',
    'CREATE INDEX idx_dim_date_year_week
     ON dim_date (calendar_year, week_of_year)'
);

-- Geography dashboard filtering.
CALL sp_create_index_if_missing(
    'dim_geography',
    'idx_dim_geography_market_country',
    'CREATE INDEX idx_dim_geography_market_country
     ON dim_geography (market, order_country)'
);

CALL sp_create_index_if_missing(
    'dim_geography',
    'idx_dim_geography_region_country_city',
    'CREATE INDEX idx_dim_geography_region_country_city
     ON dim_geography (order_region, order_country, order_city)'
);

-- Shipping service lookup.
CALL sp_create_index_if_missing(
    'dim_shipping_mode',
    'idx_dim_shipping_service_level',
    'CREATE INDEX idx_dim_shipping_service_level
     ON dim_shipping_mode (service_level_group)'
);

-- ============================================================================
-- 4. UPDATE OPTIMIZER STATISTICS
-- ============================================================================
ANALYZE TABLE fact_order_item;
ANALYZE TABLE dim_customer;
ANALYZE TABLE dim_product;
ANALYZE TABLE dim_category;
ANALYZE TABLE dim_date;
ANALYZE TABLE dim_shipping_mode;
ANALYZE TABLE dim_geography;

-- ============================================================================
-- 5. INDEX INVENTORY
-- ============================================================================
SELECT
    table_name,
    index_name,
    non_unique,
    index_type,
    GROUP_CONCAT(
        column_name
        ORDER BY seq_in_index
        SEPARATOR ', '
    ) AS indexed_columns,
    MAX(cardinality) AS estimated_cardinality
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN (
      'fact_order_item',
      'dim_customer',
      'dim_product',
      'dim_category',
      'dim_date',
      'dim_shipping_mode',
      'dim_geography'
  )
GROUP BY
    table_name,
    index_name,
    non_unique,
    index_type
ORDER BY
    table_name,
    CASE WHEN index_name = 'PRIMARY' THEN 0 ELSE 1 END,
    index_name;

-- ============================================================================
-- 6. INDEX COUNT SUMMARY
-- ============================================================================
SELECT
    table_name,
    COUNT(DISTINCT index_name) AS total_indexes
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN (
      'fact_order_item',
      'dim_customer',
      'dim_product',
      'dim_category',
      'dim_date',
      'dim_shipping_mode',
      'dim_geography'
  )
GROUP BY table_name
ORDER BY table_name;

-- ============================================================================
-- 7. SAMPLE EXPLAIN: MONTHLY SALES TREND
-- ============================================================================
EXPLAIN
SELECT
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    SUM(f.sales) AS total_sales,
    SUM(f.order_profit_per_order) AS total_profit,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM fact_order_item AS f
JOIN dim_date AS d
    ON d.date_key = f.order_date_key
GROUP BY
    d.calendar_year,
    d.calendar_month,
    d.month_name
ORDER BY
    d.calendar_year,
    d.calendar_month;

-- ============================================================================
-- 8. SAMPLE EXPLAIN: CATEGORY PERFORMANCE
-- ============================================================================
EXPLAIN
SELECT
    c.category_name,
    SUM(f.sales) AS total_sales,
    SUM(f.order_profit_per_order) AS total_profit,
    AVG(f.profit_margin_pct) AS average_profit_margin_pct
FROM fact_order_item AS f
JOIN dim_category AS c
    ON c.category_key = f.category_key
GROUP BY c.category_name
ORDER BY total_sales DESC;

-- ============================================================================
-- 9. SAMPLE EXPLAIN: DELIVERY PERFORMANCE
-- ============================================================================
EXPLAIN
SELECT
    sm.shipping_mode,
    COUNT(*) AS order_items,
    AVG(f.days_for_shipping_real) AS average_shipping_days,
    AVG(f.shipping_delay_days) AS average_delay_days,
    AVG(f.is_late_delivery) * 100 AS late_delivery_rate_pct
FROM fact_order_item AS f
JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode_key = f.shipping_mode_key
GROUP BY sm.shipping_mode
ORDER BY late_delivery_rate_pct DESC;

-- ============================================================================
-- 10. CLEAN UP HELPER PROCEDURE
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_create_index_if_missing;

SELECT
    'INDEX CREATION COMPLETE' AS index_status,
    NOW(6) AS completed_at;
