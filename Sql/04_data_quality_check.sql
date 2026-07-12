/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 04_data_quality_check.sql
   Purpose       : Validate staging data after CSV ingestion.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   INTERPRETATION
   - FAIL on a Critical check: do not continue to dimension/fact loading.
   - FAIL on a High check: investigate and document before continuing.
   - Warnings can be accepted only with a documented business explanation.
   ============================================================================ */

USE nexora_supply_chain;

-- Use the latest batch by default.
SET @batch_id = (
    SELECT load_batch_id
    FROM stg_supply_chain
    WHERE load_batch_id IS NOT NULL
    ORDER BY loaded_at DESC
    LIMIT 1
);
SET @expected_min_rows = 180000;

SELECT @batch_id AS batch_under_review;

DROP TEMPORARY TABLE IF EXISTS tmp_data_quality_results;
CREATE TEMPORARY TABLE tmp_data_quality_results (
    check_id       INT NOT NULL AUTO_INCREMENT,
    category       VARCHAR(50) NOT NULL,
    check_name     VARCHAR(200) NOT NULL,
    severity       ENUM('Critical','High','Medium','Low','Info') NOT NULL,
    failed_rows    BIGINT UNSIGNED NOT NULL,
    total_rows     BIGINT UNSIGNED NOT NULL,
    failed_pct     DECIMAL(12,4) NOT NULL,
    status         ENUM('PASS','FAIL') NOT NULL,
    expected_result VARCHAR(255) NULL,
    PRIMARY KEY (check_id)
);

SET @batch_rows = (
    SELECT COUNT(*) FROM stg_supply_chain WHERE load_batch_id = @batch_id
);

-- 1. Volume and grain checks
INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Volume', 'Batch contains at least 180,000 rows', 'Critical',
       IF(@batch_rows >= @expected_min_rows, 0, @batch_rows), @batch_rows,
       IF(@batch_rows >= @expected_min_rows, 0, 100),
       IF(@batch_rows >= @expected_min_rows, 'PASS', 'FAIL'),
       'At least 180,000 rows';

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Primary Key', 'order_item_id is not null', 'Critical',
       SUM(order_item_id IS NULL), COUNT(*),
       ROUND(SUM(order_item_id IS NULL) / NULLIF(COUNT(*),0) * 100, 4),
       IF(SUM(order_item_id IS NULL)=0,'PASS','FAIL'), '0 null values'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Primary Key', 'order_item_id is unique inside the batch', 'Critical',
       COALESCE(SUM(duplicate_rows),0), @batch_rows,
       ROUND(COALESCE(SUM(duplicate_rows),0) / NULLIF(@batch_rows,0) * 100,4),
       IF(COALESCE(SUM(duplicate_rows),0)=0,'PASS','FAIL'), '0 duplicate rows'
FROM (
    SELECT COUNT(*) AS duplicate_rows
    FROM stg_supply_chain
    WHERE load_batch_id=@batch_id AND order_item_id IS NOT NULL
    GROUP BY order_item_id
    HAVING COUNT(*) > 1
) d;

-- 2. Required-field completeness
INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Completeness', 'Required business fields are populated', 'Critical',
       SUM(order_id IS NULL OR order_date IS NULL OR shipping_date IS NULL
           OR sales IS NULL OR order_item_quantity IS NULL),
       COUNT(*),
       ROUND(SUM(order_id IS NULL OR order_date IS NULL OR shipping_date IS NULL
           OR sales IS NULL OR order_item_quantity IS NULL) / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(order_id IS NULL OR order_date IS NULL OR shipping_date IS NULL
           OR sales IS NULL OR order_item_quantity IS NULL)=0,'PASS','FAIL'),
       '0 rows missing required fields'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

