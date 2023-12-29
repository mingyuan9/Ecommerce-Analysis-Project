/*
1. With gsearch doing well and the site performing better, the company decided to launch 
a second paid search channel, bsearch, around August 22.
I'm going to pull weekly trended session volume since then and compare to gsearch nonbrand.
*/

SELECT 
	   MIN(DATE(created_at)) as week_start_date,
       -- COUNT(DISTINCT website_session_id) as total_sessions,
       COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS gsearch_sessions,
       COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bsearch_sessions
FROM website_sessions ws
WHERE created_at > '2012-08-22' 
	AND created_at < '2012-11-29'
	AND utm_campaign = 'nonbrand'
GROUP BY YEARWEEK(created_at)

/* 
2. Next, I'd like to learn more about the bsearch nonbrand campaign,
I'm going to pull the percentage of traffic coming on Mobile, and compare that to gsearch.
*/

SELECT utm_source,
       COUNT(website_session_id) as sessions,
       COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END) as mobile_sessions,
       COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END)/COUNT(website_session_id) AS pct_mobile
FROM website_sessions
WHERE utm_campaign = 'nonbrand'
	  AND created_at > '2012-08-22'
      AND created_at < '2012-11-30'      
GROUP BY utm_source

-- gsearch is 24.5% mobile users, while bsearch is 8.6% mobile users

/* 
3. Now, we're wondering if bsearch nonbrand should have the same bids as gsearch.
I'm going to pull nonbrand conversion rates from session to order for gsearch and bsearch, 
and slice the data by device type.
*/

SELECT device_type,
       utm_source,
       COUNT(DISTINCT ws.website_session_id) as sessions,
       COUNT(DISTINCT order_id) as orders,
       COUNT(DISTINCT order_id)/COUNT(DISTINCT ws.website_session_id) as conv_rate
       -- COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END) as mobile_sessions,
FROM website_sessions ws
LEFT JOIN orders o 
ON ws.website_session_id = o.website_session_id
WHERE utm_campaign = 'nonbrand'
	  AND ws.created_at >= '2012-08-22'
      AND ws.created_at <= '2012-09-18'      
GROUP BY 1,2
ORDER BY 1

-- Within  desktop traffic, gsearch got 4.56% cr
-- within both desktop and mobile, gsearch outperform than bsearch
-- action: bid down bsearch nonbrand on both desktop and mobile channels 

/* 
4. We bid down bsearch nonbrand on Dec 2nd. 
I'm going to pull weekly session volume for gsearch and bsearch nonbrand by device since Nov 4th.
Also, to include a comparison metric to show bsearch as a percent of gsearch for each device.
*/

SELECT MIN(DATE(ws.created_at)) as week_start_date,
       COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'desktop' THEN website_session_id ELSE NULL END) AS g_dtop_sessions,
	   COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'desktop' THEN website_session_id ELSE NULL END) AS b_dtop_sessions,
COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'desktop' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'desktop' THEN website_session_id ELSE NULL END) 
AS b_pct_of_g_dtop,
	   COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'mobile' THEN website_session_id ELSE NULL END) AS g_mob_sessions,
	   COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'mobile' THEN website_session_id ELSE NULL END) AS b_mob_sessions,
	COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND device_type = 'mobile' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND device_type = 'mobile' THEN website_session_id ELSE NULL END)
    AS b_pct_of_g_mob
FROM website_sessions ws
WHERE utm_campaign = 'nonbrand'
AND ws.created_at > '2012-11-04'
AND ws.created_at < '2012-12-22'
GROUP BY YEARWEEK(ws.created_at)

-- Looks like bsearch traffic dropped off a bit after the bid down.
-- gsearch was down too after black friday and cyber monday, but bsearched dropped even more. 

/* 
5. CEO asked me if we'll need to keep relying on paid traffic.
I'm going to pull organic search,  direct type in, and paid brand search sessions by months, 
and show these sessions as a % of paid search nonbrand.
*/

SELECT 
     YEAR(created_at) as year,
     MONTH(created_at) as month,
	COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_session_id ELSE NULL END) AS nonbrand,
	COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_session_id ELSE NULL END) AS brand,  
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_session_id ELSE NULL END) AS brand_pct_of_nonbrand,
    COUNT(DISTINCT CASE WHEN utm_campaign IS NULL AND http_referer IS NULL THEN website_session_id END) as direct,
	COUNT(DISTINCT CASE WHEN utm_campaign IS NULL AND http_referer IS NULL THEN website_session_id END)/COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_session_id ELSE NULL END) AS direct_pct_of_nonbrand,
    COUNT(DISTINCT CASE WHEN utm_campaign IS NULL AND http_referer IS NOT NULL THEN website_session_id END) as organic,
    COUNT(DISTINCT CASE WHEN utm_campaign IS NULL AND http_referer IS NOT NULL THEN website_session_id END)/COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_session_id ELSE NULL END) AS organic_pct_of_nonbrand
FROM website_sessions ws
WHERE created_at < '2012-12-23'
GROUP BY 1,2
	
-- brand, direct, and organic volums are growing as a percentage of our paid traffic volume.
 