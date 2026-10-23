-- ============================================================================
-- Step 9: Use Case 3 - Campaign Profit Contribution & Gross Margin Analysis
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: GRAPH_TABLE (4-Hop Traversal: Touchpoint -> Order -> OrderItem -> Product)
-- Scenario: Connect marketing touchpoints all the way through to product COGS
--           to measure true Gross Profit and Gross Margin % by marketing campaign.
-- ============================================================================

SELECT
  campaign_name,
  channel,
  ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
  ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
  ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit,
  ROUND(SAFE_DIVIDE(SUM((sale_price - cost) * linear_weight), SUM(sale_price * linear_weight)) * 100, 2) AS gross_margin_pct
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
GROUP BY campaign_name, channel
ORDER BY gross_profit DESC;
