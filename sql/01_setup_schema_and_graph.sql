-- ============================================================================
-- Step 1 & 2: Setup Schema, Marketing Campaigns, Attributed Touchpoints,
--             and Unified Property Graph with Semantic Measures
-- Dataset: thelook_graph
-- Base Public Data: bigquery-public-data.thelook_ecommerce
-- Snapshot Bucket: gs://sample-data-and-media/thelook_dataset_snapshot/
-- ============================================================================

-- 1. Create Local Graph Dataset
CREATE SCHEMA IF NOT EXISTS `thelook_graph`
OPTIONS (
  location = 'US',
  description = 'Marketing Attribution & ROAS Graph using thelook_ecommerce'
);

-- ----------------------------------------------------------------------------
-- 2. Create Marketing Campaigns Reference View
--    Defines top-of-funnel upstream campaign parameters: weekly budgets,
--    benchmark target ROAS, and channel grouping.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `thelook_graph.marketing_campaigns` AS
SELECT 'Paid Search' AS channel, 'Q4_Search_Generic_Audio' AS campaign_name, 1500000.0 AS total_budget, 4.0 AS target_roas UNION ALL
SELECT 'Paid Search', 'Q4_Search_Brand_Electronics', 1100000.0, 5.0 UNION ALL
SELECT 'Paid Social', 'Q4_Meta_IG_Retargeting', 250000.0, 4.5 UNION ALL
SELECT 'Video', 'Q4_YouTube_Video_Awareness', 220000.0, 2.5 UNION ALL
SELECT 'Paid Social', 'Q4_TikTok_Prospecting_GenZ', 150000.0, 3.0 UNION ALL
SELECT 'Email Marketing', 'Q4_Email_Cart_Abandonment', 75000.0, 10.0 UNION ALL
SELECT 'Email Marketing', 'Q4_Email_VIP_Weekly_Drop', 60000.0, 8.0 UNION ALL
SELECT 'Organic', 'Organic_Search_SEO', 25000.0, 15.0;

-- ----------------------------------------------------------------------------
-- 3. Create Enriched Touchpoints View (over public web events)
--    Connects 2.4M raw web events to specific Q4 ad campaigns and adds
--    industry benchmark CPC costs for ad spend calculation.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `thelook_graph.touchpoints` AS
SELECT
  e.id AS touchpoint_id,
  e.user_id,
  e.session_id,
  e.created_at,
  e.event_type,
  e.browser,
  e.traffic_source,
  -- Deterministic campaign assignment based on traffic source
  CASE
    WHEN e.traffic_source = 'Adwords' AND MOD(e.id, 2) = 0 THEN 'Q4_Search_Generic_Audio'
    WHEN e.traffic_source = 'Adwords' THEN 'Q4_Search_Brand_Electronics'
    WHEN e.traffic_source = 'Facebook' AND MOD(e.id, 2) = 0 THEN 'Q4_Meta_IG_Retargeting'
    WHEN e.traffic_source = 'Facebook' THEN 'Q4_TikTok_Prospecting_GenZ'
    WHEN e.traffic_source = 'YouTube' THEN 'Q4_YouTube_Video_Awareness'
    WHEN e.traffic_source = 'Email' AND MOD(e.id, 2) = 0 THEN 'Q4_Email_Cart_Abandonment'
    WHEN e.traffic_source = 'Email' THEN 'Q4_Email_VIP_Weekly_Drop'
    ELSE 'Organic_Search_SEO'
  END AS campaign_name,
  -- High-level channel classification
  CASE
    WHEN e.traffic_source = 'Adwords' THEN 'Paid Search'
    WHEN e.traffic_source = 'Facebook' THEN 'Paid Social'
    WHEN e.traffic_source = 'YouTube' THEN 'Video'
    WHEN e.traffic_source = 'Email' THEN 'Email Marketing'
    ELSE 'Organic'
  END AS channel,
  -- Realistic benchmark CPC cost per interaction
  CASE
    WHEN e.traffic_source = 'Adwords' AND MOD(e.id, 2) = 0 THEN 3.78
    WHEN e.traffic_source = 'Adwords' THEN 2.64
    WHEN e.traffic_source = 'Facebook' AND MOD(e.id, 2) = 0 THEN 1.85
    WHEN e.traffic_source = 'Facebook' THEN 0.99
    WHEN e.traffic_source = 'YouTube' THEN 0.85
    WHEN e.traffic_source = 'Email' AND MOD(e.id, 2) = 0 THEN 0.12
    WHEN e.traffic_source = 'Email' THEN 0.10
    ELSE 0.00
  END AS cpc_cost
FROM `bigquery-public-data.thelook_ecommerce.events` e;

