CREATE SCHEMA IF NOT EXISTS `eRetail_marketing`;

-- 1. Campaigns Table
CREATE OR REPLACE TABLE `eRetail_marketing.campaigns` (
  campaign_id STRING,
  campaign_name STRING,
  channel STRING,
  weekly_budget NUMERIC,
  target_roas FLOAT64,
  PRIMARY KEY (campaign_id) NOT ENFORCED
);

-- 2. Products Table
CREATE OR REPLACE TABLE `eRetail_marketing.products` (
  product_id STRING,
  product_name STRING,
  category STRING,
  cost_of_goods NUMERIC,
  retail_price NUMERIC,
  PRIMARY KEY (product_id) NOT ENFORCED
);

-- 3. Customers Table
CREATE OR REPLACE TABLE `eRetail_marketing.customers` (
  customer_id STRING,
  first_seen_date DATE,
  customer_segment STRING,
  PRIMARY KEY (customer_id) NOT ENFORCED
);

-- 4. Touchpoints Table
CREATE OR REPLACE TABLE `eRetail_marketing.touchpoints` (
  touchpoint_id STRING,
  customer_id STRING,
  campaign_id STRING,
  touchpoint_timestamp TIMESTAMP,
  cpc_cost NUMERIC,
  device_type STRING,
  PRIMARY KEY (touchpoint_id) NOT ENFORCED,
  FOREIGN KEY (customer_id) REFERENCES `eRetail_marketing.customers`(customer_id) NOT ENFORCED,
  FOREIGN KEY (campaign_id) REFERENCES `eRetail_marketing.campaigns`(campaign_id) NOT ENFORCED
);

-- 5. Orders Table
CREATE OR REPLACE TABLE `eRetail_marketing.orders` (
  order_id STRING,
  customer_id STRING,
  order_timestamp TIMESTAMP,
  order_status STRING,
  shipping_cost NUMERIC,
  PRIMARY KEY (order_id) NOT ENFORCED,
  FOREIGN KEY (customer_id) REFERENCES `eRetail_marketing.customers`(customer_id) NOT ENFORCED
);

-- 6. Order Items Table
CREATE OR REPLACE TABLE `eRetail_marketing.order_items` (
  order_item_id STRING,
  order_id STRING,
  product_id STRING,
  sale_price NUMERIC,
  discount_amount NUMERIC,
  refund_amount NUMERIC,
  cost_of_goods NUMERIC,
  item_status STRING,
  PRIMARY KEY (order_item_id) NOT ENFORCED,
  FOREIGN KEY (order_id) REFERENCES `eRetail_marketing.orders`(order_id) NOT ENFORCED,
  FOREIGN KEY (product_id) REFERENCES `eRetail_marketing.products`(product_id) NOT ENFORCED
);

-- 7. Edge Influenced (Attribution Mapping Table)
CREATE OR REPLACE TABLE `eRetail_marketing.edge_influenced` (
  touchpoint_id STRING,
  order_id STRING,
  attribution_weight FLOAT64,
  touchpoint_rank INT64,
  days_to_convert FLOAT64,
  PRIMARY KEY (touchpoint_id, order_id) NOT ENFORCED,
  FOREIGN KEY (touchpoint_id) REFERENCES `eRetail_marketing.touchpoints`(touchpoint_id) NOT ENFORCED,
  FOREIGN KEY (order_id) REFERENCES `eRetail_marketing.orders`(order_id) NOT ENFORCED
);
