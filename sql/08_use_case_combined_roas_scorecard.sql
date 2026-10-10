-- ============================================================================
-- Use Case 5: Unified Executive ROAS Scorecard (Dual Views on a Single Graph)
-- Graph: eCommerce_Integrated (Unified Single Graph)
-- Operator: Single GoogleSQL CTE Query combining GRAPH_EXPAND and GRAPH_TABLE
-- Scenario: Fuse top-of-funnel marketing measures (safe budgets & spend via GRAPH_EXPAND)
--           with bottom-of-funnel profit attribution (via GRAPH_TABLE) on the SAME
--           Property Graph to calculate True ROAS on Actual Ad Spend vs. ROAS on Budget.
-- ============================================================================

WITH marketing_funnel AS (
  -- 1. Top-of-funnel marketing metrics from eCommerce_Integrated via GRAPH_EXPAND
  SELECT
    campaigns_channel AS channel,
    campaigns_campaign_name AS campaign_name,
    AGG(campaigns_total_campaign_budget) AS budget,
    AGG(touchpoints_total_clicks) AS clicks,
    ROUND(AGG(touchpoints_total_ad_spend), 2) AS ad_spend
  FROM GRAPH_EXPAND("eRetail_marketing.eCommerce_Integrated", start_node => "touchpoints")
  GROUP BY channel, campaign_name
),

sales_attribution AS (
  -- 2. Bottom-of-funnel 5-hop profit attribution from eCommerce_Integrated via GRAPH_TABLE
  SELECT
    campaign_name,
    ROUND(SUM(CAST(net_revenue AS FLOAT64) * attribution_weight), 2) AS attributed_revenue,
    ROUND(SUM(CAST(cost_of_goods AS FLOAT64) * attribution_weight), 2) AS attributed_cogs
  FROM GRAPH_TABLE(
    `eRetail_marketing.eCommerce_Integrated`
    MATCH (c:campaigns)
          <-[g:GENERATED_BY]-(tp:touchpoints)
          -[i:INFLUENCED]->(o:orders)
          <-[b:BELONGS_TO]-(oi:order_items)
    COLUMNS (
      c.campaign_name AS campaign_name,
      oi.net_revenue AS net_revenue,
      oi.cost_of_goods AS cost_of_goods,
      i.attribution_weight AS attribution_weight
    )
  )
  GROUP BY campaign_name
)

-- 3. Combine both views of the same graph into a unified Executive ROAS Scorecard
SELECT
  mf.channel,
  mf.campaign_name,
  mf.budget,
  mf.clicks,
  mf.ad_spend,
  sa.attributed_revenue,
  sa.attributed_cogs,
  ROUND(sa.attributed_revenue - sa.attributed_cogs, 2) AS gross_profit,
  ROUND(sa.attributed_revenue / NULLIF(mf.ad_spend, 0), 2) AS roas_on_actual_spend,
  ROUND(sa.attributed_revenue / NULLIF(mf.budget, 0), 2) AS roas_on_budget
FROM marketing_funnel mf
JOIN sales_attribution sa ON mf.campaign_name = sa.campaign_name
ORDER BY gross_profit DESC;
