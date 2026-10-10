-- ============================================================================
-- Step 3: Create Unified BigQuery Property Graph
-- Graph: eCommerce_Integrated (Unified Enterprise Graph with Semantic Measures)
-- Query Operators: 
--   1. GRAPH_EXPAND("eRetail_marketing.eCommerce_Integrated", start_node => "touchpoints")
--   2. Pure ISO GQL: GRAPH `eRetail_marketing.eCommerce_Integrated` MATCH ... RETURN ...
--   3. GRAPH_TABLE(`eRetail_marketing.eCommerce_Integrated` MATCH ... COLUMNS ...)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Property Graph: eCommerce_Integrated
-- Topology: Full 6-Entity Unified Mesh connecting Marketing Touchpoints to Fulfillment
-- Features: Zero-copy mapping over 6 tables, semantic MEASUREs, and multi-hop edges.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROPERTY GRAPH `eRetail_marketing.eCommerce_Integrated`
NODE TABLES (
  -- 1. Campaigns Node Table
  `eRetail_marketing.campaigns` AS campaigns
    KEY (campaign_id)
    LABEL campaigns PROPERTIES (
      campaign_id,
      campaign_name,
      channel,
      weekly_budget,
      target_roas,
      MEASURE(SUM(weekly_budget)) AS total_campaign_budget
    ),

  -- 2. Touchpoints Node Table (Marketing Interaction Fact Node)
  `eRetail_marketing.touchpoints` AS touchpoints
    KEY (touchpoint_id)
    LABEL touchpoints PROPERTIES (
      touchpoint_id,
      customer_id,
      campaign_id,
      cpc_cost,
      device_type,
      MEASURE(SUM(cpc_cost)) AS total_ad_spend,
      MEASURE(COUNT(touchpoint_id)) AS total_clicks
    ),

  -- 3. Customers Node Table
  `eRetail_marketing.customers` AS customers
    KEY (customer_id)
    LABEL customers PROPERTIES (
      customer_id,
      customer_segment,
      MEASURE(COUNT(DISTINCT customer_id)) AS total_reach
    ),

  -- 4. Orders Node Table
  `eRetail_marketing.orders` AS orders
    KEY (order_id)
    LABEL orders PROPERTIES (
      order_id,
      order_status,
      shipping_cost,
      MEASURE(COUNT(order_id)) AS total_orders
    ),

  -- 5. Order Items Node Table (Fulfillment & Revenue Fact Node)
  `eRetail_marketing.order_items` AS order_items
    KEY (order_item_id)
    LABEL order_items PROPERTIES (
      order_item_id,
      product_id,
      order_id,
      sale_price,
      discount_amount,
      cost_of_goods,
      refund_amount,
      item_status,
      sale_price - discount_amount AS net_revenue,
      MEASURE(SUM(net_revenue)) AS gross_revenue,
      MEASURE(SUM(cost_of_goods)) AS total_cogs,
      MEASURE(SUM(refund_amount)) AS total_refunds
    ),

  -- 6. Products Node Table
  `eRetail_marketing.products` AS products
    KEY (product_id)
    LABEL products PROPERTIES (
      product_id,
      product_name,
      category,
      cost_of_goods,
      retail_price
    )
)
EDGE TABLES (
  -- Touchpoint -> Campaign (GENERATED_BY)
  `eRetail_marketing.touchpoints` AS generated_by
    KEY (touchpoint_id)
    SOURCE KEY (touchpoint_id)
      REFERENCES touchpoints (touchpoint_id)
    DESTINATION KEY (campaign_id)
      REFERENCES campaigns (campaign_id)
    LABEL GENERATED_BY NO PROPERTIES,

  -- Customer -> Touchpoint (ENGAGED_WITH)
  `eRetail_marketing.touchpoints` AS engaged_with
    KEY (touchpoint_id)
    SOURCE KEY (customer_id)
      REFERENCES customers (customer_id)
    DESTINATION KEY (touchpoint_id)
      REFERENCES touchpoints (touchpoint_id)
    LABEL ENGAGED_WITH NO PROPERTIES,

  -- Touchpoint -> Order (INFLUENCED: The Attribution Bridge)
  `eRetail_marketing.edge_influenced` AS edge_influenced
    KEY (touchpoint_id, order_id)
    SOURCE KEY (touchpoint_id)
      REFERENCES touchpoints (touchpoint_id)
    DESTINATION KEY (order_id)
      REFERENCES orders (order_id)
    LABEL INFLUENCED PROPERTIES (
      attribution_weight,
      touchpoint_rank,
      days_to_convert
    ),

  -- Order Item -> Order (BELONGS_TO)
  `eRetail_marketing.order_items` AS item_belongs_to_order
    KEY (order_item_id)
    SOURCE KEY (order_item_id)
      REFERENCES order_items (order_item_id)
    DESTINATION KEY (order_id)
      REFERENCES orders (order_id)
    LABEL BELONGS_TO NO PROPERTIES,

  -- Order Item -> Product (IS_PRODUCT)
  `eRetail_marketing.order_items` AS item_is_product
    KEY (order_item_id)
    SOURCE KEY (order_item_id)
      REFERENCES order_items (order_item_id)
    DESTINATION KEY (product_id)
      REFERENCES products (product_id)
    LABEL IS_PRODUCT NO PROPERTIES
);
