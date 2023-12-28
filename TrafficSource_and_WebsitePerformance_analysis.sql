-- Analyzing Traffic Source & Website performance

-- 1.1 Finding Top traffic Souces
SELECT utm_source,
       utm_campaign,
       http_referer,
       COUNT(website_session_id) as sessions
FROM website_sessions
WHERE created_at < '2012-04-12'
GROUP BY 1,2,3
-- Finding: We found out gsearch nonbrand has the most sessions

-- 1.2 Gsearch nonband is our major traffic source, What's the traffic conversion rate from gsearch nonbrand?
-- We'll need a cvr of at least 4% to make the numbers work.

SELECT 
	COUNT(DISTINCT ws.website_session_id) as sessions,
	COUNT(DISTINCT o.order_id) as orders,
	COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id) as session_to_order_conv_rate
FROM website_sessions ws
LEFT JOIN orders o USING (website_session_id)
WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' AND ws.created_at < '2012-04-14'

-- session cvr is 2.88%, we're below 4% threshold. We'll need to dial down our search bids a bit.

-- 1.3 We bid down gsearch brand on 2012-04-15. Now we need to see if the bid changes haved caused volume to drop?
SELECT 
    YEAR(ws.created_at) as yr,
    WEEK(ws.created_at) as wk,
    MIN(DATE(ws.created_at)) as week_started_at,
	COUNT(DISTINCT ws.website_session_id) as sessions
FROM website_sessions ws
WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' AND ws.created_at < '2012-05-10'
GROUP BY YEAR(ws.created_at),
         WEEK(ws.created_at)

-- Finding: we do see gsearch nonbrand traffic dropped since the bid down.

-- 1.4 We wanna maximize session volume, but don't wanna spend too much money.
-- We'll analyze performance trending by device type in order to refine bidding strategy.
SELECT 
    device_type,
	COUNT(DISTINCT w.website_session_id) as sessions,
	COUNT(DISTINCT o.order_id) as orders,
	COUNT(DISTINCT o.order_id)/COUNT(DISTINCT w.website_session_id) as session_to_order_cr
FROM website_sessions w
LEFT JOIN orders o USING(website_session_id)
WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' AND w.created_at < '2012-05-11'
GROUP BY device_type

-- FINDING:  Desktop performance is better than mobile. We should bid more for desktop specific traffic.

/* 1.5 Since 2012-05-19, we bid our gsearch nonbrand desktop campaigns, now we need to pull weekly 
trends fro both desktop and mobile */

SELECT 
    -- YEAR(ws.created_at) as yr,
    -- WEEK(ws.created_at) as wk,
    MIN(DATE(ws.created_at)) as week_started_at,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN ws.website_session_id END) as dtop_sessions,
	COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN ws.website_session_id END) as mob_sessions
FROM website_sessions ws
WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' 
      AND ws.created_at BETWEEN '2012-04-15' AND '2012-06-19'
GROUP BY YEAR(ws.created_at),
         WEEK(ws.created_at)

-- Since 05/19, we bid up on desktop traffic, we did see a pop in desktop traffic.

/* 1.6 Next, we can deep dive into conversion rate from session to orders */
SELECT 
    -- YEAR(ws.created_at) as yr,
    -- WEEK(ws.created_at) as wk,
    MIN(DATE(ws.created_at)) as week_started_at,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN ws.website_session_id END) as dtop_sessions,
	COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN ws.website_session_id END) as mob_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN o.order_id END) AS dtop_orders,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN o.order_id END) AS mob_orders,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN o.order_id END)/COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN ws.website_session_id END) as dtop_cvr,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN o.order_id END)/COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN ws.website_session_id END) as mob_cvr
FROM website_sessions ws
LEFT JOIN orders o USING (website_session_id)
WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' 
      AND ws.created_at BETWEEN '2012-04-15' AND '2012-06-19'
GROUP BY YEAR(ws.created_at),
         WEEK(ws.created_at)

/* 2.1 - We wanna to know the most_viewed website pages */ 
SELECT DISTINCT pageview_url,
	   (DISTINCT website_pageview_id) as sessions
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY 1
ORDER BY 2 DESC

-- home page, product page, and mrfuzzy page are the top 3 most viewed pages.

/* 2.2 - We want to know where the customer firstly land on the website.(landing page/entry page) */

SELECT pageview_url as landing_page_url,
       COUNT(website_session_id) as sessions_hitting_page
FROM
(
SELECT DISTINCT(website_session_id), 
       MIN(website_pageview_id) as first_pageview_id,
       pageview_url
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY 1
	) first_pageview_w_session
GROUP BY 1

-- Finding: our traffic all comes in through the homepage right now.

/* 2.3 - Next, what's the bounce rate for traffic landing on the homepage? 
step 1: find the first website_pageview_id and pageview_url for relevant sessions */
CREATE TEMPORARY TABLE landing_page_w_pageviewid
SELECT wp.website_session_id,
       min(website_pageview_id) as min_pageview_id,
       pageview_url as landing_page
FROM website_pageviews wp
WHERE wp.created_at < '2012-06-14'
GROUP BY 1

