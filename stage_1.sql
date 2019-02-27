/*
Check Safety
-------------
HEADER ? None
Unconstrained primary key ? True
Data type consistency ? Ignore
Numerical flow ? Ignore
Realistic value ? Ignore
Cross column consistency ? Ignore
 */

-- Primary key safety check
-- PK::customer_id::str

with counts as (SELECT customer_id, COUNT(customer_id) id_count
                FROM customers
                GROUP BY customer_id)
SELECT co.customer_id, id_count
FROM counts as co
WHERE id_count > 1;
-- Is this hash collision? Join with other attrs to find out.
with counts as (SELECT customer_id, COUNT(customer_id) id_count
                FROM customers
                GROUP BY customer_id)
SELECT co.customer_id, id_count, cu.*
FROM counts as co
       INNER JOIN customers cu on co.customer_id = cu.customer_id
WHERE id_count > 1;

-- Doesn't look like it, create a new table using CTAS.
CREATE TABLE c_distinct AS
  with dist_c as (
    select *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS row_n
    FROM customers
    )
    SELECT *
    FROM dist_c
    WHERE row_n = 1;


-- What was the total revenue to the nearest dollar for customers who have paid by credit card?
-- Assuming that this field is in dollars.
-- $50189329
SELECT cc_payments, round(sum(revenue))
FROM c_distinct
GROUP BY cc_payments;

-- What percentage of customers who have purchased female items have paid by credit card?
-- Could use some fancy pivot, but that's if time permits. Just add em up the console for now.
-- (22483/ (22483 + 11852)) * 100 = 65.4812873161497
with fem_buyers as (
  SELECT customer_id, cc_payments
  FROM c_distinct
  WHERE female_items > 0
)
SELECT cc_payments, count(customer_id)
FROM fem_buyers
GROUP BY cc_payments;

-- What was the average revenue for customers who used either iOS, Android or Desktop?
-- Assuming dollars
-- $1487.089894962388

with selected_customers as (
  SELECT customer_id, revenue
  FROM c_distinct
  WHERE ios_orders > 0
     OR android_orders > 0
     OR desktop_orders > 0
)
SELECT AVG(revenue)
FROM selected_customers;

-- We want to run an email campaign promoting a new mens luxury brand. Can you provide a list of customers we should -- send to?
-- Men's -> Prioritising customers who have higher purchases of men's items.
-- Luxury -> Prioritising customers who have higher revenues.

-- Could probably do this in like one query using some recursive CTEs, but haven't done those for a while and in the
-- interest of time, just compute the values and use them manually.

-- Men's items bucket statistics.
SELECT min(male_items)
     , avg(male_items)
     , max(male_items)
     , stdev(male_items)
FROM c_distinct;
-- Let's say anyone who is on the right side of the mean for now.

-- Let's assume luxury item's are likely to be bought by customers with high specific revenue.
-- That is, a lot of revenue, little amount of number of purchases.
with spec_rev_stats as (SELECT revenue / male_items as specific_revenue
                        FROM c_distinct
                        WHERE male_items > 0)
SELECT min(specific_revenue)
     , avg(specific_revenue)
     , max(specific_revenue)
     , stdev(specific_revenue)
FROM spec_rev_stats;

-- Select the customers
SELECT customer_id
FROM c_distinct
WHERE male_items > 2
AND revenue / male_items > 617;
