-- ============================================================================
-- Step 11: Use Case 5 - Unified Executive ROAS Scorecard
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: Single GoogleSQL Query fusing GRAPH_EXPAND and GRAPH_TABLE
-- Scenario: Combines top-of-funnel marketing metrics (safe weekly budget, reach,
--           and actual ad spend via GRAPH_EXPAND) with bottom-of-funnel multi-hop
--           profit attribution (via GRAPH_TABLE) on the SAME Property Graph.
-- ============================================================================

WITH marketing_funnel AS (
  -- 1. Top-of-funnel marketing metrics from eCommerce_Integrated via GRAPH_EXPAND
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
),

sales_attribution AS (
  -- 2. Bottom-of-funnel 4-hop profit attribution from eCommerce_Integrated via GRAPH_TABLE
  SELECT
    campaign_name,
    ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
    ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
    ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit
  FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
    MATCH (t:touchpoints)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
    COLUMNS (
      t.campaign_name AS campaign_name,
      oi.sale_price,
      p.cost,
      i.linear_weight
    )
  )
  GROUP BY campaign_name
)

SELECT
  m.channel,
  m.campaign_name,
  m.total_budget,
  m.total_ad_spend,
  m.remaining_budget,
  m.effective_avg_cpc,
  s.attributed_revenue,
  s.gross_profit,
  ROUND(s.attributed_revenue / NULLIF(m.total_ad_spend, 0), 2) AS roas_on_spend,
  ROUND(s.attributed_revenue / NULLIF(m.total_budget, 0), 2) AS roas_on_budget,
  ROUND(SAFE_DIVIDE(s.gross_profit, s.attributed_revenue) * 100, 2) AS gross_margin_pct
FROM marketing_funnel m
JOIN sales_attribution s ON m.campaign_name = s.campaign_name
ORDER BY s.gross_profit DESC;