-- step 2: find how many pageviews is for each website session id 
-- step 3: bring the result to find out bounced sessions and bounce rate
WITH session_id_w_pgviews AS
(
SELECT lp.website_session_id, 
	   lp.landing_page,
	   COUNT(wp.website_pageview_id) as num_pageviews
FROM website_pageviews wp
LEFT JOIN landing_page_w_pageviewid lp
ON wp.website_session_id = lp.website_session_id
GROUP BY 1
)

SELECT landing_page,
       COUNT(DISTINCT website_session_id) AS num_session_id,
       COUNT(CASE WHEN num_pageviews = 1 THEN 1 END) as bounced_sessions,
       COUNT(CASE WHEN num_pageviews = 1 THEN 1 END)/COUNT(DISTINCT website_session_id) as bounce_rt
FROM session_id_w_pgviews

-- Finding: we found out 59.18% of people left the website after seeing the landing page. 

/* 2.4 - we later on ran a new customer landing page (/lander-1) in a 50/50 test against the homepage (/home) 
for our gsearch nonbrand traffic. Now we need to pull the comparison between two landing pages. */

-- step 1: find out when does the /lander-1 first time get traffic?
SELECT pageview_url,
       min(website_pageview_id) as first_lander1_pageview,  -- there're many pageviews landed on /lander-1
	   min(created_at) as first_traffic
FROM website_pageviews
WHERE pageview_url = '/lander-1'
-- we found pageview_id = 23504 was the first time '/lander-1' got traffic through
-- step 2: Find out the first pageview id and landing page for each website session id
CREATE TEMPORARY TABLE landing_page_w_pageview_id
SELECT DISTINCT website_session_id,
       min(website_pageview_id) as min_pageview_id,
       pageview_url as landing_page
FROM website_pageviews
JOIN website_sessions USING (website_session_id)
WHERE website_pageview_id >= 23504
      AND pageview_url in ('/lander-1','/home')
	  AND utm_source = 'gsearch'
      AND utm_campaign = 'nonbrand'
      AND website_pageviews.created_at < '2012-07-28'
GROUP BY 1

-- step 3: JOIN website_pageviews table to find out for each pageview_id, how many pageviews they have?
WITH landing_page_w_pgviews AS
(
SELECT lpp.website_session_id,
       lpp.landing_page,
       COUNT(wp.website_pageview_id) as num_pageviews
FROM website_pageviews wp
JOIN landing_page_w_pageview_id lpp
USING (website_session_id)
GROUP BY 1
)
-- step 4: find bounce rate by landing page
SELECT landing_page,
	   COUNT(DISTINCT website_session_id) as num_session_id,
       COUNT(CASE WHEN num_pageviews = 1 THEN 1 END) as bounced_sessions,
       COUNT(CASE WHEN num_pageviews = 1 THEN 1 END)/COUNT(DISTINCT website_session_id) as bounce_rt
FROM landing_page_w_pgviews
GROUP BY 1

-- the new landing page '/lander-1' has a lower bounce rate, which is great!

/* 2.5 - We want to know the volume of paid search nonbrand traffic landing on '/home' and '/lander-1', 
trended weekly since June 1st, as well as bounce rate.*/

WITH CTE AS
(
SELECT ws.website_session_id,
       wp.created_at,
       wp.pageview_url as landing_page,
       MIN(wp.website_pageview_id) AS first_pageview_id,
	   COUNT(wp.website_pageview_id) AS count_pageviews
FROM website_sessions ws
LEFT JOIN website_pageviews wp
		ON ws.website_session_id = wp.website_session_id
WHERE ws.created_at BETWEEN '2012-06-01' AND '2012-08-31'
		AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY 1
ORDER BY 1
)

SELECT  MIN(DATE(created_at)) as week_started_at,
        -- COUNT(DISTINCT website_session_id) as total_sessions,
        -- COUNT(CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END) AS bounced_sessions,
        COUNT(CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) as bounced_rt,
        COUNT(CASE WHEN landing_page = '/home' THEN 1 END) AS home_sessions,
		COUNT(CASE WHEN landing_page = '/lander-1' THEN 1 END) AS lander_sessions
FROM CTE 
GROUP BY YEAR(created_at),
		 WEEK(created_at)
-- Finding: The bounce rate starting at 60%, and over time, traffic primarily going to '/lander-1', and we were seeing bounce rate closer to 50%

/* 2.6 - We want a more detailed analysis about full conversion funnel, analyzing how many customers make it to each step.
Starting with '/lander-1' and build the funnel all the way to thank_you page. Use data from August 05 - Sep 05 */

-- step 1&2: select all pageviews for relevant sessions

SELECT  ws.website_session_id,
        wp.pageview_url,
        CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS product_page,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
		CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
		CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
		CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_pageviews wp
LEFT JOIN website_sessions ws
		  ON wp.website_session_id = ws.website_session_id
WHERE ws.created_at > '2012-08-05' AND ws.created_at < '2012-09-05'
	  AND ws.utm_source = 'gsearch'
      AND ws.utm_campaign = 'nonbrand'
