/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 03_advanced_queries.sql
   Purpose       : Advanced SQL analysis using subqueries, correlated subqueries,
                   EXISTS, derived tables, anti-joins, and analytical logic.
   Compatibility : MySQL 8.0+ / MySQL Workbench
   ============================================================================ */

USE nexora_supply_chain;

-- ============================================================================
-- Q1. Products with sales above the overall product average
-- ============================================================================
SELECT
    p.product_name,
    ROUND(SUM(f.sales), 2) AS total_sales
FROM fact_order_item AS f
JOIN dim_product AS p
    ON p.product_key = f.product_key
GROUP BY p.product_name
HAVING SUM(f.sales) > (
    SELECT AVG(product_sales)
    FROM (
        SELECT SUM(sales) AS product_sales
        FROM fact_order_item
        GROUP BY product_key
    ) AS product_totals
)
ORDER BY total_sales DESC;

-- ============================================================================
-- Q2. Customers whose lifetime sales exceed their segment average
-- ============================================================================
SELECT
    c.customer_id,
    c.customer_segment,
    ROUND(SUM(f.sales), 2) AS customer_sales
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_id,
    c.customer_segment
HAVING SUM(f.sales) > (
    SELECT AVG(segment_customer_sales)
    FROM (
        SELECT
            c2.customer_segment,
            c2.customer_id,
            SUM(f2.sales) AS segment_customer_sales
        FROM fact_order_item AS f2
        JOIN dim_customer AS c2
            ON c2.customer_key = f2.customer_key
        GROUP BY
            c2.customer_segment,
            c2.customer_id
    ) AS customer_segment_totals
    WHERE customer_segment_totals.customer_segment = c.customer_segment
)
ORDER BY customer_sales DESC;

-- ============================================================================
-- Q3. Categories containing at least one loss-making product
-- ============================================================================
SELECT DISTINCT
    c.category_name
FROM dim_category AS c
WHERE EXISTS (
    SELECT 1
    FROM fact_order_item AS f
    JOIN dim_product AS p
        ON p.product_key = f.product_key
    WHERE f.category_key = c.category_key
      AND f.order_profit_per_order < 0
);

-- ============================================================================
-- Q4. Products that never generated a loss
-- ============================================================================
SELECT
    p.product_name
FROM dim_product AS p
WHERE p.product_key <> 0
  AND NOT EXISTS (
      SELECT 1
      FROM fact_order_item AS f
      WHERE f.product_key = p.product_key
        AND f.order_profit_per_order < 0
  )
ORDER BY p.product_name;

-- ============================================================================
-- Q5. Top-performing market using a derived table
-- ============================================================================
SELECT
    market,
    total_sales,
    total_profit,
    profit_margin_pct
FROM (
    SELECT
        g.market,
        ROUND(SUM(f.sales), 2) AS total_sales,
        ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,
        ROUND(
            SUM(f.order_profit_per_order)
            / NULLIF(SUM(f.sales), 0) * 100,
            2
        ) AS profit_margin_pct
    FROM fact_order_item AS f
    JOIN dim_geography AS g
        ON g.geography_key = f.geography_key
    GROUP BY g.market
) AS market_summary
ORDER BY total_profit DESC
LIMIT 1;

-- ============================================================================
-- Q6. Orders with sales above the average order value
-- ============================================================================
SELECT
    order_id,
    ROUND(SUM(sales), 2) AS order_sales
FROM fact_order_item
GROUP BY order_id
HAVING SUM(sales) > (
    SELECT AVG(order_sales)
    FROM (
        SELECT SUM(sales) AS order_sales
        FROM fact_order_item
        GROUP BY order_id
    ) AS order_totals
)
ORDER BY order_sales DESC;

-- ============================================================================
-- Q7. Markets with late-delivery rate above the global average
-- ============================================================================
SELECT
    g.market,
    ROUND(AVG(f.is_late_delivery) * 100, 2) AS market_late_rate_pct
FROM fact_order_item AS f
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
GROUP BY g.market
HAVING AVG(f.is_late_delivery) > (
    SELECT AVG(is_late_delivery)
    FROM fact_order_item
)
ORDER BY market_late_rate_pct DESC;

-- ============================================================================
-- Q8. Customer segments contributing at least 20% of total sales
-- ============================================================================
SELECT
    c.customer_segment,
    ROUND(SUM(f.sales), 2) AS segment_sales,
    ROUND(
        SUM(f.sales)
        / (SELECT SUM(sales) FROM fact_order_item) * 100,
        2
    ) AS sales_contribution_pct
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
GROUP BY c.customer_segment
HAVING
    SUM(f.sales)
    / (SELECT SUM(sales) FROM fact_order_item) >= 0.20
ORDER BY segment_sales DESC;

-- ============================================================================
-- Q9. Find orphan dimension keys using anti-join logic
-- Expected result: no rows
-- ============================================================================
SELECT
    f.fact_order_item_key,
    f.order_item_id,
    f.customer_key,
    f.product_key,
    f.category_key
FROM fact_order_item AS f
LEFT JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
LEFT JOIN dim_product AS p
    ON p.product_key = f.product_key
LEFT JOIN dim_category AS cat
    ON cat.category_key = f.category_key
WHERE
    c.customer_key IS NULL
    OR p.product_key IS NULL
    OR cat.category_key IS NULL;

-- ============================================================================
-- Q10. Compare category profit to department average profit
-- ============================================================================
SELECT
    category_name,
    department_name,
    total_profit,
    department_average_profit,
    ROUND(total_profit - department_average_profit, 2)
        AS difference_from_department_average
FROM (
    SELECT
        category_name,
        department_name,
        total_profit,
        AVG(total_profit) OVER (
            PARTITION BY department_name
        ) AS department_average_profit
    FROM (
        SELECT
            c.category_name,
            c.department_name,
            SUM(f.order_profit_per_order) AS total_profit
        FROM fact_order_item AS f
        JOIN dim_category AS c
            ON c.category_key = f.category_key
        GROUP BY
            c.category_name,
            c.department_name
    ) AS category_profit
) AS department_comparison
ORDER BY difference_from_department_average DESC;
