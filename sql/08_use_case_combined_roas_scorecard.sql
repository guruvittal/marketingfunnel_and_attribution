-- ============================================================================
-- Step 11: Use Case 5 - Unified Executive ROAS Scorecard
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: Single GoogleSQL Query fusing GRAPH_EXPAND and GRAPH_TABLE
-- Scenario: Combines top-of-funnel marketing metrics (safe weekly budget and
--           session volume via GRAPH_EXPAND) with bottom-of-funnel multi-hop
--           profit attribution (via GRAPH_TABLE) on the SAME Property Graph.
-- ============================================================================

WITH marketing_funnel AS (
  -- 1. Top-of-funnel marketing metrics from eCommerce_Integrated via GRAPH_EXPAND
  SELECT
    channels_channel_name AS channel,
    AGG(channels_total_budget) AS weekly_budget,
    AGG(events_total_events) AS total_events,
    AGG(events_total_sessions) AS total_sessions
  FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "events")
  GROUP BY channel
),

sales_attribution AS (
  -- 2. Bottom-of-funnel 4-hop profit attribution from eCommerce_Integrated via GRAPH_TABLE
  SELECT
    channel,
    ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
    ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
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
  GROUP BY channel
)

SELECT
  m.channel,
  m.weekly_budget,
  m.total_events,
  m.total_sessions,
  s.attributed_revenue,
  s.attributed_cogs,
  s.gross_profit,
  ROUND(s.attributed_revenue / NULLIF(m.weekly_budget, 0), 2) AS roas_on_budget,
  ROUND(SAFE_DIVIDE(s.gross_profit, s.attributed_revenue) * 100, 2) AS gross_margin_pct
FROM marketing_funnel m
JOIN sales_attribution s
  ON m.channel = s.channel
ORDER BY s.attributed_revenue DESC;
