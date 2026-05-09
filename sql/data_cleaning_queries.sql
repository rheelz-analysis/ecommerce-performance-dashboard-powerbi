-- =====================================================
-- E-COMMERCE DATA CLEANING & PREPARATION
-- =====================================================

-- =====================================================
-- 1. INITIAL DATA VALIDATION
-- =====================================================

-- Orders table row count
SELECT COUNT(*) 
FROM orders;

-- Distinct orders check
SELECT COUNT(DISTINCT order_id) 
FROM orders;

-- Check order status distribution
SELECT order_status, COUNT(*) AS status_count
FROM orders
GROUP BY order_status;

-- Check missing delivery dates
SELECT 
    COUNT(*) AS total_rows,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_dates
FROM orders;

-- =====================================================
-- 2. ORDER ITEMS VALIDATION
-- =====================================================

-- Total order items
SELECT COUNT(*) 
FROM orderitems;

-- Check duplicate order-item combinations
SELECT COUNT(DISTINCT order_id, order_item_id) 
FROM orderitems;

-- Check missing values
SELECT 
    SUM(price IS NULL) AS null_price,
    SUM(freight_value IS NULL) AS null_freight
FROM orderitems;

-- Price and freight ranges
SELECT 
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight
FROM orderitems;

-- =====================================================
-- 3. CUSTOMER DATA VALIDATION
-- =====================================================

SELECT COUNT(*) 
FROM customers;

SELECT COUNT(DISTINCT customer_id) 
FROM customers;

SELECT COUNT(DISTINCT customer_unique_id) 
FROM customers;

-- Check missing customer locations
SELECT 
    SUM(customer_city IS NULL) AS null_city,
    SUM(customer_state IS NULL) AS null_state
FROM customers;

-- =====================================================
-- 4. PRODUCT DATA VALIDATION
-- =====================================================

SELECT COUNT(*) 
FROM products;

SELECT COUNT(DISTINCT product_id) 
FROM products;

-- Check missing categories
SELECT 
    SUM(product_category_name IS NULL) AS null_category
FROM products;

-- Product weight range
SELECT 
    MIN(product_weight_g) AS min_weight,
    MAX(product_weight_g) AS max_weight
FROM products;

-- =====================================================
-- 5. FIXING COLUMN HEADER ISSUE
-- =====================================================

ALTER TABLE productcategorynametranslation
CHANGE COLUMN `ï»¿product_category_name`
product_category_name TEXT;

-- =====================================================
-- 6. DATE CONVERSION
-- =====================================================

ALTER TABLE orders
ADD COLUMN order_purchase_dt DATETIME,
ADD COLUMN order_approved_dt DATETIME,
ADD COLUMN order_delivered_carrier_dt DATETIME,
ADD COLUMN order_delivered_customer_dt DATETIME,
ADD COLUMN order_estimated_delivery_dt DATETIME;

UPDATE orders
SET
    order_purchase_dt =
        STR_TO_DATE(NULLIF(order_purchase_timestamp, ''), '%d/%m/%Y %H:%i'),

    order_approved_dt =
        STR_TO_DATE(NULLIF(order_approved_at, ''), '%d/%m/%Y %H:%i'),

    order_delivered_carrier_dt =
        STR_TO_DATE(NULLIF(order_delivered_carrier_date, ''), '%d/%m/%Y %H:%i'),

    order_delivered_customer_dt =
        STR_TO_DATE(NULLIF(order_delivered_customer_date, ''), '%d/%m/%Y %H:%i'),

    order_estimated_delivery_dt =
        STR_TO_DATE(NULLIF(order_estimated_delivery_date, ''), '%d/%m/%Y %H:%i');

-- Validate converted dates
SELECT
    MIN(order_purchase_dt),
    MAX(order_purchase_dt)
FROM orders;

-- Check invalid delivery dates
SELECT COUNT(*) 
FROM orders
WHERE order_delivered_customer_dt < order_purchase_dt;

-- =====================================================
-- 7. REVENUE PREPARATION
-- =====================================================

ALTER TABLE orderitems
ADD COLUMN item_revenue DECIMAL(10,2);

UPDATE orderitems
SET item_revenue = price;

-- Revenue validation
SELECT
    ROUND(SUM(price),2) AS total_price,
    ROUND(SUM(item_revenue),2) AS total_revenue
FROM orderitems;

-- =====================================================
-- 8. PRODUCT QUALITY CHECKS
-- =====================================================

-- Check zero dimensions and weights
SELECT
    SUM(product_weight_g = 0) AS zero_weight,
    SUM(product_length_cm = 0) AS zero_length,
    SUM(product_height_cm = 0) AS zero_height,
    SUM(product_width_cm = 0) AS zero_width
FROM products;

-- Flag missing weights
ALTER TABLE products
ADD COLUMN weight_missing_flag TINYINT;

UPDATE products
SET weight_missing_flag =
CASE
    WHEN product_weight_g = 0 THEN 1
    ELSE 0
END;

-- =====================================================
-- 9. ANALYTICAL EXPLORATION
-- =====================================================

-- Orders where freight exceeds item price
SELECT COUNT(*)
FROM orderitems
WHERE freight_value > price;

-- Revenue by category
SELECT
    product_category_name_english,
    ROUND(SUM(item_revenue), 2) AS revenue
FROM vw_order_items_clean
GROUP BY product_category_name_english
ORDER BY revenue DESC
LIMIT 10;

-- =====================================================
-- 10. FINAL ANALYTICS VIEW
-- =====================================================

CREATE OR REPLACE VIEW vw_order_items_clean AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,

    -- Revenue
    oi.price AS item_revenue,
    oi.freight_value,

    -- Order Information
    o.order_purchase_dt,
    o.order_status,

    -- Product Information
    p.product_category_name,
    pct.product_category_name_english,
    p.weight_missing_flag,

    -- Customer Information
    c.customer_unique_id,
    c.customer_city,
    c.customer_state

FROM orderitems oi

JOIN orders o
    ON oi.order_id = o.order_id

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN productcategorynametranslation pct
    ON p.product_category_name = pct.product_category_name

JOIN customers c
    ON o.customer_id = c.customer_id;

-- =====================================================
-- 11. FINAL VALIDATION
-- =====================================================

SELECT COUNT(*) 
FROM vw_order_items_clean;

SELECT
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    ROUND(SUM(item_revenue), 2) AS total_revenue
FROM vw_order_items_clean;

-- =====================================================
-- END OF PROJECT
-- =====================================================
