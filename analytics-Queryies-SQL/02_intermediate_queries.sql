/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 02_intermediate_queries.sql
   Purpose       : Intermediate SQL analysis using JOIN, CASE, HAVING,
                   COALESCE, UNION ALL, and grouped business logic.
   Compatibility : MySQL 8.0+ / MySQL Workbench
   ============================================================================ */

USE nexora_supply_chain;

-- ============================================================================
-- Q1. Sales and profit by customer segment
-- ============================================================================
SELECT
    c.customer_segment,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,
    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
GROUP BY c.customer_segment
ORDER BY total_sales DESC;

-- ============================================================================
-- Q2. Classify categories by sales performance
-- ============================================================================
SELECT
    c.category_name,
    ROUND(SUM(f.sales), 2) AS total_sales,
    CASE
        WHEN SUM(f.sales) >= 1000000 THEN 'High Sales'
        WHEN SUM(f.sales) >= 500000 THEN 'Medium Sales'
        ELSE 'Low Sales'
    END AS sales_performance_group
FROM fact_order_item AS f
JOIN dim_category AS c
    ON c.category_key = f.category_key
GROUP BY c.category_name
ORDER BY total_sales DESC;

-- ============================================================================
-- Q3. Categories with sales above average category sales
-- ============================================================================
SELECT
    c.category_name,
    ROUND(SUM(f.sales), 2) AS total_sales
FROM fact_order_item AS f
JOIN dim_category AS c
    ON c.category_key = f.category_key
GROUP BY c.category_name
HAVING SUM(f.sales) > (
    SELECT AVG(category_sales)
    FROM (
        SELECT SUM(sales) AS category_sales
        FROM fact_order_item
        GROUP BY category_key
    ) AS category_summary
)
ORDER BY total_sales DESC;

-- ============================================================================
-- Q4. Shipping mode service-level performance
-- ============================================================================
SELECT
    sm.shipping_mode,
    sm.service_level_group,
    COUNT(*) AS order_item_rows,
    ROUND(AVG(f.days_for_shipping_real), 2) AS avg_actual_days,
    ROUND(AVG(f.days_for_shipment_scheduled), 2) AS avg_scheduled_days,
    ROUND(AVG(f.shipping_delay_days), 2) AS avg_delay_days,
    ROUND(AVG(f.is_late_delivery) * 100, 2) AS late_delivery_rate_pct
FROM fact_order_item AS f
JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode_key = f.shipping_mode_key
GROUP BY
    sm.shipping_mode,
    sm.service_level_group
ORDER BY late_delivery_rate_pct DESC;

-- ============================================================================
-- Q5. Market profitability with status classification
-- ============================================================================
SELECT
    g.market,
    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,
    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,
    CASE
        WHEN SUM(f.order_profit_per_order) < 0 THEN 'Loss Market'
        WHEN SUM(f.order_profit_per_order)
             / NULLIF(SUM(f.sales), 0) * 100 >= 15
            THEN 'Strong Margin'
        ELSE 'Moderate Margin'
    END AS profitability_status
FROM fact_order_item AS f
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
GROUP BY g.market
ORDER BY total_profit DESC;

-- ============================================================================
-- Q6. Product performance with NULL-safe category labels
-- ============================================================================
SELECT
    COALESCE(p.product_name, 'Unknown Product') AS product_name,
    COALESCE(p.category_name, 'Unknown Category') AS category_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.order_item_quantity) AS total_quantity,
    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit
FROM fact_order_item AS f
LEFT JOIN dim_product AS p
    ON p.product_key = f.product_key
GROUP BY
    COALESCE(p.product_name, 'Unknown Product'),
    COALESCE(p.category_name, 'Unknown Category')
ORDER BY total_sales DESC
LIMIT 20;

-- ============================================================================
-- Q7. Monthly performance with year-over-year classification
-- ============================================================================
SELECT
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,
    CASE
        WHEN SUM(f.order_profit_per_order) > 0 THEN 'Profitable Month'
        WHEN SUM(f.order_profit_per_order) = 0 THEN 'Break Even Month'
        ELSE 'Loss Month'
    END AS month_status
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
-- Q8. Combine profitable and loss-making order items
-- ============================================================================
SELECT
    'Profitable Items' AS item_group,
    COUNT(*) AS item_count,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(order_profit_per_order), 2) AS total_profit
FROM fact_order_item
WHERE order_profit_per_order > 0

UNION ALL

SELECT
    'Loss Items',
    COUNT(*),
    ROUND(SUM(sales), 2),
    ROUND(SUM(order_profit_per_order), 2)
FROM fact_order_item
WHERE order_profit_per_order < 0;

-- ============================================================================
-- Q9. Customers with more than 5 orders
-- ============================================================================
SELECT
    c.customer_id,
    c.customer_segment,
    c.customer_country,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_id,
    c.customer_segment,
    c.customer_country
HAVING COUNT(DISTINCT f.order_id) > 5
ORDER BY total_sales DESC;

-- ============================================================================
-- Q10. Operational risk summary by market
-- ============================================================================
SELECT
    g.market,
    f.operational_risk_segment,
    COUNT(*) AS order_item_rows,
    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,
    ROUND(AVG(f.shipping_delay_days), 2) AS avg_delay_days,
    ROUND(AVG(f.requires_management_attention) * 100, 2)
        AS management_attention_rate_pct
FROM fact_order_item AS f
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
GROUP BY
    g.market,
    f.operational_risk_segment
ORDER BY
    g.market,
    order_item_rows DESC;
