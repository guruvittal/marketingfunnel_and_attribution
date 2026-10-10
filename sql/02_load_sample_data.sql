-- ============================================================================
-- Step 4: Loading Sample Marketing Attribution & ROAS Data
-- ============================================================================
-- This script loads the complete retail dataset into the 7 tables in `eRetail_marketing`:
--   • 8 Campaigns (Search, Social, Affiliate, Email)
--   • 8 Products across Audio, Accessories, Displays
--   • 1,000 Customers (VIP, Loyal, New)
--   • 5,000 Touchpoints across Mobile & Desktop
--   • 800 Orders & 1,544 Order Items
--   • 1,728 Influenced Attribution Edges
--
-- Data is loaded directly from the public Google Cloud Storage bucket
-- `gs://marketing_attribution/data/*.csv` using BigQuery SQL LOAD DATA.
-- ============================================================================

-- 1. Load Campaigns
LOAD DATA OVERWRITE `eRetail_marketing.campaigns`
(
  campaign_id STRING,
  campaign_name STRING,
  channel STRING,
  weekly_budget NUMERIC,
  target_roas FLOAT64
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/campaigns.csv'],
  skip_leading_rows = 1
);

-- 2. Load Products Catalog
LOAD DATA OVERWRITE `eRetail_marketing.products`
(
  product_id STRING,
  product_name STRING,
  category STRING,
  cost_of_goods NUMERIC,
  retail_price NUMERIC
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/products.csv'],
  skip_leading_rows = 1
);

-- 3. Load Customers
LOAD DATA OVERWRITE `eRetail_marketing.customers`
(
  customer_id STRING,
  first_seen_date DATE,
  customer_segment STRING
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/customers.csv'],
  skip_leading_rows = 1
);

-- 4. Load Touchpoints (Ad Clicks & Digital Interactions)
LOAD DATA OVERWRITE `eRetail_marketing.touchpoints`
(
  touchpoint_id STRING,
  customer_id STRING,
  campaign_id STRING,
  touchpoint_timestamp TIMESTAMP,
  cpc_cost NUMERIC,
  device_type STRING
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/touchpoints.csv'],
  skip_leading_rows = 1
);

-- 5. Load Orders (E-commerce Transactions)
LOAD DATA OVERWRITE `eRetail_marketing.orders`
(
  order_id STRING,
  customer_id STRING,
  order_timestamp TIMESTAMP,
  order_status STRING,
  shipping_cost NUMERIC
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/orders.csv'],
  skip_leading_rows = 1
);

-- 6. Load Order Items (Transaction Line Items)
LOAD DATA OVERWRITE `eRetail_marketing.order_items`
(
  order_item_id STRING,
  order_id STRING,
  product_id STRING,
  sale_price NUMERIC,
  discount_amount NUMERIC,
  refund_amount NUMERIC,
  cost_of_goods NUMERIC,
  item_status STRING
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/order_items.csv'],
  skip_leading_rows = 1
);

-- 7. Load Influenced Edge (Attribution Weights & Conversion Paths)
LOAD DATA OVERWRITE `eRetail_marketing.edge_influenced`
(
  touchpoint_id STRING,
  order_id STRING,
  attribution_weight FLOAT64,
  touchpoint_rank INT64,
  days_to_convert FLOAT64
)
FROM FILES (
  format = 'CSV',
  uris = ['gs://marketing_attribution/data/edge_influenced.csv'],
  skip_leading_rows = 1
);
