/*
1. Firstly, I'm going to pull monthly trends to date for number of sales, 
total revenue and total margin generated for the business.
*/

SELECT 
	YEAR(created_at) as yr,
	MONTH(created_at) as mon,
	COUNT(DISTINCT order_id) as num_of_sales,
	SUM(price_usd) as total_revenue,
	SUM(price_usd - cogs_usd) as total_margin
FROM orders 
WHERE created_at < '2013-01-04'
GROUP BY YEAR(created_at),
         MONTH(created_at)
         
/* 
2. On Jan.06, the company launched a new product.
I'll pull the monthly order volume, overall conversion rates, revenue per session, 
and a breakdown of sales by product since April 1, 2012
*/
SELECT YEAR(ws.created_at) yr,
       MONTH(ws.created_at) mon,
	   COUNT(DISTINCT ws.website_session_id) as monthly_sessions,
       COUNT(DISTINCT o.order_id) as num_orders,
       -- SUM(price_usd) as monthly_revenue,
       COUNT(DISTINCT o.order_id)/COUNT(ws.website_session_id) AS conv_rate,
       ROUND(SUM(price_usd)/COUNT(ws.website_session_id),2) as revenue_per_session,
       COUNT(CASE WHEN primary_product_id = 1 THEN order_id ELSE NULL END) AS product_one_orders,      
       COUNT(CASE WHEN primary_product_id = 2 THEN order_id ELSE NULL END) AS product_two_orders
FROM website_sessions ws
LEFT JOIN orders o USING(website_session_id)
WHERE ws.created_at > '2012-04-01'
      AND ws.created_at < '2013-04-05' 
GROUP BY YEAR(ws.created_at), 
         MONTH(ws.created_at) 
         
-- conversion rate and revenue per session are increasing over time
-- a new quesiont rises: if the growth is due to our new product release or just a continuation of overall business improvements?

/*
3. Now, the website manager wants to look at sessions which hit the /products page and see where they went next.
I'm going to pull clickthrough rate from /products since the new product launch on Jan 6th 2013, by product,
and also compare the 3 months leading up to launch a baseline
*/

/* 
STEP 1: find the relevant/products pageviews with website_session_id
STEP 2: find the next pageview id that occurs AFTER the product pageview
STEP 3: find the pageview_url associated with any applicable next pageview id
STEP 4: summarize the data and analyze the pre vs post periods
*/

-- 1. finding the /products pageviews we care about
CREATE TEMPORARY TABLE products_pageviews
SELECT wp.website_session_id,
       wp.website_pageview_id,
       wp.created_at,
       CASE WHEN wp.created_at BETWEEN date_sub('2013-01-06', INTERVAL 3 MONTH) AND '2013-01-06' THEN 'A.Pre_Product_2'
            WHEN wp.created_at BETWEEN '2013-01-06' AND date_add('2013-01-06', INTERVAL 3 MONTH) THEN 'B.Post_Product_2'
            END AS time_period
FROM website_pageviews wp
WHERE wp.created_at > date_sub('2013-01-06', INTERVAL 3 MONTH) AND
      wp.created_at < date_add('2013-01-06', INTERVAL 3 MONTH) AND
      wp.pageview_url IN ('/products')

-- 2. find the next pageview id that occurs AFTER the product pageview
-- using the website session id looking for other pageviews in pageviews that have the same website session(same person)
CREATE TEMPORARY TABLE  sessions_w_next_pageview_id
SELECT pp.time_period,
       pp.website_session_id,
       pp.website_pageview_id, 
       MIN(wp.website_pageview_id) AS min_next_pageview_id
FROM products_pageviews pp
LEFT JOIN website_pageviews wp
	ON pp.website_session_id = wp.website_session_id
	AND wp.website_pageview_id > pp.website_pageview_id
GROUP BY 1,2

-- 3.find the pageview_url associated with any applicable next pageview id
CREATE TEMPORARY TABLE sessions_w_next_pageview_url
SELECT sp.time_period,
       sp.website_session_id,
       wp.pageview_url as next_pageview_url
FROM sessions_w_next_pageview_id sp 
LEFT JOIN website_pageviews wp
ON wp.website_pageview_id = sp.min_next_pageview_id

-- 4.summarize the data and analyze the pre vs post periods
SELECT time_period,
		COUNT(DISTINCT website_session_id) AS sessions,
        COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id END) AS w_next_pg,
        COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id END)/COUNT(DISTINCT website_session_id) AS pct_next_pg,
		COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id END) AS to_mr_fuzzy,
        COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id END)/COUNT(DISTINCT website_session_id) AS pct_to_mrfuzzy,
		COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id END) AS to_lovebear,
        COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id END)/COUNT(DISTINCT website_session_id) AS pct_to_lovebear