GROUP BY ws.website_session_id,
		 wp.created_at
         
-- step 3: create the session-level conversion funnel view (create a temporary table)

CREATE TEMPORARY TABLE session_level_made_it

SELECT  website_session_id,
		MAX(product_page) as product_made_it,
        MAX(mrfuzzy_page) as mrfuzzy_made_it,
        MAX(cart_page) as cart_made_it,
        MAX(billing_page) as billing_made_it,
        MAX(shipping_page) as shipping_made_it,
        MAX(thankyou_page) as thankyou_made_it
FROM
(SELECT ws.website_session_id,
        wp.pageview_url,
        CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS product_page,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
		CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
		CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
		CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_pageviews wp
LEFT JOIN website_sessions ws
		  ON wp.website_session_id = ws.website_session_id
WHERE ws.created_at > '2012-08-05' AND ws.created_at < '2012-09-05'
	  AND ws.utm_source = 'gsearch'
      AND ws.utm_campaign = 'nonbrand'
GROUP BY ws.website_session_id,
		 wp.created_at
         ) as pageview_level
GROUP BY 1

SELECT *
FROM session_level_made_it

-- step 4: summarize the result. How many people go the each page?
SELECT 
	COUNT(DISTINCT website_session_id) as sessions,
	COUNT(CASE WHEN product_made_it = 1 THEN product_made_it ELSE NULL END ) as product_clicks,
    COUNT(CASE WHEN mrfuzzy_made_it = 1 THEN mrfuzzy_made_it  ELSE NULL END ) as mrfuzzay_clicks,
    COUNT(CASE WHEN cart_made_it = 1 THEN cart_made_it ELSE NULL END ) as cart_clicks,
	COUNT(CASE WHEN shipping_made_it = 1 THEN shipping_made_it ELSE NULL END ) as shipping_clicks,
    COUNT(CASE WHEN billing_made_it = 1 THEN billing_made_it ELSE NULL END ) as billing_clicks,
    COUNT(CASE WHEN thankyou_made_it = 1 THEN thankyou_made_it ELSE NULL END ) as thankyou_clicks
FROM session_level_made_it

-- what's click through rate of each page?
SELECT 
	COUNT(CASE WHEN product_made_it = 1 THEN product_made_it ELSE NULL END )/COUNT(DISTINCT website_session_id) as lander_ctr,
    COUNT(CASE WHEN mrfuzzy_made_it = 1 THEN mrfuzzy_made_it  ELSE NULL END )/COUNT(CASE WHEN product_made_it = 1 THEN product_made_it ELSE NULL END ) as product_ctr,
    COUNT(CASE WHEN cart_made_it = 1 THEN cart_made_it ELSE NULL END )/COUNT(CASE WHEN mrfuzzy_made_it = 1 THEN mrfuzzy_made_it  ELSE NULL END ) as mrfuzzy_ctr,
    COUNT(CASE WHEN shipping_made_it = 1 THEN shipping_made_it ELSE NULL END )/COUNT(CASE WHEN cart_made_it = 1 THEN cart_made_it ELSE NULL END ) as cart_ctr,
    COUNT(CASE WHEN billing_made_it = 1 THEN billing_made_it ELSE NULL END )/COUNT(CASE WHEN shipping_made_it = 1 THEN shipping_made_it ELSE NULL END ) as shipping_ctr,
    COUNT(CASE WHEN thankyou_made_it = 1 THEN thankyou_made_it ELSE NULL END )/COUNT(CASE WHEN shipping_made_it = 1 THEN shipping_made_it ELSE NULL END ) as billing_ctr
FROM session_level_made_it

/* 2.6 - The website manager wants to test an updated billing page and want to know whether '/billing-2' is doing any better than '/billing' page?
what's the % of sessions ended up placing an order. */
-- step 1: what the first pageview_id when '/billing-2' started to have traffic
SELECT 
	   MIN(wp.website_pageview_id) as first_pv_id
       -- MIN(ws.created_at) as first_created_at
FROM website_pageviews wp
JOIN website_sessions ws
		  ON ws.website_session_id=wp.website_session_id
		  AND wp.pageview_url = '/billing-2'

-- first_pv_id = 53550

-- step 2: Create subquery table: figure out which billing page were seen.
-- step 3: which billing page convert more orders
SELECT 
     billing_version_seen,
     COUNT(DISTINCT website_session_id) as sessions,
     COUNT(DISTINCT order_id) as orders,
     COUNT(DISTINCT order_id)/COUNT(DISTINCT website_session_id) as billing_to_order_rt
FROM 
     (SELECT wp.website_session_id,
	         wp.pageview_url as billing_version_seen,
             o.order_id
	  FROM website_pageviews wp
		    LEFT JOIN orders o USING (website_session_id)  -- return all rows from wp, no matter they have order or not
	  WHERE wp.website_pageview_id >= 53550
			AND wp.created_at < '2012-11-10'
			AND wp.pageview_url IN ('/billing', '/billing-2')
	  ) AS billingpage_level_order
GROUP BY billing_version_seen
