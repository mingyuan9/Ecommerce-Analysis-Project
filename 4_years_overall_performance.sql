/* Final Course Project
THE SITUATION: The manager is close to securing Maven Fuzzy Factory's next round of funding, and she needs help to tell a compelling story to investors.

QUESTION 1: First, I'd like to show our volume growth. I'll pull overall session and order volume,
trended by quarter for the life of the business.*/


SELECT YEAR(ws.created_at) as yr,
	   QUARTER(ws.created_at) as qr,
       COUNT(DISTINCT ws.website_session_id) as sessions,
       COUNT(DISTINCT o.order_id) as orders
FROM website_sessions ws
LEFT JOIN orders o
USING (website_session_id)
GROUP BY 1,2

/* 2. Next, let's showcase all of our efficiency improvements. I would love to show quarterly figures since we launched,
for session-to-order conversion rate, revenue per order, and revenue per session */

SELECT YEAR(ws.created_at) as yr,
	   QUARTER(ws.created_at) as qr,
       -- COUNT(DISTINCT ws.website_session_id) as sessions,
       COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id) as order_to_session,
       SUM(price_usd)/COUNT(DISTINCT o.order_id) as revenue_per_order,
       SUM(price_usd)/COUNT(DISTINCT ws.website_session_id) as revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o
USING (website_session_id)
GROUP BY 1,2

/* 3. I'd like to show how we've grown specific channels. Could you pull a quarterly view of orders from
gsearch nonbrand, bsearch nonbrand, brand search overall, organic search , and direct type-in? */

SELECT YEAR(ws.created_at) as yr,
	   QUARTER(ws.created_at) as qr,
       COUNT(CASE WHEN utm_source = 'gsearch' and utm_campaign = 'nonbrand' THEN o.order_id END) AS gsearch_nonbrand_orders,
       COUNT(CASE WHEN utm_source = 'bsearch' and utm_campaign = 'nonbrand' THEN o.order_id END) AS bsearch_nonbrand_orders,
       COUNT(CASE WHEN utm_campaign = 'brand' THEN o.order_id END) AS overall_nonbrand_orders,
       COUNT(CASE WHEN utm_source is null and http_referer is not null THEN o.order_id END) AS organic_search_orders,
       COUNT(CASE WHEN utm_source is null and http_referer is null THEN o.order_id END) AS direct_type_in_orders
FROM website_sessions ws
LEFT JOIN orders o
USING (website_session_id)
GROUP BY 1,2

-- finding: gsearch nonbrand produces more orders than other channels

/* Next, let's show the overall session-to-order conversion rate trends for those same channels, by quarter. 
Please also make a note of any periods where we made major improvements or optimizations.*/

SELECT YEAR(ws.created_at) as yr,
	   QUARTER(ws.created_at) as qr,
       COUNT(CASE WHEN utm_source = 'gsearch' and utm_campaign = 'nonbrand' THEN o.order_id END)/
             COUNT(CASE WHEN utm_source = 'gsearch' and utm_campaign = 'nonbrand' THEN ws.website_session_id END) AS gsearch_nonbrand_session_to_order,
             
       COUNT(CASE WHEN utm_source = 'bsearch' and utm_campaign = 'nonbrand' THEN o.order_id END)/
             COUNT(CASE WHEN utm_source = 'bsearch' and utm_campaign = 'nonbrand' THEN ws.website_session_id END) AS bsearch_nonbrand_session_to_order,
             
       COUNT(CASE WHEN utm_campaign = 'brand' THEN o.order_id END)/
            COUNT(CASE WHEN utm_campaign = 'brand' THEN ws.website_session_id END) AS nonbrand_session_to_order,
            
       COUNT(CASE WHEN utm_source is null and http_referer is not null THEN o.order_id END)/
            COUNT(CASE WHEN utm_source is null and http_referer is not null THEN ws.website_session_id END) AS organic_search_session_to_order,
            
       COUNT(CASE WHEN utm_source is null and http_referer is null THEN o.order_id END)/
			COUNT(CASE WHEN utm_source is null and http_referer is null THEN ws.website_session_id END) AS direct_type_in_session_to_order
FROM website_sessions ws
LEFT JOIN orders o
USING (website_session_id)
GROUP BY 1,2

-- 2013 1st quarter, for gsearch nonbrand channel, session to order rate improved from 0.0436 to 0.0612, bsearch nonbrand increased from 0.0497 to 0.0693, 
-- nonbrand increased from 0.0531 to 0.0703, organic search increased from 0.0539 to 0.0753, this is a big improvement. 

/* 5. We've come a long way since the days of selling a single product. Let's pull monthly trending for revenue and margin by product, 
along with total sales and revenue. Note anything you notice about seasonality.*/

