/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage: These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- Create Dimension: gold.dim_customers

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT 
ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
cu.cst_id as customer_id,
cu.cst_key as customer_number,
cu.cst_firstname as first_name,
cu.cst_lastname as last_name,
lo.cntry as country,
cs.bdate as birth_date,
cu.cst_marital_status as marital_status,
CASE
    WHEN cu.cst_gndr != 'n/a' THEN cu.cst_gndr -- CRM is the primary source for gender
    ELSE COALESCE(cs.gen, 'n/a')               -- Fallback to ERP data
END AS gender,
cu.cst_create_date as create_date

FROM silver.crm_cust_info cu
LEFT JOIN silver.erp_cust_az12 cs
	ON cu.cst_key = cs.cid
LEFT JOIN silver.erp_loc_a101 lo
	ON cu.cst_key = lo.cid;
GO

-- Create Dimension: gold.dim_products

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
ROW_NUMBER() OVER (ORDER BY pr.prd_start_dt, pr.prd_key) AS product_key,
pr.prd_id as product_id,
pr.cat_id as category_id,
pr.prd_key as product_number,
pr.prd_nm as product_name,
px.cat as product_category,
px.subcat as product_subcategory,
px.maintenance as maintenance,
pr.prd_cost as product_cost,
pr.prd_line as product_line,
pr.prd_start_dt as start_dt

FROM silver.crm_prd_info pr
LEFT JOIN silver.erp_px_cat_g1v2 px
    ON pr.cat_id = px.id
WHERE pr.prd_end_dt is NULL;
GO

-- Create Fact Table: gold.fact_sales

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
sd.sls_ord_num  AS order_number,
pr.product_key  AS product_key,
cu.customer_key AS customer_key,
sd.sls_order_dt AS order_date,
sd.sls_ship_dt  AS shipping_date,
sd.sls_due_dt   AS due_date,
sd.sls_sales    AS sales_amount,
sd.sls_quantity AS quantity,
sd.sls_price    AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
GO