FROM sessions_w_next_pageview_url
GROUP BY 1

-- It looks like the percent of /products pageviews that clicked to mr.fuzzy has gone down
-- since the release of new product(love bear), but the overall ctr has gone up.

/*
4. Product Conversion Funnels
We need to analyze the conversion funnels from each product page to conversion
Product a comparison between the two conversion funnels, for all website traffic
*/

-- step 1:  find the paveview_id related to each product 
CREATE TEMPORARY TABLE session_id_seen_product
SELECT website_pageview_id,
	   created_at,
       website_session_id,
       CASE WHEN pageview_url = '/the-forever-love-bear' THEN 'lovebear'
            WHEN pageview_url = '/the-original-mr-fuzzy' THEN 'mrfuzzy' 
		    END AS product_seen
FROM website_pageviews wp
WHERE wp.created_at BETWEEN  '2013-01-06' AND '2013-04-10'
      AND pageview_url IN ('/the-forever-love-bear', '/the-original-mr-fuzzy') 

-- STEP 2: in subquery, figure out which pageview urls to look for
-- STEP 3: aggregate the data to assess funnel performance
SELECT product_seen,
       COUNT(DISTINCT website_session_id) as session,
       COUNT(to_cart) as to_cart,
       COUNT(to_shipping) as to_shipping,
       COUNT(to_billing) as to_billing,
       COUNT(to_thankyou) as to_thankyou
FROM
  (SELECT DISTINCT sp.website_session_id,
		  product_seen,
          CASE WHEN pageview_url = '/cart' THEN 1 ELSE NULL END AS to_cart,
	      CASE WHEN pageview_url = '/shipping' THEN 1 ELSE NULL END AS to_shipping,
	      CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE NULL END AS to_billing, -- billing page changed
	      CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE NULL END AS to_thankyou     
    FROM website_pageviews wp
    JOIN session_id_seen_product sp USING (website_session_id)
   ) AS product_funnel
GROUP BY 1

/* 5. CROSS SELLING ANALYSIS
On Sep 25th, the company gave the customers the option to add a 2nd product while
on the /cart page. 
Compare the month before vs the month after the change. Also, pull the crt from
the /cart page, avg products per order, AOV, and overall revenue per /cart page view
*/

-- step 1: find out session id that has seen /cart pageview
CREATE TEMPORARY TABLE sessions_seeing_cart
SELECT 
        CASE WHEN wp.created_at BETWEEN date_sub('2013-09-25', INTERVAL 1 MONTH) AND '2013-09-25' THEN 'Pre_Cross_Sell'
		WHEN wp.created_at BETWEEN '2013-09-25' AND date_add('2013-09-25', INTERVAL 1 MONTH) THEN 'Post_Cross_Sell'
		END AS time_period,
	    wp.website_session_id as cart_session_id,
        wp.website_pageview_id as cart_pageview_id
FROM website_pageviews  wp
WHERE wp.created_at between date_sub('2013-09-25', INTERVAL 1 MONTH)
      and date_add('2013-09-25', INTERVAL 1 MONTH) 
      and wp.pageview_url = '/cart'

-- step 2: next page analysis, find out session id who see the next page
CREATE TEMPORARY TABLE cart_sessions_seeing_thenext_page
SELECT 
      ss.time_period,
      ss.cart_session_id,
      MIN(wp.website_pageview_id) as pv_id_after_cart
FROM sessions_seeing_cart  ss
LEFT JOIN website_pageviews wp
		ON ss.cart_session_id = wp.website_session_id
        AND wp.website_pageview_id > ss.cart_pageview_id -- only grab pageview they have AFTER they see the cart page
GROUP BY 1,2
HAVING MIN(wp.website_pageview_id) IS NOT NULL -- exclude people who abondon the cart

-- step 3: find the orders associated with the /cart sessions.
CREATE TEMPORARY TABLE pre_post_sessions_orders
SELECT  time_period,
		cart_session_id,
        order_id,
        items_purchased,
        price_usd
FROM sessions_seeing_cart 
INNER JOIN orders 
ON sessions_seeing_cart.cart_session_id = orders.website_session_id

