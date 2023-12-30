/* 
1.Identifying repeat visitors
How many of our website visitors come back for another session?
*/

-- STEP 1: Identify the relevant new sessions
-- STEP 2: use the user_id in step 1 to find any repeat sessions 
CREATE TEMPORARY TABLE sessions_w_repeats
SELECT  new_sessions.user_id,
        new_sessions.website_session_id as new_session_id,
        ws.website_session_id as repeat_session_id
FROM
(
    SELECT user_id,
           website_session_id
	FROM website_sessions
	WHERE created_at BETWEEN '2014-01-01' AND '2014-11-01'
	      AND is_repeat_session = 0 -- new sessions only
) new_sessions
LEFT JOIN website_sessions ws
	 ON ws.user_id = new_sessions.user_id
	 AND ws.is_repeat_session = 1 -- was a repeat session
	 AND ws.website_session_id > new_sessions.website_session_id -- session was later than new session
	 AND ws.created_at BETWEEN '2014-01-01' AND '2014-11-01'
    
    
-- STEP 3: aggregate data to find out how many people come back for another session? how many time they come back?
SELECT
      repeat_sessions,
	  COUNT(DISTINCT user_id) as users
FROM
(
	SELECT user_id,
		   COUNT(DISTINCT new_session_id) as new_sessions,
           COUNT(DISTINCT repeat_session_id) as repeat_sessions
	FROM sessions_w_repeats
	GROUP BY 1
	ORDER BY 3 
) user_level
GROUP BY 1

/*
2. We want to better understand the behavior of the repeat customers.
Now, I'm going to pull out the minimum, the maximum, and average time btw the first and second sessions.
*/

-- 1. identify the relevant new sessions
-- 2. use the user_id values from step 1 to find any repeat sessions those users had
-- 3. find the created_at times for first and second sessions
-- 4. find the differences btw fst and snd sessions at a user level
-- 5. aggregate the user level data to find the avg, min, max

CREATE TEMPORARY TABLE users_fst_snd_sessions
SELECT new_sessions.user_id,
       new_sessions.fst_visit_time,
       new_sessions.website_session_id as fst_session_id,
       min(DATE(ws.created_at)) as snd_visit_time,
       ws.website_session_id as snd_session_id
FROM
(
	SELECT user_id,
		   DATE(created_at) as fst_visit_time,
		   website_session_id
	FROM website_sessions
	WHERE created_at BETWEEN '2014-01-01' AND '2014-11-01'
		  AND is_repeat_session = 0 
) new_sessions
JOIN website_sessions ws
ON new_sessions.user_id = ws.user_id
    AND new_sessions.website_session_id < ws.website_session_id
    AND ws.is_repeat_session = 1
    AND ws.created_at BETWEEN '2014-01-01' AND '2014-11-01'
GROUP BY 1

-- next step
SELECT avg(days_fst_snd_session) avg_days_fst_snd,
       min(days_fst_snd_session) min_days_fst_snd,
       max(days_fst_snd_session) max_days_fst_snd
FROM
(
SELECT user_id,
       DATEDIFF(snd_visit_time, fst_visit_time) as days_fst_snd_session
FROM users_fst_snd_sessions
) user_level

/* 3. 
New vs repeat channel patterns
To understand the channels they come back through? 
Are we paying for these customers with paid search ads multiple times?
To compare new vs. repeat sessions by channel
*/

SELECT CASE WHEN utm_campaign = 'brand' THEN 'paid_brand'
            WHEN utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
            WHEN http_referer IS NULL AND utm_source IS NULL THEN 'direct_type_id'
            WHEN utm_source = 'socialbook' THEN 'paid_social' 
            WHEN http_referer IS NOT NULL AND utm_source IS NULL THEN 'organic search' 
                 END AS channel_group,
		    COUNT(CASE WHEN is_repeat_session = 0 THEN website_session_id END) as new_sessions,
            COUNT(CASE WHEN is_repeat_session = 1 THEN website_session_id END) as repeat_sessions
FROM website_sessions
WHERE created_at BETWEEN '2014-01-01' AND '2014-11-05'
GROUP BY 1
ORDER BY 3 DESC

-- findings: most of results are comming back through organic search or direct type in, and
-- paid brand is cheaper than paid nonbrand. Overall, the company is not paying very much for these subsequent visits.

/*
4. I'm going to do a comparison of conversion rates and revenue per session for repeat sessions vs new sessions
*/

SELECT  is_repeat_session,
		COUNT(DISTINCT ws.website_session_id) as sessions,
        COUNT(DISTINCT order_id)/COUNT(DISTINCT ws.website_session_id) as conv_rate,
        SUM(price_usd)/COUNT(ws.website_session_id) rev_per_session
FROM website_sessions ws
LEFT JOIN orders USING (website_session_id)
WHERE ws.created_at BETWEEN '2014-01-01' AND '2014-11-08'
GROUP BY 1

-- Findings: repeat sessions are more likely to convert and produce more revenue per session.