-- ----------------------------------------------------------------------------
-- 4. Create Attributed Edge Table: edge_influenced
--    Connects browsing touchpoints to orders within a 30-day lookback window.
--    Pre-calculates mathematically normalized attribution weights:
--      • first_touch_weight: 1.0 for earliest touchpoint, 0.0 otherwise
--      • last_touch_weight:  1.0 for latest touchpoint, 0.0 otherwise
--      • linear_weight:      1.0 / total_touchpoints (satisfies sum(w_i) = 1.0)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `thelook_graph.edge_influenced` AS
WITH ranked_touchpoints AS (
  SELECT
    t.touchpoint_id,
    o.order_id,
    t.campaign_name,
    t.channel,
    t.cpc_cost,
    t.created_at AS event_timestamp,
    o.created_at AS order_timestamp,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY t.created_at ASC) AS touchpoint_asc,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY t.created_at DESC) AS touchpoint_desc,
    COUNT(*) OVER (PARTITION BY o.order_id) AS total_touchpoints
  FROM `bigquery-public-data.thelook_ecommerce.orders` o
  JOIN `thelook_graph.touchpoints` t
    ON o.user_id = t.user_id 
   AND t.created_at <= o.created_at
   AND t.created_at >= TIMESTAMP_SUB(o.created_at, INTERVAL 30 DAY)
  WHERE o.status NOT IN ('Cancelled', 'Returned')
)
SELECT
  touchpoint_id,
  order_id,
  campaign_name,
  channel,
  cpc_cost,
  touchpoint_asc AS touchpoint_rank,
  total_touchpoints,
  ROUND(TIMESTAMP_DIFF(order_timestamp, event_timestamp, HOUR) / 24.0, 1) AS days_to_convert,
  IF(touchpoint_asc = 1, 1.0, 0.0) AS first_touch_weight,
  IF(touchpoint_desc = 1, 1.0, 0.0) AS last_touch_weight,
  ROUND(1.0 / total_touchpoints, 6) AS linear_weight
FROM ranked_touchpoints;

-- ----------------------------------------------------------------------------
-- 5. Create Unified Property Graph: eCommerce_Integrated
--    Zero-copy mapping over public Google dataset bigquery-public-data.thelook_ecommerce
--    and local marketing views/edges. Includes declared semantic MEASUREs.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROPERTY GRAPH `thelook_graph.eCommerce_Integrated`
NODE TABLES (
  -- 1. Marketing Campaigns Node Table
  `thelook_graph.marketing_campaigns` AS campaigns
    KEY (campaign_name)
    LABEL campaigns PROPERTIES (
      campaign_name,
      channel,
      total_budget,
      target_roas,
      MEASURE(SUM(total_budget)) AS total_campaign_budget
    ),

  -- 2. Marketing Touchpoints Node Table
  `thelook_graph.touchpoints` AS touchpoints
    KEY (touchpoint_id)
    LABEL touchpoints PROPERTIES (
      touchpoint_id,
      user_id,
      session_id,
      campaign_name,
      channel,
      cpc_cost,
      event_type,
      browser,
      created_at,
      MEASURE(SUM(cpc_cost)) AS total_ad_spend,
      MEASURE(COUNT(touchpoint_id)) AS total_clicks,
      MEASURE(COUNT(DISTINCT user_id)) AS unique_reach
    ),

  -- 3. Users Node Table
  `bigquery-public-data.thelook_ecommerce.users` AS users
    KEY (id)
    LABEL users PROPERTIES (
      id,
      first_name,
      last_name,
      email,
      age,
      gender,
      country,
      traffic_source,
      created_at,
      MEASURE(COUNT(DISTINCT id)) AS total_users
    ),

  -- 4. Orders Node Table
  `bigquery-public-data.thelook_ecommerce.orders` AS orders
    KEY (order_id)
    LABEL orders PROPERTIES (
      order_id,
      user_id,
      status,
      created_at,
      num_of_item,
      MEASURE(COUNT(order_id)) AS total_orders
    ),

  -- 5. Order Items Node Table (Line-Item Financial Leaf Grain)
  `bigquery-public-data.thelook_ecommerce.order_items` AS order_items
    KEY (id)
    LABEL order_items PROPERTIES (
      id,
      order_id,
      user_id,
      product_id,
      sale_price,
      status,
      created_at,
      MEASURE(SUM(sale_price)) AS gross_revenue,
      MEASURE(COUNT(id)) AS total_items_sold
    ),

  -- 6. Products Catalog Node Table
  `bigquery-public-data.thelook_ecommerce.products` AS products
    KEY (id)
    LABEL products PROPERTIES (
      id,
      cost,
      category,
      name,
      brand,
      retail_price,
      department,
      MEASURE(AVG(cost)) AS avg_cost,
      MEASURE(AVG(retail_price)) AS avg_retail_price
    )
)
EDGE TABLES (
  -- Touchpoint -> Campaign (GENERATED_BY)
  `thelook_graph.touchpoints` AS touchpoint_campaign
    KEY (touchpoint_id)
    SOURCE KEY (touchpoint_id) REFERENCES touchpoints (touchpoint_id)
    DESTINATION KEY (campaign_name) REFERENCES campaigns (campaign_name)
    LABEL GENERATED_BY NO PROPERTIES,

  -- User -> Touchpoint (ENGAGED_WITH)
  `thelook_graph.touchpoints` AS user_touchpoint
    KEY (touchpoint_id)
    SOURCE KEY (user_id) REFERENCES users (id)
    DESTINATION KEY (touchpoint_id) REFERENCES touchpoints (touchpoint_id)
    LABEL ENGAGED_WITH NO PROPERTIES,

  -- Touchpoint -> Order (INFLUENCED)
  `thelook_graph.edge_influenced` AS edge_influenced
    KEY (touchpoint_id, order_id)
    SOURCE KEY (touchpoint_id) REFERENCES touchpoints (touchpoint_id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL INFLUENCED PROPERTIES (
      campaign_name,
      channel,
      cpc_cost,
      touchpoint_rank,
      total_touchpoints,
      days_to_convert,
      first_touch_weight,
      last_touch_weight,
      linear_weight
    ),

  -- Order Item -> Order (BELONGS_TO)
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_order
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL BELONGS_TO NO PROPERTIES,

  -- Order Item -> Product (IS_PRODUCT)
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_product
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (product_id) REFERENCES products (id)
    LABEL IS_PRODUCT NO PROPERTIES
);
