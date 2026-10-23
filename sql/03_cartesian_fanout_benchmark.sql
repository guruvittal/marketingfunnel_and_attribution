-- ============================================================================
-- Step 6: Benchmark - Demonstrating the Cartesian Fan-Out Multiplier
-- Graph: thelook_graph.eCommerce_Integrated
-- Description: Shows why standard relational SQL fails on multi-grain marketing
--              joins by blowing up upstream campaign budgets by thousands of times.
-- ============================================================================

-- Query 1: The Broken Relational SQL Join
-- Upstream campaign budget is duplicated across every leaf-grain line item!
SELECT
  c.channel,
  c.campaign_name,
  c.total_budget AS actual_campaign_budget,
  COUNT(*) AS joined_rows,
  ROUND(SUM(c.total_budget), 2) AS blown_up_budget,
  ROUND(SUM(c.total_budget) / c.total_budget, 0) AS budget_multiplication_factor,
  ROUND(SUM(oi.sale_price), 2) AS total_gross_sales
FROM `thelook_graph.marketing_campaigns` c
JOIN `thelook_graph.touchpoints` t
  ON c.campaign_name = t.campaign_name
JOIN `bigquery-public-data.thelook_ecommerce.orders` o
  ON t.user_id = o.user_id
JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi
  ON o.order_id = oi.order_id
GROUP BY c.channel, c.campaign_name, c.total_budget
ORDER BY joined_rows DESC;
