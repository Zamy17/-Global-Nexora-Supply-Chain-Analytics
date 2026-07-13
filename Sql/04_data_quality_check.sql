/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 04_data_quality_check_final.sql
   Purpose       : Validate staging data before loading dimension tables.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   Expected staging result:
   - 180,519 rows
   - 180,519 unique order_item_id values
   - 180,519 valid order dates
   - 180,519 valid shipping dates
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

-- ============================================================================
-- 1. IDENTIFY THE LATEST LOAD BATCH
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
    COUNT(*) AS latest_batch_rows,
    MIN(loaded_at) AS load_started_at,
    MAX(loaded_at) AS load_completed_at
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 2. VOLUME AND UNIQUENESS CHECK
-- ============================================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_item_id) AS unique_order_item_ids,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicate_rows,
    CASE
        WHEN COUNT(*) = 180519
         AND COUNT(DISTINCT order_item_id) = 180519
        THEN 'PASS'
        ELSE 'FAIL'
    END AS volume_and_uniqueness_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 3. REQUIRED-FIELD COMPLETENESS
-- ============================================================================
SELECT
    SUM(order_item_id IS NULL) AS missing_order_item_id,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(product_card_id IS NULL) AS missing_product_card_id,
    SUM(category_id IS NULL) AS missing_category_id,
    SUM(order_date IS NULL) AS missing_order_date,
    SUM(shipping_date IS NULL) AS missing_shipping_date,
    SUM(sales IS NULL) AS missing_sales,
    SUM(order_item_quantity IS NULL) AS missing_quantity,
    CASE
        WHEN
            SUM(order_item_id IS NULL) = 0
            AND SUM(order_id IS NULL) = 0
            AND SUM(customer_id IS NULL) = 0
            AND SUM(product_card_id IS NULL) = 0
            AND SUM(category_id IS NULL) = 0
            AND SUM(order_date IS NULL) = 0
            AND SUM(shipping_date IS NULL) = 0
            AND SUM(sales IS NULL) = 0
            AND SUM(order_item_quantity IS NULL) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS completeness_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 4. DUPLICATE BUSINESS KEY CHECK
-- ============================================================================
SELECT
    order_item_id,
    COUNT(*) AS duplicate_count
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id
GROUP BY order_item_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, order_item_id
LIMIT 100;

-- ============================================================================
-- 5. DATE VALIDATION
-- ============================================================================
SELECT
    COUNT(order_date) AS valid_order_dates,
    COUNT(shipping_date) AS valid_shipping_dates,
    SUM(order_date IS NULL) AS null_order_dates,
    SUM(shipping_date IS NULL) AS null_shipping_dates,
    SUM(shipping_date < order_date) AS shipping_before_order,
    MIN(order_date) AS minimum_order_date,
    MAX(order_date) AS maximum_order_date,
    MIN(shipping_date) AS minimum_shipping_date,
    MAX(shipping_date) AS maximum_shipping_date,
    CASE
        WHEN
            COUNT(order_date) = COUNT(*)
            AND COUNT(shipping_date) = COUNT(*)
            AND SUM(shipping_date < order_date) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS date_quality_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 6. NUMERIC BUSINESS-RULE CHECKS
-- ============================================================================
SELECT
    SUM(sales < 0) AS negative_sales,
    SUM(order_item_quantity <= 0) AS invalid_quantity,
    SUM(order_item_product_price < 0) AS negative_item_price,
    SUM(product_price < 0) AS negative_product_price,
    SUM(order_item_discount < 0) AS negative_discount,
    SUM(days_for_shipping_real < 0) AS negative_actual_shipping_days,
    SUM(days_for_shipment_scheduled < 0) AS negative_scheduled_shipping_days,
    CASE
        WHEN
            SUM(sales < 0) = 0
            AND SUM(order_item_quantity <= 0) = 0
            AND SUM(order_item_product_price < 0) = 0
            AND SUM(product_price < 0) = 0
            AND SUM(order_item_discount < 0) = 0
            AND SUM(days_for_shipping_real < 0) = 0
            AND SUM(days_for_shipment_scheduled < 0) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS numeric_rule_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 7. DISCOUNT-RATE VALIDATION
