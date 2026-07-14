/* ============================================================================
04_window_functions.sql
NEXORA SUPPLY CHAIN ANALYTICS
Purpose : Demonstrate SQL Window Functions (MySQL 8.0+)
============================================================================ */

USE nexora_supply_chain;

-- Q1. ROW_NUMBER - Sales ranking by product
SELECT
    p.product_name,
    SUM(f.sales) AS total_sales,
    ROW_NUMBER() OVER(ORDER BY SUM(f.sales) DESC) AS row_num
FROM fact_order_item f
JOIN dim_product p ON p.product_key=f.product_key
GROUP BY p.product_name;

-- Q2. RANK - Top products by profit
SELECT
    p.product_name,
    SUM(f.order_profit_per_order) AS total_profit,
    RANK() OVER(ORDER BY SUM(f.order_profit_per_order) DESC) AS profit_rank
FROM fact_order_item f
JOIN dim_product p ON p.product_key=f.product_key
GROUP BY p.product_name;

-- Q3. DENSE_RANK - Categories by sales
SELECT
    c.category_name,
    SUM(f.sales) AS total_sales,
    DENSE_RANK() OVER(ORDER BY SUM(f.sales) DESC) AS sales_rank
FROM fact_order_item f
JOIN dim_category c ON c.category_key=f.category_key
GROUP BY c.category_name;

-- Q4. ROW_NUMBER partitioned by market
SELECT
    g.market,
    c.category_name,
    SUM(f.sales) AS total_sales,
    ROW_NUMBER() OVER(
        PARTITION BY g.market
        ORDER BY SUM(f.sales) DESC
    ) AS market_rank
FROM fact_order_item f
JOIN dim_geography g ON g.geography_key=f.geography_key
JOIN dim_category c ON c.category_key=f.category_key
GROUP BY g.market,c.category_name;

-- Q5. LAG - Monthly sales comparison
WITH monthly AS (
SELECT
 d.calendar_year,
 d.calendar_month,
 d.calendar_year_month,
 SUM(f.sales) total_sales
FROM fact_order_item f
JOIN dim_date d ON d.date_key=f.order_date_key
GROUP BY d.calendar_year,d.calendar_month,d.calendar_year_month
)
SELECT *,
LAG(total_sales) OVER(ORDER BY calendar_year,calendar_month) AS previous_month_sales,
total_sales-LAG(total_sales) OVER(ORDER BY calendar_year,calendar_month) AS sales_change
FROM monthly;

-- Q6. LEAD - Next month sales
WITH monthly AS (
SELECT
 d.calendar_year,
 d.calendar_month,
 d.calendar_year_month,
 SUM(f.sales) total_sales
FROM fact_order_item f
JOIN dim_date d ON d.date_key=f.order_date_key
GROUP BY d.calendar_year,d.calendar_month,d.calendar_year_month
)
SELECT *,
LEAD(total_sales) OVER(ORDER BY calendar_year,calendar_month) AS next_month_sales
FROM monthly;

-- Q7. Running total sales
SELECT
 d.calendar_year_month,
 SUM(f.sales) AS monthly_sales,
 SUM(SUM(f.sales)) OVER(
   ORDER BY d.calendar_year,d.calendar_month
 ) AS running_total_sales
FROM fact_order_item f
JOIN dim_date d ON d.date_key=f.order_date_key
GROUP BY d.calendar_year,d.calendar_month,d.calendar_year_month;

-- Q8. Moving average (3 months)
WITH monthly AS (
SELECT
 d.calendar_year,
 d.calendar_month,
 d.calendar_year_month,
 SUM(f.sales) total_sales
FROM fact_order_item f
JOIN dim_date d ON d.date_key=f.order_date_key
GROUP BY d.calendar_year,d.calendar_month,d.calendar_year_month
)
SELECT *,
AVG(total_sales) OVER(
 ORDER BY calendar_year,calendar_month
 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
) AS moving_avg_3_months
FROM monthly;

-- Q9. NTILE customer segmentation
SELECT
 c.customer_id,
 SUM(f.sales) AS total_sales,
 NTILE(4) OVER(ORDER BY SUM(f.sales) DESC) AS sales_quartile
FROM fact_order_item f
JOIN dim_customer c ON c.customer_key=f.customer_key
GROUP BY c.customer_id;

-- Q10. FIRST_VALUE / LAST_VALUE
WITH market_sales AS (
SELECT
 g.market,
 d.calendar_year_month,
 SUM(f.sales) total_sales
FROM fact_order_item f
JOIN dim_geography g ON g.geography_key=f.geography_key
JOIN dim_date d ON d.date_key=f.order_date_key
GROUP BY g.market,d.calendar_year_month,d.calendar_year,d.calendar_month
)
SELECT
 market,
 calendar_year_month,
 total_sales,
 FIRST_VALUE(total_sales) OVER(
   PARTITION BY market
   ORDER BY calendar_year_month
 ) AS first_month_sales,
 LAST_VALUE(total_sales) OVER(
   PARTITION BY market
   ORDER BY calendar_year_month
   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
 ) AS last_month_sales
FROM market_sales;
