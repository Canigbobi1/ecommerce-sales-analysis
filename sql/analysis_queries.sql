-- ============================================================
-- E-Commerce Sales Analysis — SQL Queries
-- Analyst: Churchill Anigbobi
-- Database: ecommerce.db (SQLite)
-- Tables: orders, customers, logistics
-- ============================================================


-- ── 1. Star Schema Consolidation Query ───────────────────────────────────────
-- Merges 3 source systems into a single analysis-ready fact table
CREATE VIEW IF NOT EXISTS vw_fact_sales AS
SELECT
    o.order_id,
    o.order_date,
    o.category,
    o.quantity,
    o.unit_price_ngn,
    o.discount_pct,
    o.gmv_ngn,
    o.order_status,
    c.customer_id,
    c.region,
    c.channel,
    c.customer_segment,
    l.delivery_days,
    l.shipping_cost_ngn,
    l.warehouse_region,
    CASE
        WHEN o.order_status = 'Completed' THEN o.gmv_ngn
        ELSE 0
    END AS net_revenue_ngn
FROM orders o
JOIN customers c ON o.order_id = c.order_id
JOIN logistics l ON o.order_id = l.order_id;


-- ── 2. Monthly GMV Trend ──────────────────────────────────────────────────────
SELECT
    strftime('%Y-%m', order_date)  AS month,
    COUNT(order_id)                AS total_orders,
    ROUND(SUM(gmv_ngn) / 1e6, 2)  AS gmv_millions,
    ROUND(SUM(CASE WHEN order_status = 'Completed'
                   THEN gmv_ngn ELSE 0 END) / 1e6, 2) AS completed_gmv_millions
FROM orders
GROUP BY 1
ORDER BY 1;


-- ── 3. Revenue by Category ────────────────────────────────────────────────────
SELECT
    o.category,
    COUNT(o.order_id)                           AS orders,
    ROUND(SUM(o.gmv_ngn) / 1e6, 2)             AS total_gmv_m,
    ROUND(AVG(o.unit_price_ngn), 0)             AS avg_unit_price,
    ROUND(100.0 * SUM(o.gmv_ngn) /
          SUM(SUM(o.gmv_ngn)) OVER (), 1)       AS gmv_share_pct
FROM orders o
WHERE o.order_status = 'Completed'
GROUP BY 1
ORDER BY 3 DESC;


-- ── 4. Regional Performance ───────────────────────────────────────────────────
SELECT
    c.region,
    COUNT(o.order_id)                  AS orders,
    ROUND(SUM(o.gmv_ngn) / 1e6, 2)    AS gmv_m,
    ROUND(AVG(l.delivery_days), 1)     AS avg_delivery_days,
    ROUND(AVG(o.discount_pct), 1)      AS avg_discount_pct
FROM orders o
JOIN customers c ON o.order_id = c.order_id
JOIN logistics l ON o.order_id = l.order_id
WHERE o.order_status = 'Completed'
GROUP BY 1
ORDER BY 3 DESC;


-- ── 5. Revenue Leakage — Returned & Uncategorised Orders ─────────────────────
SELECT
    order_status,
    COUNT(order_id)                     AS order_count,
    ROUND(SUM(gmv_ngn) / 1e6, 2)       AS gmv_lost_millions,
    ROUND(AVG(gmv_ngn), 0)             AS avg_order_value
FROM orders
WHERE order_status IN ('Returned', 'Cancelled')
GROUP BY 1
ORDER BY 3 DESC;


-- ── 6. Return Rate by Category (Leakage Breakdown) ───────────────────────────
SELECT
    category,
    COUNT(order_id)                              AS total_orders,
    SUM(CASE WHEN order_status = 'Returned'
             THEN 1 ELSE 0 END)                  AS returns,
    ROUND(100.0 * SUM(CASE WHEN order_status = 'Returned'
                           THEN 1 ELSE 0 END) /
          COUNT(order_id), 1)                    AS return_rate_pct,
    ROUND(SUM(CASE WHEN order_status = 'Returned'
                   THEN gmv_ngn ELSE 0 END) / 1e6, 2) AS gmv_lost_m
FROM orders
GROUP BY 1
ORDER BY 5 DESC;


-- ── 7. Channel Performance ────────────────────────────────────────────────────
SELECT
    c.channel,
    COUNT(o.order_id)                          AS orders,
    ROUND(SUM(o.gmv_ngn) / 1e6, 2)            AS gmv_m,
    ROUND(AVG(o.gmv_ngn), 0)                  AS avg_order_value,
    ROUND(AVG(l.delivery_days), 1)             AS avg_delivery_days
FROM orders o
JOIN customers c ON o.order_id = c.order_id
JOIN logistics l ON o.order_id = l.order_id
WHERE o.order_status = 'Completed'
GROUP BY 1
ORDER BY 3 DESC;


-- ── 8. VIP Customer Segment Analysis ─────────────────────────────────────────
SELECT
    c.customer_segment,
    COUNT(o.order_id)                  AS orders,
    ROUND(SUM(o.gmv_ngn) / 1e6, 2)    AS gmv_m,
    ROUND(AVG(o.gmv_ngn), 0)          AS avg_order_value,
    ROUND(AVG(o.discount_pct), 1)     AS avg_discount_pct
FROM orders o
JOIN customers c ON o.order_id = c.order_id
WHERE o.order_status = 'Completed'
GROUP BY 1
ORDER BY 3 DESC;
