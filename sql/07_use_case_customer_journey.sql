-- ============================================================================
-- Step 10: Use Case 4 - Multi-Touch Customer Journey (Pure ISO GQL)
-- Graph: thelook_graph.eCommerce_Integrated
-- Operator: Pure ISO GQL (GRAPH ... MATCH ... RETURN)
-- Scenario: Trace an active user's (e.g. user_id = 65516) browsing touchpoints
--           leading to order conversions across marketing channels.
-- ============================================================================

-- Query 1: Pure ISO GQL Tabular Traversal
GRAPH `thelook_graph.eCommerce_Integrated`
MATCH (u:users)-[:GENERATED_EVENT]->(e:events)-[i:INFLUENCED]->(o:orders)
WHERE u.id = 65516
RETURN
  u.id AS user_id,
  u.first_name,
  e.traffic_source,
  e.event_type,
  i.touchpoint_rank,
  i.linear_weight,
  o.order_id
ORDER BY o.order_id, i.touchpoint_rank
LIMIT 10;

-- Query 2: Graph Traversal returning JSON for Visual Graph Exploration
GRAPH `thelook_graph.eCommerce_Integrated`
MATCH (u:users)-[:GENERATED_EVENT]->(e:events)-[i:INFLUENCED]->(o:orders)
WHERE u.id = 65516
RETURN
  TO_JSON(u) AS user_node,
  TO_JSON(e) AS event_node,
  TO_JSON(i) AS influenced_edge,
  TO_JSON(o) AS order_node
LIMIT 10;