SELECT YEAR(o.created_at) as year,
	   MONTH(o.created_at) as month,
       -- COUNT(DISTINCT CASE WHEN oi.product_id = 1 THEN oi.order_id ELSE 0 END) as product_1_orders,
       SUM(CASE WHEN oi.product_id = 1 THEN oi.price_usd END) as product_1_revenue,
	   SUM(CASE WHEN oi.product_id = 1 THEN oi.price_usd-oi.cogs_usd END) as product_1_margin,
       -- COUNT(DISTINCT CASE WHEN oi.product_id = 2 THEN oi.order_id ELSE 0 END) as product_2_orders,
       SUM(CASE WHEN oi.product_id = 2 THEN oi.price_usd END) as product_2_revenue,
	   SUM(CASE WHEN oi.product_id = 2 THEN oi.price_usd-oi.cogs_usd END) as product_2_margin,
       -- COUNT(DISTINCT CASE WHEN oi.product_id = 3 THEN oi.order_id ELSE 0 END) as product_3_orders,
       SUM(CASE WHEN oi.product_id = 3 THEN oi.price_usd END) as product_3_revenue,  
	   SUM(CASE WHEN oi.product_id = 3 THEN oi.price_usd-oi.cogs_usd END) as product_3_margin,
       -- COUNT(DISTINCT CASE WHEN oi.product_id = 4 THEN oi.order_id ELSE 0 END) as product_4_orders,
       SUM(CASE WHEN oi.product_id = 4 THEN oi.price_usd END) as product_4_revenue,
	   SUM(CASE WHEN oi.product_id = 4 THEN oi.price_usd-oi.cogs_usd END) as product_4_margin,
       SUM(oi.price_usd) as total_revenue,
       SUM(oi.price_usd-oi.cogs_usd) as total_margin
FROM orders o
JOIN order_items oi
USING (order_id)
GROUP BY 1,2

-- finding: 11,12 holiday season
-- product 2, love bear, spikes in Feb, valentine's 

/* 6. Let's dive deeper into the impact of introducing new products. Please pull monthly sessions to the /product
page, and show how the % of those sessions clicking through another page has changed over time, along with a view 
of how conversion from /products to placing an order has improved.*/

-- first, identifying all the views of the /products page
CREATE TEMPORARY TABLE product_page_pageviews
SELECT website_session_id,
	   website_pageview_id,
       created_at as saw_product_page_at
FROM website_pageviews
WHERE pageview_url = '/products'

SELECT 
     YEAR(saw_product_page_at) as yr,
     MONTH(saw_product_page_at) AS mo,
     COUNT(DISTINCT ppp.website_session_id) AS sessions_to_product_page,
     COUNT(DISTINCT wp.website_session_id) as clicked_to_next_page,
     COUNT(DISTINCT wp.website_session_id)/COUNT(DISTINCT ppp.website_session_id) AS ctr,
     COUNT(DISTINCT o.order_id) AS orders,
     COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ppp.website_session_id) AS products_to_orders_rt
FROM product_page_pageviews ppp
LEFT JOIN website_pageviews wp
     ON ppp.website_session_id = wp.website_session_id -- same session
     AND wp.website_pageview_id > ppp.website_pageview_id -- they had another page AFTER
LEFT JOIN orders o 
     ON o.website_session_id = ppp.website_session_id
GROUP BY 1,2

/*7. We made our 4th product available on Dec 05,2014.(it was previously only a cross-sell item).
Could you please pull sales data since then, and show how well each product cross-sells from one another?*/
-- STEP 1:
CREATE TEMPORARY TABLE primary_products
SELECT order_id,
       primary_product_id,
       created_at AS ordered_at
FROM orders
WHERE created_at >= '2014-12-05' -- when the 4th product was added

-- STEP 2: create a subquery that bringing in cross-sells
-- STEP 3: find out well each product cross-sells from one another
SELECT 
      primary_product_id,
      COUNT(DISTINCT order_id) as total_orders,
      COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS _xsold_p1,
	  COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS _xsold_p2,
      COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS _xsold_p3,
      COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS _xsold_p4,
	  COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) as p1_xsell_rt,
	  COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) as p2_xsell_rt,
	  COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) as p3_xsell_rt,
	  COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) as p4_xsell_rt
FROM
(
	SELECT primary_products.*,
		   order_items.product_id as cross_sell_product_id
	FROM primary_products
	LEFT JOIN order_items -- not all primary products have cross-selling products
		ON primary_products.order_id = order_items.order_id
		AND order_items.is_primary_item = 0 -- only bringing in cross-sells
	) as primary_w_cross_sell
GROUP BY 1

-- finding: product 1 has the most cross sales,, and product 1 is likely to cross sell with product 4.
-- product 2 is the second product with most cross selling orders, and product 2 is likely to cross sell with product 3.

/* 8.In addition to telling investors about what we've already achieved, let's show them that we still have plenty
of gas in the tank. Based on all the analysis you've done, could you share some recommendations and opportunities 
for us going forward? No right or wrong answer here - I'd just like to hear your perspective.
*/

-- since gsearch nonbrand has the most traffic, I recomment the marketing could continue to bid up this channel.
-- also, we could release more products to increase cross selling opportunities

