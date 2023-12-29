## Maven Fuzzy Factory E-commerce Analytics ##
### Introduction ###
Maven Fuzzy Factory is a fictional toy company, running an online shop. The objective was to act as an eCommerce Database Analyst to help
stakeholders (CEO, product manager, marketing manager...) understand business health and provide actionable recommendations.

### The Goal ###
- Analyze and optimize marketing channels, measure and test website conversion performance for improving bid strategy
- Use data to understand the impact of new product launches
- Analyze most-viewed pages and landing page performance, and use conversion funnel analysis to understand how many users continue/abondon at each step
- Analyze seasonality and business patterns to help the company maximize efficiency and anticipate future trends
- Analyze customer behavior to understand which products users are most likely to purchase together for better cross-selling and upselling

### ER Diagram ###
![Database ERD](https://github.com/mingyuan9/PortfolioProject/blob/main/ERD.png)

### Database Description ### 
  - website_sessions table
    - utm parameters(utm_source/utm_campaign/utm_content) are associated with paid traffic   
  - website_pageviews table
  - products
  - orders
    - primary_product_id column: each order has a primary product
  - order_items
    - is_primary_item BINARY column: if an item is the primary item, then it's 1, if an item is cross-selling item added in cart page, then it's 0
  - order_item_refunds
