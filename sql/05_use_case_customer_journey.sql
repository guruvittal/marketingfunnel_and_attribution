-- ============================================================================
-- Use Case 2: Multi-Touch Customer Conversion Journey
-- Graph: eCommerce_Integrated
-- Operator: Pure ISO GQL (GRAPH ... MATCH ... RETURN)
-- Scenario: Trace Customer CUST_0888's touchpoint journey to conversion
-- ============================================================================

-- Query 1: Graph Traversal returning structured columns
GRAPH `eRetail_marketing.eCommerce_Integrated`
MATCH (c:campaigns)
        <-[g:GENERATED_BY]-(tp:touchpoints)
        -[i:INFLUENCED]->(o:orders),
      (cust:customers WHERE cust.customer_id = 'CUST_0888')
        -[e:ENGAGED_WITH]->(tp)
RETURN
    cust.customer_id,
    c.campaign_name,
    c.channel,
    tp.touchpoint_id,
    tp.device_type,
    tp.cpc_cost,
    i.attribution_weight,
    i.touchpoint_rank,
    o.order_id
ORDER BY o.order_id, i.touchpoint_rank;

-- Query 2: Graph Traversal returning JSON for Visual Graph Exploration
GRAPH `eRetail_marketing.eCommerce_Integrated`
MATCH (c:campaigns)<-[g:GENERATED_BY]-(tp:touchpoints)-[i:INFLUENCED]->(o:orders),
      (cust:customers WHERE cust.customer_id = 'CUST_0888')-[e:ENGAGED_WITH]->(tp)
RETURN
    TO_JSON(cust) AS customer,
    TO_JSON(e) AS edge_engaged,
    TO_JSON(tp) AS touchpoint,
    TO_JSON(g) AS edge_generated,
    TO_JSON(c) AS campaign,
    TO_JSON(i) AS edge_influenced,
    TO_JSON(o) AS orders
LIMIT 20;
