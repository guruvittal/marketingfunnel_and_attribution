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
  channel,
  campaign_name,
  SUM(total_budget) AS actual_budget
FROM `thelook_graph.marketing_campaigns`
GROUP BY channel, campaign_name;

-- ----------------------------------------------------------------------------
-- 2. Plain SQL SUM() on Multi-Table JOIN: CATASTROPHIC FAN-OUT (ANTI-PATTERN)
-- Joining upstream campaigns (1 row per campaign) to downstream touchpoints/orders
-- (hundreds of thousands of rows) duplicates the budget column across every single joined path row.
-- Email VIP Weekly Drop budget blows up from $60,000 to $66.7 BILLION (1,111,635x ERROR)!
-- ----------------------------------------------------------------------------
SELECT 
  c.campaign_name,
  c.total_budget AS actual_budget,
  SUM(c.total_budget) AS blown_up_budget, -- 1,111,635x ERROR!
  COUNT(*) AS total_paths
FROM `thelook_graph.marketing_campaigns` c
JOIN `thelook_graph.touchpoints` t
  ON c.campaign_name = t.campaign_name
JOIN `thelook_graph.edge_influenced` i
  ON t.touchpoint_id = i.touchpoint_id
GROUP BY c.campaign_name, c.total_budget;

-- ----------------------------------------------------------------------------
-- 3. GRAPH_TABLE: For Paths, Traversal Filters, & Leaf-Grain Attributions
-- Use when you need multi-hop topology matching (e.g. touchpoint -> order -> item -> product)
-- and compute downstream metrics using normalized leaf weights (sum(w_i) = 1.0).
-- ----------------------------------------------------------------------------
SELECT
  campaign_name,
  channel,
  ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
  ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (t:touchpoints)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
  COLUMNS (
    t.campaign_name AS campaign_name,
    t.channel AS channel,
    oi.sale_price,
    p.cost,
    i.linear_weight
  )
)
GROUP BY campaign_name, channel;

-- ----------------------------------------------------------------------------
-- 4. GRAPH_EXPAND: For Multi-Grain Metrics across Upstream & Downstream Nodes
-- Use when you want to report upstream coarse metrics (e.g. total_campaign_budget)
-- side-by-side with downstream interaction metrics (total_clicks, total_ad_spend) using declared MEASUREs.
-- ----------------------------------------------------------------------------
SELECT
  campaigns_channel AS channel,
  campaigns_campaign_name AS campaign_name,
  AGG(campaigns_total_campaign_budget) AS total_budget,
  AGG(touchpoints_total_clicks) AS total_clicks,
  AGG(touchpoints_unique_reach) AS unique_reach,
  ROUND(AGG(touchpoints_total_ad_spend), 2) AS total_ad_spend,
  ROUND(AGG(campaigns_total_campaign_budget) - AGG(touchpoints_total_ad_spend), 2) AS remaining_budget,
  ROUND(AGG(touchpoints_total_ad_spend) / NULLIF(AGG(touchpoints_total_clicks), 0), 2) AS effective_avg_cpc
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "touchpoints")
GROUP BY channel, campaign_name
ORDER BY total_ad_spend DESC;
