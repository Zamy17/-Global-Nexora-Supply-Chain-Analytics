/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 05_cte_queries.sql
   Purpose       : Common Table Expression (CTE) analysis for supply-chain,
                   customer, product, profitability, and delivery performance.
   Compatibility : MySQL 8.0+ / MySQL Workbench
   ============================================================================ */

USE nexora_supply_chain;

-- ============================================================================
-- Q1. Monthly sales and profit trend
-- ============================================================================
WITH monthly_performance AS (
    SELECT
        d.calendar_year,
        d.calendar_month,
        d.calendar_year_month,
        SUM(f.sales) AS total_sales,
        SUM(f.order_profit_per_order) AS total_profit,
        COUNT(DISTINCT f.order_id) AS total_orders
    FROM fact_order_item AS f
    JOIN dim_date AS d
        ON d.date_key = f.order_date_key
    GROUP BY
        d.calendar_year,
        d.calendar_month,
        d.calendar_year_month
)
SELECT
    calendar_year,
    calendar_month,
    calendar_year_month,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    total_orders,
    ROUND(
        total_profit / NULLIF(total_sales, 0) * 100,
        2
    ) AS profit_margin_pct
FROM monthly_performance
ORDER BY
    calendar_year,
    calendar_month;

-- ============================================================================
-- Q2. Top 10 products by sales
-- ============================================================================
WITH product_sales AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category_name,
        SUM(f.sales) AS total_sales,
        SUM(f.order_profit_per_order) AS total_profit,
        SUM(f.order_item_quantity) AS total_quantity
    FROM fact_order_item AS f
    JOIN dim_product AS p
        ON p.product_key = f.product_key
    GROUP BY
        p.product_key,
        p.product_name,
        p.category_name
)
SELECT
    product_name,
    category_name,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    total_quantity
FROM product_sales
ORDER BY total_sales DESC
LIMIT 10;

-- ============================================================================
-- Q3. High-value customers above average customer sales
-- ============================================================================
WITH customer_sales AS (
    SELECT
        c.customer_key,
        c.customer_id,
        c.customer_segment,
        c.customer_country,
        SUM(f.sales) AS total_sales,
        SUM(f.order_profit_per_order) AS total_profit,
        COUNT(DISTINCT f.order_id) AS total_orders
    FROM fact_order_item AS f
    JOIN dim_customer AS c
        ON c.customer_key = f.customer_key
    GROUP BY
        c.customer_key,
        c.customer_id,
        c.customer_segment,
        c.customer_country
),
customer_benchmark AS (
    SELECT
        AVG(total_sales) AS average_customer_sales
    FROM customer_sales
)
SELECT
    cs.customer_id,
    cs.customer_segment,
    cs.customer_country,
    cs.total_orders,
    ROUND(cs.total_sales, 2) AS total_sales,
    ROUND(cs.total_profit, 2) AS total_profit,
    ROUND(cb.average_customer_sales, 2) AS average_customer_sales
FROM customer_sales AS cs
CROSS JOIN customer_benchmark AS cb
WHERE cs.total_sales > cb.average_customer_sales
ORDER BY cs.total_sales DESC;

-- ============================================================================
-- Q4. Category profitability ranking
-- ============================================================================
WITH category_profitability AS (
    SELECT
        c.category_key,
        c.category_name,
        c.department_name,
        SUM(f.sales) AS total_sales,
        SUM(f.order_profit_per_order) AS total_profit
    FROM fact_order_item AS f
    JOIN dim_category AS c
        ON c.category_key = f.category_key
    GROUP BY
        c.category_key,
        c.category_name,
        c.department_name
),
ranked_categories AS (
    SELECT
        category_name,
        department_name,
        total_sales,
        total_profit,
        total_profit / NULLIF(total_sales, 0) * 100
            AS profit_margin_pct,
        DENSE_RANK() OVER (
            ORDER BY total_profit DESC
        ) AS profit_rank
    FROM category_profitability
)
SELECT
    category_name,
    department_name,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(profit_margin_pct, 2) AS profit_margin_pct,
    profit_rank
FROM ranked_categories
ORDER BY profit_rank;

-- ============================================================================
-- Q5. Markets with late-delivery rate above the global average
-- ============================================================================
WITH market_delivery AS (
    SELECT
        g.market,
        COUNT(*) AS order_item_rows,
        AVG(f.is_late_delivery) AS late_delivery_rate
    FROM fact_order_item AS f
    JOIN dim_geography AS g
        ON g.geography_key = f.geography_key
    GROUP BY g.market
),
global_delivery AS (
    SELECT
        AVG(is_late_delivery) AS global_late_delivery_rate
    FROM fact_order_item
)
SELECT
    md.market,
    md.order_item_rows,
    ROUND(md.late_delivery_rate * 100, 2)
        AS market_late_delivery_rate_pct,
    ROUND(gd.global_late_delivery_rate * 100, 2)
        AS global_late_delivery_rate_pct
FROM market_delivery AS md
CROSS JOIN global_delivery AS gd
WHERE md.late_delivery_rate > gd.global_late_delivery_rate
ORDER BY md.late_delivery_rate DESC;