-- STEP 4
WITH CTE AS
(
SELECT ss.time_period,
       ss.cart_session_id,
       CASE WHEN sn.cart_session_id IS NULL THEN 0 ELSE 1 END AS clicked_to_another_page,
       CASE WHEN so.order_id IS NULL THEN 0 ELSE 1 END AS placed_order,
       so.items_purchased,
       so.price_usd
FROM sessions_seeing_cart ss 
LEFT JOIN cart_sessions_seeing_thenext_page sn 
		on ss.cart_session_id = sn.cart_session_id
LEFT JOIN pre_post_sessions_orders so 
		on ss.cart_session_id = so.cart_session_id
)

SELECT time_period,
       COUNT(DISTINCT cart_session_id) AS cart_sessions,
       SUM(clicked_to_another_page) as clickthroughs,
       SUM(clicked_to_another_page)/COUNT(DISTINCT cart_session_id) as cart_ctr,
       SUM(placed_order) as orders_placed,
       SUM(items_purchased) as products_purchased,
       SUM(items_purchased)/SUM(placed_order) as products_per_order,
       SUM(price_usd) as revenue,
       SUM(price_usd)/SUM(placed_order) as aov,
       SUM(price_usd)/COUNT(DISTINCT cart_session_id) as rev_per_cart_session
FROM CTE
GROUP BY 1

-- ctr from the /cart page didn't go down.
-- products per order, revenue, aov, revenue per /cart session went up since the cross-sell feature launched.

/* 
6. Portfolio expansion analysis:
On Dec.12th, the company launched a 3rd product(Birthday Bear)
Run a pre-post analysis comparing the month before vs. the month after
session-to-order conversion rate, AOV, products per order, revenue per ssession
*/

-- STEP 1: Find out the session id seeing birthday bear

SELECT CASE WHEN ws.created_at < '2013-12-12' THEN 'A.Pre_Birthday_Bear'
            WHEN ws.created_at >= '2013-12-12' THEN 'B.Post_Birthday_Bear'
	   END AS time_period,
	   -- COUNT(DISTINCT ws.website_session_id) as sessions,
       -- COUNT(DISTINCT o.order_id) as orders,
       COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id) as conv_rate,
		--    SUM(o.price_usd) as total_rev,
        -- SUM(o.items_purchased) as total_products_sold,
        SUM(o.price_usd)/COUNT(DISTINCT o.order_id) AS avg_order_value,
        SUM(o.items_purchased)/COUNT(DISTINCT o.order_id) as products_per_order,
        SUM(o.price_usd)/COUNT(DISTINCT ws.website_session_id) as revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o USING (website_session_id)
WHERE ws.created_at BETWEEN '2013-11-12' AND '2014-01-12'
GROUP BY 1

-- all the critical metrics improved since the 3rd product launched.

/*
7. Mr.fuzzy supplier had some quality issues regarding to the bear's arms were falling off around Aug/Sep 2014.
The company replaced the with a new supplier on Sep 14, 2014.
Pull monthly product refund rates, by product, to see how the qualify issues are now fixed yet.
*/

SELECT yr,
       mo,
       COUNT(CASE WHEN product_id = 1 THEN order_item_id END) as p1_orders,
       COUNT(CASE WHEN product_id = 1 THEN return_order_item_id END)/COUNT(CASE WHEN product_id = 1 THEN order_item_id END) as p1_refund_rt,
       COUNT(CASE WHEN product_id = 2 THEN order_item_id END) as p2_orders,
       COUNT(CASE WHEN product_id = 2 THEN return_order_item_id END)/COUNT(CASE WHEN product_id = 2 THEN order_item_id END) as p2_refund_rt,
       COUNT(CASE WHEN product_id = 3 THEN order_item_id END) as p3_orders,
       COUNT(CASE WHEN product_id = 3 THEN return_order_item_id END)/COUNT(CASE WHEN product_id = 3 THEN order_item_id END) as p3_refund_rt,
       COUNT(CASE WHEN product_id = 4 THEN order_item_id END) as p4_orders,
       COUNT(CASE WHEN product_id = 4 THEN return_order_item_id END)/COUNT(CASE WHEN product_id = 4 THEN order_item_id END) as p4_refund_rt
FROM
(SELECT YEAR(oi.created_at) as yr,
       MONTH(oi.created_at) as mo,
	   oi.order_id,
       oi.product_id,
       oi.order_item_id,
       oir.order_item_id as return_order_item_id
FROM order_items oi
LEFT JOIN order_item_refunds oir
USING (order_item_id)
WHERE oi.created_at < '2014-10-15') item_refund
GROUP BY 1,2

-- the refund rates were terrible in aug and sep in 2014 (13%-14%)
-- it looks like the new supplier is doing much better since the refund rate went down a lot in Oct.

