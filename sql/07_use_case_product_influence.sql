-- ============================================================================
-- Use Case 4: Product-Level Campaign Influence & Channel Affinity
-- Graph: eCommerce_Integrated
-- Operator: Hybrid GRAPH_TABLE (5-Hop Traversal)
-- Scenario: Discover which marketing campaigns drive sales for specific product categories
-- ============================================================================

SELECT
    category AS product_category,
    product_name,
    channel AS marketing_channel,
    campaign_name,
    COUNT(DISTINCT order_id) AS orders_count,
    ROUND(SUM(CAST(net_revenue AS FLOAT64) * attribution_weight), 2) AS attributed_sales,
    ROUND(AVG(days_to_convert), 1) AS avg_days_to_convert
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
    prod.category AS category,
    prod.product_name AS product_name,
    o.order_id AS order_id,
    oi.net_revenue AS net_revenue,
    i.attribution_weight AS attribution_weight,
    i.days_to_convert AS days_to_convert
  )
)
GROUP BY category, product_name, channel, campaign_name
ORDER BY category, attributed_sales DESC;