-- ============================================================================
-- Q6. Shipping-mode service performance
-- ============================================================================
WITH shipping_performance AS (
    SELECT
        sm.shipping_mode,
        sm.service_level_group,
        COUNT(*) AS order_item_rows,
        AVG(f.days_for_shipping_real) AS avg_actual_days,
        AVG(f.days_for_shipment_scheduled) AS avg_scheduled_days,
        AVG(f.shipping_delay_days) AS avg_delay_days,
        AVG(f.is_late_delivery) AS late_delivery_rate
    FROM fact_order_item AS f
    JOIN dim_shipping_mode AS sm
        ON sm.shipping_mode_key = f.shipping_mode_key
    GROUP BY
        sm.shipping_mode,
        sm.service_level_group
)
SELECT
    shipping_mode,
    service_level_group,
    order_item_rows,
    ROUND(avg_actual_days, 2) AS avg_actual_days,
    ROUND(avg_scheduled_days, 2) AS avg_scheduled_days,
    ROUND(avg_delay_days, 2) AS avg_delay_days,
    ROUND(late_delivery_rate * 100, 2)
        AS late_delivery_rate_pct
FROM shipping_performance
ORDER BY late_delivery_rate DESC;

-- ============================================================================
-- Q7. Discount impact by discount band
-- ============================================================================
WITH discount_analysis AS (
    SELECT
        discount_band,
        COUNT(*) AS order_item_rows,
        SUM(sales) AS total_sales,
        SUM(order_profit_per_order) AS total_profit,
        AVG(discount_rate_pct) AS avg_discount_rate_pct,
        AVG(profit_margin_pct) AS avg_profit_margin_pct
    FROM fact_order_item
    GROUP BY discount_band
)
SELECT
    discount_band,
    order_item_rows,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(avg_discount_rate_pct, 2)
        AS avg_discount_rate_pct,
    ROUND(avg_profit_margin_pct, 2)
        AS avg_profit_margin_pct
FROM discount_analysis
ORDER BY avg_discount_rate_pct;

-- ============================================================================
-- Q8. Operational risk by category
-- ============================================================================
WITH category_risk AS (
    SELECT
        c.category_name,
        COUNT(*) AS order_item_rows,
        SUM(f.requires_management_attention)
            AS attention_items,
        AVG(f.is_late_delivery) AS late_delivery_rate,
        AVG(f.is_loss_item) AS loss_item_rate,
        SUM(f.sales) AS total_sales,
        SUM(f.order_profit_per_order) AS total_profit
    FROM fact_order_item AS f
    JOIN dim_category AS c
        ON c.category_key = f.category_key
    GROUP BY c.category_name
)
SELECT
    category_name,
    order_item_rows,
    attention_items,
    ROUND(
        attention_items / NULLIF(order_item_rows, 0) * 100,
        2
    ) AS attention_rate_pct,
    ROUND(late_delivery_rate * 100, 2)
        AS late_delivery_rate_pct,
    ROUND(loss_item_rate * 100, 2)
        AS loss_item_rate_pct,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit
FROM category_risk
ORDER BY attention_rate_pct DESC;

-- ============================================================================
-- Q9. Year-over-year sales growth
-- ============================================================================
WITH yearly_sales AS (
    SELECT
        d.calendar_year,
        SUM(f.sales) AS total_sales,
        SUM(f.order_profit_per_order) AS total_profit
    FROM fact_order_item AS f
    JOIN dim_date AS d
        ON d.date_key = f.order_date_key
    GROUP BY d.calendar_year
),
yearly_growth AS (
    SELECT
        calendar_year,
        total_sales,
        total_profit,
        LAG(total_sales) OVER (
            ORDER BY calendar_year
        ) AS previous_year_sales
    FROM yearly_sales
)
SELECT
    calendar_year,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(previous_year_sales, 2)
        AS previous_year_sales,
    ROUND(
        (total_sales - previous_year_sales)
        / NULLIF(previous_year_sales, 0) * 100,
        2
    ) AS sales_growth_pct
FROM yearly_growth
ORDER BY calendar_year;

-- ============================================================================
-- Q10. Recursive CTE to generate a simple month sequence
-- Demonstrates recursive CTE capability in MySQL 8.
-- ============================================================================
WITH RECURSIVE month_sequence AS (
    SELECT 1 AS month_number
    UNION ALL
    SELECT month_number + 1
    FROM month_sequence
    WHERE month_number < 12
),
monthly_sales AS (
    SELECT
        d.calendar_month,
        SUM(f.sales) AS total_sales
    FROM fact_order_item AS f
    JOIN dim_date AS d
        ON d.date_key = f.order_date_key
    GROUP BY d.calendar_month
)
SELECT
    msq.month_number,
    MONTHNAME(
        STR_TO_DATE(msq.month_number, '%m')
    ) AS month_name,
    ROUND(COALESCE(ms.total_sales, 0), 2)
        AS total_sales
FROM month_sequence AS msq
LEFT JOIN monthly_sales AS ms
    ON ms.calendar_month = msq.month_number
ORDER BY msq.month_number;
