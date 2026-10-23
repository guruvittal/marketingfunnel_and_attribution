-- ============================================================================
-- Step 5.2 & 5.3: Cartesian Fan-Out Benchmark (Upstream vs. Downstream Variables)
-- Graph: thelook_graph.eCommerce_Integrated
-- Description: Demonstrates why applying plain SQL SUM() to upstream variables
--              (like weekly_budget) across a multi-hop graph or relational JOIN
--              multiplies budget by 432,000x due to downstream path fan-out.
-- ============================================================================

-- Query 1: Benchmark showing Cartesian duplication on Upstream Budget
SELECT
  channel_name,
  -- True upstream budget at channel level:
  ANY_VALUE(weekly_budget) AS actual_budget,
  -- Naive sum across joined downstream paths (DO NOT USE IN PRODUCTION):
  ROUND(SUM(weekly_budget), 2) AS blown_up_budget,
  COUNT(*) AS path_row_count,
  ROUND(SUM(weekly_budget) / ANY_VALUE(weekly_budget)) AS duplication_factor
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (c:channels)<-[:ATTRIBUTED_TO]-(e:events)-[i:INFLUENCED]->(o:orders)
  COLUMNS (c.channel_name, c.weekly_budget)
)
GROUP BY channel_name
ORDER BY path_row_count DESC;

-- Query 2: Equivalent Relational JOIN Cartesian Explosion (Plain SQL)
-- Joining upstream marketing_channels to downstream events and orders produces
-- the identical catastrophic multiplication error:
SELECT
  c.channel_name,
  ANY_VALUE(c.weekly_budget) AS actual_budget,
  ROUND(SUM(c.weekly_budget), 2) AS blown_up_budget,
  COUNT(*) AS path_count
FROM `thelook_graph.marketing_channels` c
JOIN `bigquery-public-data.thelook_ecommerce.events` e
  ON c.channel_name = e.traffic_source
JOIN `thelook_graph.edge_influenced` i
  ON e.id = i.event_id
GROUP BY c.channel_name
ORDER BY path_count DESC;