-- 3. Date and numeric business rules
INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Date', 'shipping_date is not earlier than order_date', 'Critical',
       SUM(shipping_date < order_date), COUNT(*),
       ROUND(SUM(shipping_date < order_date) / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(shipping_date < order_date)=0,'PASS','FAIL'),
       'shipping_date >= order_date'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Numeric Range', 'Sales, quantity, prices, and shipping days are valid', 'High',
       SUM(sales < 0 OR order_item_quantity <= 0 OR order_item_product_price < 0
           OR days_for_shipping_real < 0 OR days_for_shipment_scheduled < 0),
       COUNT(*),
       ROUND(SUM(sales < 0 OR order_item_quantity <= 0 OR order_item_product_price < 0
           OR days_for_shipping_real < 0 OR days_for_shipment_scheduled < 0)
           / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(sales < 0 OR order_item_quantity <= 0 OR order_item_product_price < 0
           OR days_for_shipping_real < 0 OR days_for_shipment_scheduled < 0)=0,'PASS','FAIL'),
       'No invalid negative values; quantity > 0'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Numeric Range', 'Discount rates are within valid ranges', 'High',
       SUM((order_item_discount_rate < 0 OR order_item_discount_rate > 1)
           OR (discount_rate_pct < 0 OR discount_rate_pct > 100)),
       COUNT(*),
       ROUND(SUM((order_item_discount_rate < 0 OR order_item_discount_rate > 1)
           OR (discount_rate_pct < 0 OR discount_rate_pct > 100))
           / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM((order_item_discount_rate < 0 OR order_item_discount_rate > 1)
           OR (discount_rate_pct < 0 OR discount_rate_pct > 100))=0,'PASS','FAIL'),
       'Raw rate 0–1 and percentage 0–100'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Geography', 'Latitude and longitude are valid', 'High',
       SUM((latitude < -90 OR latitude > 90) OR (longitude < -180 OR longitude > 180)),
       COUNT(*),
       ROUND(SUM((latitude < -90 OR latitude > 90) OR (longitude < -180 OR longitude > 180))
           / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM((latitude < -90 OR latitude > 90) OR (longitude < -180 OR longitude > 180))=0,
          'PASS','FAIL'),
       'Latitude -90–90; longitude -180–180'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

-- 4. Engineered-feature consistency
INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Feature Consistency', 'shipping_delay_days formula is correct', 'Critical',
       SUM(NOT (shipping_delay_days <=> (days_for_shipping_real-days_for_shipment_scheduled))),
       COUNT(*),
       ROUND(SUM(NOT (shipping_delay_days <=> (days_for_shipping_real-days_for_shipment_scheduled)))
             / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(NOT (shipping_delay_days <=> (days_for_shipping_real-days_for_shipment_scheduled)))=0,
          'PASS','FAIL'),
       'actual days - scheduled days'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Feature Consistency', 'is_late_delivery agrees with shipping delay', 'Critical',
       SUM(is_late_delivery <> IF(shipping_delay_days > 0,1,0)
           OR is_late_delivery IS NULL),
       COUNT(*),
       ROUND(SUM(is_late_delivery <> IF(shipping_delay_days > 0,1,0)
           OR is_late_delivery IS NULL) / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(is_late_delivery <> IF(shipping_delay_days > 0,1,0)
           OR is_late_delivery IS NULL)=0,'PASS','FAIL'),
       '1 only when shipping_delay_days > 0'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Feature Consistency', 'Gross sales equals sales plus discount', 'High',
       SUM(ABS(gross_sales_before_discount-(sales+order_item_discount)) > 0.02
           OR gross_sales_before_discount IS NULL),
       COUNT(*),
       ROUND(SUM(ABS(gross_sales_before_discount-(sales+order_item_discount)) > 0.02
           OR gross_sales_before_discount IS NULL) / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(ABS(gross_sales_before_discount-(sales+order_item_discount)) > 0.02
           OR gross_sales_before_discount IS NULL)=0,'PASS','FAIL'),
       'Difference <= 0.02'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Feature Consistency', 'Profit margin formula is correct', 'High',
       SUM(CASE WHEN sales <> 0 AND order_profit_per_order IS NOT NULL
                THEN ABS(profit_margin_pct-(order_profit_per_order/sales*100)) > 0.02
                ELSE FALSE END),
       COUNT(*),
       ROUND(SUM(CASE WHEN sales <> 0 AND order_profit_per_order IS NOT NULL
                THEN ABS(profit_margin_pct-(order_profit_per_order/sales*100)) > 0.02
                ELSE FALSE END) / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM(CASE WHEN sales <> 0 AND order_profit_per_order IS NOT NULL
                THEN ABS(profit_margin_pct-(order_profit_per_order/sales*100)) > 0.02
                ELSE FALSE END)=0,'PASS','FAIL'),
       'Difference <= 0.02 percentage point'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