-- ============================================================================
SELECT
    SUM(
        order_item_discount_rate < 0
        OR order_item_discount_rate > 1
    ) AS invalid_raw_discount_rate,
    SUM(
        discount_rate_pct < 0
        OR discount_rate_pct > 100
    ) AS invalid_discount_rate_pct,
    CASE
        WHEN
            SUM(
                order_item_discount_rate < 0
                OR order_item_discount_rate > 1
            ) = 0
            AND SUM(
                discount_rate_pct < 0
                OR discount_rate_pct > 100
            ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS discount_rate_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 8. GEOGRAPHIC RANGE VALIDATION
-- ============================================================================
SELECT
    SUM(latitude < -90 OR latitude > 90) AS invalid_latitude,
    SUM(longitude < -180 OR longitude > 180) AS invalid_longitude,
    CASE
        WHEN
            SUM(latitude < -90 OR latitude > 90) = 0
            AND SUM(longitude < -180 OR longitude > 180) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS geography_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 9. SHIPPING FEATURE CONSISTENCY
-- ============================================================================
SELECT
    SUM(
        ABS(
            shipping_delay_days
            - (
                days_for_shipping_real
                - days_for_shipment_scheduled
              )
        ) > 0.0001
    ) AS invalid_shipping_delay,

    SUM(
        is_late_delivery
        <> CASE
               WHEN days_for_shipping_real
                  > days_for_shipment_scheduled
               THEN 1
               ELSE 0
           END
    ) AS invalid_late_delivery_flag,

    SUM(
        is_on_time_delivery
        <> CASE
               WHEN days_for_shipping_real
                  <= days_for_shipment_scheduled
               THEN 1
               ELSE 0
           END
    ) AS invalid_on_time_flag,

    CASE
        WHEN
            SUM(
                ABS(
                    shipping_delay_days
                    - (
                        days_for_shipping_real
                        - days_for_shipment_scheduled
                      )
                ) > 0.0001
            ) = 0
            AND SUM(
                is_late_delivery
                <> CASE
                       WHEN days_for_shipping_real
                          > days_for_shipment_scheduled
                       THEN 1
                       ELSE 0
                   END
            ) = 0
            AND SUM(
                is_on_time_delivery
                <> CASE
                       WHEN days_for_shipping_real
                          <= days_for_shipment_scheduled
                       THEN 1
                       ELSE 0
                   END
            ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS shipping_feature_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 10. FINANCIAL FEATURE CONSISTENCY
-- ============================================================================
SELECT
    SUM(
        ABS(
            gross_sales_before_discount
            - (sales + order_item_discount)
        ) > 0.01
    ) AS invalid_gross_sales,

    SUM(
        sales <> 0
        AND ABS(
            profit_margin_pct
            - ((order_profit_per_order / sales) * 100)
        ) > 0.05
    ) AS invalid_profit_margin,

    SUM(
        profitability_status
        <> CASE
               WHEN order_profit_per_order > 0 THEN 'Profitable'
               WHEN order_profit_per_order = 0 THEN 'Break Even'
               WHEN order_profit_per_order < 0 THEN 'Loss'
               ELSE 'Unknown'
           END
    ) AS invalid_profitability_status,

    CASE
        WHEN
            SUM(
                ABS(
                    gross_sales_before_discount
                    - (sales + order_item_discount)
                ) > 0.01
            ) = 0
            AND SUM(
                sales <> 0
                AND ABS(
                    profit_margin_pct
                    - ((order_profit_per_order / sales) * 100)
                ) > 0.05
            ) = 0
            AND SUM(
                profitability_status
                <> CASE
                       WHEN order_profit_per_order > 0 THEN 'Profitable'
                       WHEN order_profit_per_order = 0 THEN 'Break Even'
                       WHEN order_profit_per_order < 0 THEN 'Loss'
                       ELSE 'Unknown'
                   END
            ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS financial_feature_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 11. BINARY FIELD VALIDATION
-- ============================================================================
SELECT
    SUM(is_late_delivery NOT IN (0, 1)) AS invalid_is_late_delivery,
    SUM(is_on_time_delivery NOT IN (0, 1)) AS invalid_is_on_time_delivery,
    SUM(is_profitable_item NOT IN (0, 1)) AS invalid_is_profitable_item,
    SUM(is_loss_item NOT IN (0, 1)) AS invalid_is_loss_item,
    SUM(is_weekend_order NOT IN (0, 1)) AS invalid_is_weekend_order,
    SUM(
        requires_management_attention NOT IN (0, 1)
    ) AS invalid_management_attention,
    CASE
        WHEN
            SUM(is_late_delivery NOT IN (0, 1)) = 0
            AND SUM(is_on_time_delivery NOT IN (0, 1)) = 0
            AND SUM(is_profitable_item NOT IN (0, 1)) = 0
            AND SUM(is_loss_item NOT IN (0, 1)) = 0
            AND SUM(is_weekend_order NOT IN (0, 1)) = 0
            AND SUM(
                requires_management_attention NOT IN (0, 1)
            ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS binary_field_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 12. CATEGORY DOMAIN VALIDATION
-- ============================================================================
SELECT
    SUM(
        delivery_performance NOT IN (
            'Late',
            'On Schedule',
            'Early',
            'Unknown'
        )
    ) AS invalid_delivery_performance,

    SUM(
        profitability_status NOT IN (
            'Profitable',
            'Break Even',
            'Loss',
            'Unknown'
        )
    ) AS invalid_profitability_status,

    SUM(
        operational_risk_segment NOT IN (
            'Late and Loss',
            'Late Only',
            'Loss Only',
            'Healthy'
        )
    ) AS invalid_operational_risk_segment,

    CASE
        WHEN
            SUM(
                delivery_performance NOT IN (
                    'Late',
                    'On Schedule',
                    'Early',
                    'Unknown'
                )
            ) = 0
            AND SUM(
                profitability_status NOT IN (
                    'Profitable',
                    'Break Even',
                    'Loss',
                    'Unknown'
                )
            ) = 0
            AND SUM(
                operational_risk_segment NOT IN (
                    'Late and Loss',
                    'Late Only',
                    'Loss Only',
                    'Healthy'
                )
            ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS categorical_domain_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 13. SAMPLE PROBLEMATIC ROWS
-- ============================================================================
SELECT
    staging_row_id,
    order_item_id,
    order_id,
    customer_id,
    product_card_id,
    order_date,
    shipping_date,
    sales,
    order_item_quantity,
    shipping_delay_days,
    is_late_delivery,
    profitability_status
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id
  AND (
        order_item_id IS NULL
        OR order_id IS NULL
        OR customer_id IS NULL
        OR product_card_id IS NULL
        OR order_date IS NULL
        OR shipping_date IS NULL
        OR shipping_date < order_date
        OR sales < 0
        OR order_item_quantity <= 0
        OR is_late_delivery NOT IN (0, 1)
      )
ORDER BY staging_row_id
LIMIT 100;

-- ============================================================================
-- 14. BUSINESS RECONCILIATION SUMMARY
-- ============================================================================
SELECT
    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT(DISTINCT product_card_id) AS distinct_products,
    COUNT(DISTINCT category_id) AS distinct_categories,
    COUNT(DISTINCT shipping_mode) AS distinct_shipping_modes,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(order_profit_per_order), 2) AS total_profit,
    ROUND(
        SUM(order_profit_per_order)
        / NULLIF(SUM(sales), 0)
        * 100,
        2
    ) AS overall_profit_margin_pct,
    ROUND(AVG(days_for_shipping_real), 2)
        AS average_actual_shipping_days,
    ROUND(AVG(is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 15. FINAL DATA-READINESS DECISION
-- ============================================================================
SELECT
    q.total_rows,
    q.unique_order_item_ids,
    q.duplicate_rows,
    q.missing_critical_fields,
    q.invalid_dates,
    q.shipping_before_order,
    q.invalid_numeric_rows,
    q.invalid_shipping_features,
    CASE
        WHEN
            q.total_rows = 180519
            AND q.unique_order_item_ids = 180519
            AND q.duplicate_rows = 0
            AND q.missing_critical_fields = 0
            AND q.invalid_dates = 0
            AND q.shipping_before_order = 0
            AND q.invalid_numeric_rows = 0
            AND q.invalid_shipping_features = 0
        THEN 'READY'
        WHEN
            q.total_rows >= 180000
            AND q.duplicate_rows = 0
            AND q.missing_critical_fields = 0
        THEN 'READY WITH WARNINGS'
        ELSE 'NOT READY'
    END AS final_data_readiness
FROM (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT order_item_id)
            AS unique_order_item_ids,
        COUNT(*) - COUNT(DISTINCT order_item_id)
            AS duplicate_rows,

        SUM(
            order_item_id IS NULL
            OR order_id IS NULL
            OR customer_id IS NULL
            OR product_card_id IS NULL
            OR category_id IS NULL
            OR sales IS NULL
        ) AS missing_critical_fields,

        SUM(
            order_date IS NULL
            OR shipping_date IS NULL
        ) AS invalid_dates,

        SUM(shipping_date < order_date)
            AS shipping_before_order,

        SUM(
            sales < 0
            OR order_item_quantity <= 0
            OR order_item_product_price < 0
            OR days_for_shipping_real < 0
            OR days_for_shipment_scheduled < 0
        ) AS invalid_numeric_rows,

        SUM(
            shipping_delay_days
            <> (
                days_for_shipping_real
                - days_for_shipment_scheduled
               )
            OR is_late_delivery
            <> CASE
                   WHEN days_for_shipping_real
                      > days_for_shipment_scheduled
                   THEN 1
                   ELSE 0
               END
        ) AS invalid_shipping_features
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
) AS q;
