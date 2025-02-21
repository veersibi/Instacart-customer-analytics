-- First we start creating a union of order_products__prior and order_products__train into a simple order_products
select * from `df.order_products__prior`
union all
select * from `df.order_products__train`
as order_products;
-----------------------------------------------

--1. What are highest selling products? 
-- This is vital for the business to make sure these best sellers are always in stock 

SELECT p.product_name, count(op.product_id) as order_count
from df.order_products op
join df.products p on op.product_id=p.product_id
GROUP BY p.product_name
ORDER BY order_count DESC
LIMIT 10;

-- The top 10 most ordered items are from the same department - produce
--------------------------------------------

--2. Which are the most popular departments?

SELECT d.department, COUNT(op.product_id) AS product_count
FROM df.order_products AS op
JOIN df.products AS p
ON op.product_id = p.product_id
JOIN df.departments AS d
ON p.department_id= d.department_id
GROUP BY d.department
ORDER BY product_count DESC
LIMIT 10;

---------------------------------------------
--3. Highest reordered products
-- Products that have been reordered the most , this helps the business to identify if the product was a hit or miss among the customers 
 

SELECT p.product_name, SUM(op.reordered) / COUNT(op.product_id) AS reorder_rate
FROM df.order_products AS op
JOIN df.products AS p
ON op.product_id = p.product_id
GROUP BY p.product_name
HAVING COUNT(op.product_id) > 100 
ORDER BY reorder_rate DESC
LIMIT 10;

-----------------------------------------------
-- 4. Which product combinations were purchased the most?

WITH table1 AS (
    SELECT 
        d1.product_id AS prod_a, 
        d2.product_id AS prod_b, 
        COUNT(*) AS item_count
    FROM df.order_products d1
    JOIN df.order_products d2 ON d1.order_id = d2.order_id AND d1.product_id < d2.product_id
    GROUP BY d1.product_id, d2.product_id
    HAVING COUNT(*) > 50
)
SELECT 
    p1.product_name AS prod_a_name,  
    p2.product_name AS prod_b_name, 
    t.prod_a, 
    t.prod_b, 
    t.item_count
FROM table1 t
JOIN df.products p1 ON t.prod_a = p1.product_id
JOIN df.products p2 ON t.prod_b = p2.product_id
ORDER BY t.item_count DESC;

--5. which were the top products per department?

with table1 as (select p.product_name,count(op.order_id) as product_count,p.department_id,
row_number() over (PARTITION BY p.department_id order by count(op.order_id) DESC) as Rank
from df.order_products op
join df.products p on op.product_id=p.product_id
group by p.product_name,p.department_id)
SELECT d.department,product_name,product_count,RANK
from table1
join df.departments d on table1.department_id=d.department_id
where Rank<11
order by d.department_id;

-- 6. Is there a pattern in orders throughtout the week?
-- Which days are popular for orders? 

WITH order_counts AS (
    SELECT 
        orders.order_dow, 
        COUNT(order_products.product_id) AS total_items_ordered,
        COUNT(DISTINCT orders.order_id) AS total_orders
    FROM df.order_products
    JOIN df.orders ON order_products.order_id = orders.order_id
    GROUP BY orders.order_dow
)
SELECT 
    order_dow,
    total_items_ordered,
    total_orders,
    total_items_ordered * 1.0 / total_orders AS avg_items_per_order
FROM order_counts
ORDER BY order_dow;

-- 7. How many days do customers usually wait to reorder?

SELECT user_id, AVG(days_since_prior_order) AS avg_days_between_orders
FROM df.orders
WHERE days_since_prior_order IS NOT NULL
GROUP BY user_id
ORDER BY avg_days_between_orders DESC;

-- 8. Count of items per order
with table1 as (select count(op.product_id) as item_count,op.order_id
from df.order_products op 
group by op.order_id)
select item_count, count(order_id) as no_of_orders
from table1
group by item_count
order by item_count;

-- 9 Which items were added first to the cart? 
select p.product_name,count(op.product_id) as First_item_count
from df.order_products op
join df.products p on op.product_id=p.product_id
where op.add_to_cart_order =1
group by p.product_name
order by First_item_count DESC;

-----------------------------------

-- 10. Is there a real difference in sales of organic and inorganic products
with temp as (select products.product_id, products.product_name,departments.department, order_products.order_id,
(case when products.product_name like '%Organic%' then 'organic' else 'inorganic' end) as org_check
from df.products join df.departments on products.department_id=departments.department_id
join df.order_products on products.product_id = order_products.product_id
and departments.department = 'produce')
SELECT org_check, COUNT(*) AS count
FROM temp
GROUP BY org_check;

-- 11. Which chips are ordered the most?

select products.product_name,  count(order_products.order_id) as order_count
from df.products 
join df.departments on products.department_id = departments.department_id
join df.order_products on products.product_id = order_products.product_id
where departments.department = 'snacks'
and (
    products.product_name like "%Chips%" 
    or products.product_name like "%Crisps%"
)
and products.product_name not like "%Cookies%"
group by products.product_name
order by order_count desc;