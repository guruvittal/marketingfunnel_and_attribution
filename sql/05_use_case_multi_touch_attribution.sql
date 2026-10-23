-- ============================================================================
-- Step 8: Use Case 2 - Multi-Touch Marketing Attribution Comparison
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: GRAPH_TABLE with First-Touch, Last-Touch, and Linear Weighting
-- Scenario: Compare revenue credit assigned to each marketing campaign across
--           different attribution models.
-- Mathematical Rule: For every order, sum of linear_weights = 1.0, ensuring
--                    total attributed revenue matches total gross revenue.
-- ============================================================================

SELECT
  campaign_name,
  channel,
  ROUND(SUM(sale_price * first_touch_weight), 2) AS first_touch_revenue,
  ROUND(SUM(sale_price * last_touch_weight), 2) AS last_touch_revenue,
  ROUND(SUM(sale_price * linear_weight), 2) AS linear_revenue
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (t:touchpoints)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)
  COLUMNS (
    t.campaign_name AS campaign_name,
    t.channel AS channel,
    oi.sale_price,
    i.first_touch_weight,
    i.last_touch_weight,
    i.linear_weight
  )
)
GROUP BY campaign_name, channel
ORDER BY linear_revenue DESC;
