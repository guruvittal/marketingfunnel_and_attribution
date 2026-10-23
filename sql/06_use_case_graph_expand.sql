-- ============================================================================
-- Step 9: Use Case 3 - Multi-Grain Reporting with GRAPH_EXPAND and AGG()
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: GRAPH_EXPAND with declared MEASUREs
-- Scenario: Safely roll up upstream variables (total_budget at campaign grain)
--           alongside downstream interaction measures (total_clicks, unique_reach, total_ad_spend)
--           without fan-out multiplication error or complex CTE joins.
-- ============================================================================

-- Query 1: Executive Campaign Budget vs. Ad Spend & Reach Scorecard (Touchpoints root)
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

-- Query 2: Product Category multi-grain rollup (Order Items root)
SELECT
  products_category AS category,
  ROUND(AGG(order_items_gross_revenue), 2) AS category_revenue,
  AGG(order_items_total_items_sold) AS items_sold,
  ROUND(AGG(products_avg_cost), 2) AS avg_item_cost,
  ROUND(AGG(products_avg_retail_price), 2) AS avg_item_retail_price
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "order_items")
GROUP BY category
ORDER BY category_revenue DESC
LIMIT 10;