-- 5. Domain checks
INSERT INTO tmp_data_quality_results
(category, check_name, severity, failed_rows, total_rows, failed_pct, status, expected_result)
SELECT 'Domain', 'Binary fields contain only 0 or 1', 'High',
       SUM((late_delivery_risk NOT IN (0,1) AND late_delivery_risk IS NOT NULL)
           OR (is_late_delivery NOT IN (0,1) AND is_late_delivery IS NOT NULL)
           OR (is_on_time_delivery NOT IN (0,1) AND is_on_time_delivery IS NOT NULL)
           OR (is_profitable_item NOT IN (0,1) AND is_profitable_item IS NOT NULL)
           OR (is_loss_item NOT IN (0,1) AND is_loss_item IS NOT NULL)),
       COUNT(*),
       ROUND(SUM((late_delivery_risk NOT IN (0,1) AND late_delivery_risk IS NOT NULL)
           OR (is_late_delivery NOT IN (0,1) AND is_late_delivery IS NOT NULL)
           OR (is_on_time_delivery NOT IN (0,1) AND is_on_time_delivery IS NOT NULL)
           OR (is_profitable_item NOT IN (0,1) AND is_profitable_item IS NOT NULL)
           OR (is_loss_item NOT IN (0,1) AND is_loss_item IS NOT NULL))
           / NULLIF(COUNT(*),0) * 100,4),
       IF(SUM((late_delivery_risk NOT IN (0,1) AND late_delivery_risk IS NOT NULL)
           OR (is_late_delivery NOT IN (0,1) AND is_late_delivery IS NOT NULL)
           OR (is_on_time_delivery NOT IN (0,1) AND is_on_time_delivery IS NOT NULL)
           OR (is_profitable_item NOT IN (0,1) AND is_profitable_item IS NOT NULL)
           OR (is_loss_item NOT IN (0,1) AND is_loss_item IS NOT NULL))=0,'PASS','FAIL'),
       'Only 0, 1, or NULL'
FROM stg_supply_chain WHERE load_batch_id=@batch_id;

-- ---------------------------------------------------------------------------
-- VALIDATION SCORE AND GO/NO-GO DECISION
-- ---------------------------------------------------------------------------
SELECT
    category,
    check_name,
    severity,
    failed_rows,
    total_rows,
    failed_pct,
    status,
    expected_result
FROM tmp_data_quality_results
ORDER BY FIELD(severity,'Critical','High','Medium','Low','Info'), check_id;

SELECT
    COUNT(*) AS total_checks,
    SUM(status='PASS') AS passed_checks,
    SUM(status='FAIL') AS failed_checks,
    SUM(severity='Critical' AND status='FAIL') AS critical_failures,
    SUM(severity='High' AND status='FAIL') AS high_failures,
    ROUND(SUM(status='PASS')/COUNT(*)*100,2) AS unweighted_readiness_score,
    CASE
        WHEN SUM(severity='Critical' AND status='FAIL') > 0 THEN 'NOT READY'
        WHEN SUM(severity='High' AND status='FAIL') > 0 THEN 'READY WITH WARNINGS'
        ELSE 'READY'
    END AS warehouse_load_decision
FROM tmp_data_quality_results;

-- ---------------------------------------------------------------------------
-- REPRESENTATIVE ISSUE RECORDS
-- ---------------------------------------------------------------------------
SELECT 'duplicate_order_item_id' AS issue_type, order_item_id, COUNT(*) AS occurrences
FROM stg_supply_chain
WHERE load_batch_id=@batch_id AND order_item_id IS NOT NULL
GROUP BY order_item_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 100;

SELECT
    staging_row_id,
    order_item_id,
    order_id,
    order_date,
    shipping_date,
    sales,
    order_item_quantity,
    shipping_delay_days,
    is_late_delivery
FROM stg_supply_chain
WHERE load_batch_id=@batch_id
  AND (
      order_item_id IS NULL OR order_id IS NULL OR order_date IS NULL
      OR shipping_date IS NULL OR shipping_date < order_date
      OR sales IS NULL OR sales < 0 OR order_item_quantity IS NULL
      OR order_item_quantity <= 0
      OR NOT (shipping_delay_days <=> (days_for_shipping_real-days_for_shipment_scheduled))
      OR is_late_delivery <> IF(shipping_delay_days > 0,1,0)
  )
LIMIT 100;

-- ---------------------------------------------------------------------------
-- BUSINESS RECONCILIATION SUMMARY
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT order_item_id) AS distinct_order_items,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT(DISTINCT product_card_id) AS distinct_products,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(order_profit_per_order),2) AS total_profit,
    ROUND(SUM(order_profit_per_order)/NULLIF(SUM(sales),0)*100,2) AS profit_margin_pct,
    ROUND(AVG(is_late_delivery)*100,2) AS late_delivery_rate_pct
FROM stg_supply_chain
WHERE load_batch_id=@batch_id;
