-- ============================================================================
-- Step 9: Use Case 3 - Multi-Grain Reporting with GRAPH_EXPAND and AGG()
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: GRAPH_EXPAND with declared MEASUREs
-- Scenario: Safely roll up upstream variables (weekly_budget at channel grain)
--           alongside downstream interaction measures (total_events, total_sessions)
--           without fan-out multiplication error or complex CTE joins.
-- Note: When a graph has multiple root node tables, start_node must be specified.
-- ============================================================================

-- Query 1: Channel-level multi-grain rollup (Events root)
SELECT
  channels_channel_name AS channel,
  AGG(channels_total_budget) AS weekly_budget,
  AGG(events_total_events) AS total_events,
  AGG(events_total_sessions) AS total_sessions
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "events")
GROUP BY channel
ORDER BY total_events DESC;

-- Query 2: Product Category multi-grain rollup (Order Items root)
SELECT
  products_category AS category,
  AGG(order_items_gross_revenue) AS category_revenue,
  AGG(order_items_total_items_sold) AS items_sold,
  AGG(products_avg_cost) AS avg_item_cost,
  AGG(products_avg_retail_price) AS avg_item_retail_price
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "order_items")
GROUP BY category
ORDER BY category_revenue DESC
LIMIT 10;
