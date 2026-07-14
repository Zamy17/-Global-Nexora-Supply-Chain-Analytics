/* ============================================================
01_basic_queries.sql
NEXORA SUPPLY CHAIN ANALYTICS
============================================================ */
USE nexora_supply_chain;

-- Q1
SELECT * FROM fact_order_item LIMIT 20;

-- Q2
SELECT COUNT(*) AS total_order_items
FROM fact_order_item;

-- Q3
SELECT COUNT(DISTINCT customer_key) AS total_customers
FROM fact_order_item;

-- Q4
SELECT ROUND(SUM(sales),2) total_sales,
       ROUND(SUM(order_profit_per_order),2) total_profit
FROM fact_order_item;

-- Q5
SELECT p.product_name,
       ROUND(SUM(f.sales),2) total_sales
FROM fact_order_item f
JOIN dim_product p ON f.product_key=p.product_key
GROUP BY p.product_name
ORDER BY total_sales DESC
LIMIT 10;

-- Q6
SELECT c.customer_segment,
       ROUND(SUM(f.sales),2) total_sales
FROM fact_order_item f
JOIN dim_customer c ON f.customer_key=c.customer_key
GROUP BY c.customer_segment
ORDER BY total_sales DESC;

-- Q7
SELECT c.category_name,
       ROUND(SUM(f.sales),2) total_sales
FROM fact_order_item f
JOIN dim_category c ON f.category_key=c.category_key
GROUP BY c.category_name
ORDER BY total_sales DESC;

-- Q8
SELECT d.calendar_year,
       d.calendar_month,
       d.month_name,
       ROUND(SUM(f.sales),2) total_sales
FROM fact_order_item f
JOIN dim_date d ON f.order_date_key=d.date_key
GROUP BY d.calendar_year,d.calendar_month,d.month_name
ORDER BY d.calendar_year,d.calendar_month;

-- Q9
SELECT is_late_delivery,
       COUNT(*) total_rows,
       ROUND(AVG(shipping_delay_days),2) avg_delay_days
FROM fact_order_item
GROUP BY is_late_delivery;

-- Q10
SELECT sm.shipping_mode,
       COUNT(*) total_orders,
       ROUND(AVG(f.days_for_shipping_real),2) avg_shipping_days,
       ROUND(SUM(f.sales),2) total_sales
FROM fact_order_item f
JOIN dim_shipping_mode sm
ON f.shipping_mode_key=sm.shipping_mode_key
GROUP BY sm.shipping_mode
ORDER BY total_sales DESC;
