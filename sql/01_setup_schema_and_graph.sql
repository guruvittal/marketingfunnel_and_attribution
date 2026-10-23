-- ============================================================================
-- Step 1 & 2: Setup Schema, Marketing Reference Data, Attributed Edges,
--             and Unified Property Graph with Semantic Measures
-- Dataset: thelook_graph
-- Public Data Source: bigquery-public-data.thelook_ecommerce
-- Cloud Storage Snapshot: gs://sample-data-and-media/thelook_dataset_snapshot/
-- ============================================================================

-- 1. Create Graph Workspace Dataset
CREATE SCHEMA IF NOT EXISTS `thelook_graph`
OPTIONS (
  location = 'US',
  description = 'Marketing Attribution & ROAS Graph using thelook_ecommerce'
);

-- ----------------------------------------------------------------------------
-- 2. Create Marketing Channels Reference View
--    Defines top-of-funnel upstream channel parameters: weekly budget,
--    benchmark CPC, and target ROAS.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `thelook_graph.marketing_channels` AS
SELECT "Adwords" AS channel_name, 50000.0 AS weekly_budget, 1.50 AS default_cpc, 4.0 AS target_roas UNION ALL
SELECT "Facebook", 30000.0, 1.10, 3.5 UNION ALL
SELECT "YouTube", 25000.0, 0.85, 3.0 UNION ALL
SELECT "Email", 10000.0, 0.10, 8.0 UNION ALL
SELECT "Organic", 5000.0, 0.00, 10.0;

-- ----------------------------------------------------------------------------
-- 3. Create Attributed Edge Table: edge_influenced
--    Connects browsing events to orders within a 30-day lookback window.
--    Pre-calculates mathematically normalized attribution weights:
--      • first_touch_weight: 1.0 for earliest touchpoint, 0.0 otherwise
--      • last_touch_weight:  1.0 for latest touchpoint, 0.0 otherwise
--      • linear_weight:      1.0 / total_touchpoints (satisfies sum(w_i) = 1.0)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `thelook_graph.edge_influenced` AS
WITH ranked_touchpoints AS (
  SELECT
    e.id AS event_id,
    o.order_id,
    e.traffic_source,
    e.created_at AS event_timestamp,
    o.created_at AS order_timestamp,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY e.created_at ASC) AS touchpoint_asc,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY e.created_at DESC) AS touchpoint_desc,
    COUNT(*) OVER (PARTITION BY o.order_id) AS total_touchpoints
  FROM `bigquery-public-data.thelook_ecommerce.orders` o
  JOIN `bigquery-public-data.thelook_ecommerce.events` e
    ON o.user_id = e.user_id 
   AND e.created_at <= o.created_at
   AND e.created_at >= TIMESTAMP_SUB(o.created_at, INTERVAL 30 DAY)
  WHERE o.status NOT IN ("Cancelled", "Returned")
)
SELECT 
  event_id,
  order_id,
  traffic_source,
  touchpoint_asc AS touchpoint_rank,
  total_touchpoints,
  IF(touchpoint_asc = 1, 1.0, 0.0) AS first_touch_weight,
  IF(touchpoint_desc = 1, 1.0, 0.0) AS last_touch_weight,
  ROUND(1.0 / total_touchpoints, 4) AS linear_weight
FROM ranked_touchpoints;

-- ----------------------------------------------------------------------------
-- 4. Create Unified Property Graph: eCommerce_Integrated
--    Zero-copy mapping over public Google dataset bigquery-public-data.thelook_ecommerce
--    and local marketing views/edges. Includes declared semantic MEASUREs.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROPERTY GRAPH `thelook_graph.eCommerce_Integrated`
NODE TABLES (
  -- Users Node Table
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

  -- Events Node Table (Web Traffic & Touchpoint Interactions)
  `bigquery-public-data.thelook_ecommerce.events` AS events
    KEY (id)
    LABEL events PROPERTIES (
      id,
      user_id,
      session_id,
      created_at,
      traffic_source,
      event_type,
      browser,
      city,
      state,
      MEASURE(COUNT(id)) AS total_events,
      MEASURE(COUNT(DISTINCT session_id)) AS total_sessions
    ),

  -- Orders Node Table (Commercial Transactions)
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

  -- Order Items Node Table (Line-Item Financial Leaf Grain)
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

  -- Products Catalog Node Table
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
    ),

  -- Marketing Channels Node Table (Upstream Budget & Targets)
  `thelook_graph.marketing_channels` AS channels
    KEY (channel_name)
    LABEL channels PROPERTIES (
      channel_name,
      weekly_budget,
      target_roas,
      MEASURE(SUM(weekly_budget)) AS total_budget
    )
)
EDGE TABLES (
  -- Event -> Channel: Edge table from events to channels
  `bigquery-public-data.thelook_ecommerce.events` AS event_channel
    KEY (id)
    SOURCE KEY (id) REFERENCES events (id)
    DESTINATION KEY (traffic_source) REFERENCES channels (channel_name)
    LABEL ATTRIBUTED_TO NO PROPERTIES,

  -- User -> Event: Edge table from users to events
  `bigquery-public-data.thelook_ecommerce.events` AS user_event
    KEY (id)
    SOURCE KEY (user_id) REFERENCES users (id)
    DESTINATION KEY (id) REFERENCES events (id)
    LABEL GENERATED_EVENT NO PROPERTIES,

  -- Event -> Order: Attributed conversion edge with multi-touch weights
  `thelook_graph.edge_influenced` AS edge_influenced
    KEY (event_id, order_id)
    SOURCE KEY (event_id) REFERENCES events (id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL INFLUENCED PROPERTIES (
      touchpoint_rank,
      total_touchpoints,
      first_touch_weight,
      last_touch_weight,
      linear_weight
    ),

  -- Order Item -> Order: Line item belongs to order
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_order
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL BELONGS_TO NO PROPERTIES,

  -- Order Item -> Product: Line item references product catalog
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_product
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (product_id) REFERENCES products (id)
    LABEL IS_PRODUCT NO PROPERTIES
);
