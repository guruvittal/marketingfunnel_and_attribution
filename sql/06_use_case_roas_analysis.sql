-- ============================================================================
-- Use Case 3: Campaign Profit Contribution & Margin Analysis (GRAPH_TABLE)
-- Graph: eCommerce_Integrated
-- Operator: GRAPH_TABLE with Leaf-Grain Weighted Aggregations
-- Scenario: Calculate multi-touch attributed revenue, cost of goods sold (COGS),
--           gross profit contribution, and gross margin percentage across campaigns.
--           (Note: Aggregates at the finest leaf grain with normalized weights;
--            campaign budget & ad spend are joined via GRAPH_EXPAND in Use Case 5)
-- ============================================================================

SELECT
    channel,
    campaign_name,
    ROUND(SUM(CAST(net_revenue AS FLOAT64) * attribution_weight), 2) AS total_attributed_revenue,
    ROUND(SUM(CAST(cost_of_goods AS FLOAT64) * attribution_weight), 2) AS total_attributed_cogs,
    ROUND(SUM(CAST(net_revenue AS FLOAT64) * attribution_weight) - SUM(CAST(cost_of_goods AS FLOAT64) * attribution_weight), 2) AS gross_profit,
    ROUND(SAFE_DIVIDE(
      SUM(CAST(net_revenue AS FLOAT64) * attribution_weight) - SUM(CAST(cost_of_goods AS FLOAT64) * attribution_weight),
      SUM(CAST(net_revenue AS FLOAT64) * attribution_weight)
    ) * 100, 1) AS gross_margin_pct
FROM GRAPH_TABLE(
  `eRetail_marketing.eCommerce_Integrated`
  MATCH (c:campaigns)
        <-[g:GENERATED_BY]-(tp:touchpoints)
        -[i:INFLUENCED]->(o:orders)
        <-[b:BELONGS_TO]-(oi:order_items)
        -[p:IS_PRODUCT]->(prod:products)
  COLUMNS (
    c.campaign_name AS campaign_name,
    c.channel AS channel,
    oi.net_revenue AS net_revenue,
    oi.cost_of_goods AS cost_of_goods,
    i.attribution_weight AS attribution_weight
  )
)
GROUP BY channel, campaign_name
ORDER BY gross_profit DESC;
