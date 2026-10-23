-- ============================================================================
-- Architectural Decision Guide: Plain SQL SUM() vs. Relational JOIN
--                               vs. GRAPH_TABLE vs. GRAPH_EXPAND
-- Graph: thelook_graph.eCommerce_Integrated
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Plain SQL SUM() on Single Table: SAFE & RECOMMENDED
-- When aggregating a column at its native table grain, plain SUM() is 100% correct.
-- ----------------------------------------------------------------------------
SELECT 
  channel_name,
  SUM(weekly_budget) AS actual_budget
FROM `thelook_graph.marketing_channels`
GROUP BY channel_name;

-- ----------------------------------------------------------------------------
-- 2. Plain SQL SUM() on Multi-Table JOIN: CATASTROPHIC FAN-OUT (ANTI-PATTERN)
-- Joining upstream channels (1 row per channel) to downstream events/orders
-- (100k+ rows) duplicates the budget column across every single joined path row.
-- Email budget blows up from $10,000 to $4.32 BILLION!
-- ----------------------------------------------------------------------------
SELECT 
  c.channel_name,
  SUM(c.weekly_budget) AS blown_up_budget, -- 432,247x ERROR!
  COUNT(*) AS total_paths
FROM `thelook_graph.marketing_channels` c
JOIN `bigquery-public-data.thelook_ecommerce.events` e
  ON c.channel_name = e.traffic_source
JOIN `thelook_graph.edge_influenced` i
  ON e.id = i.event_id
GROUP BY c.channel_name;

-- ----------------------------------------------------------------------------
-- 3. GRAPH_TABLE: For Paths, Traversal Filters, & Leaf-Grain Attributions
-- Use when you need multi-hop topology matching (e.g. event -> order -> item -> product)
-- and compute downstream metrics using normalized leaf weights (sum(w_i) = 1.0).
-- ----------------------------------------------------------------------------
SELECT
  channel,
  ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
  ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (e:events)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
  COLUMNS (
    e.traffic_source AS channel,
    oi.sale_price,
    p.cost,
    i.linear_weight
  )
)
GROUP BY channel;

-- ----------------------------------------------------------------------------
-- 4. GRAPH_EXPAND: For Multi-Grain Metrics across Upstream & Downstream Nodes
-- Use when you want to report upstream coarse metrics (e.g. weekly_budget)
-- side-by-side with downstream interaction metrics (total_events) using declared MEASUREs.
-- ----------------------------------------------------------------------------
SELECT
  channels_channel_name AS channel,
  AGG(channels_total_budget) AS weekly_budget,
  AGG(events_total_events) AS total_events
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "events")
GROUP BY channel;
