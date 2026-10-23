-- ============================================================================
-- Step 8: Use Case 2 - Channel Profit Contribution & Gross Margin Analysis
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: GRAPH_TABLE (4-Hop Traversal: Event -> Order -> OrderItem -> Product)
-- Scenario: Connect marketing touchpoints all the way through to product COGS
--           to measure true Gross Profit and Gross Margin % by marketing channel.
-- ============================================================================

SELECT
  channel,
  ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
  ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
  ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit,
  ROUND(SAFE_DIVIDE(SUM((sale_price - cost) * linear_weight), SUM(sale_price * linear_weight)) * 100, 2) AS gross_margin_pct
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
ORDER BY gross_profit DESC;
