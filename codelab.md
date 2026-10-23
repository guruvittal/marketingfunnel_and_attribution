summary: Google Developers Codelab for Marketing Attribution and ROAS Graph using BigQuery Graph, Semantic Measures, and Conversational Analytics
id: marketing-attribution-bigquery-graph
categories: bigquery,graph,analytics,genai
environments: web
status: Published
feedback link: https://github.com/guruvittal/marketingfunnel_and_attribution/issues
analytics account: UA-00000000-1

# Marketing Attribution with BigQuery Graph & Measures

## 1. Overview & Business Context
Duration: 5

Welcome to the **Marketing Attribution with BigQuery Graph & Measures** codelab!

Modern digital marketing teams operate across a fragmented maze of paid search, social prospecting, retargeting, email nurturing, and video awareness. CMOs, VP of Growth, and Analytics leaders are constantly challenged by fundamental questions:
* *Which marketing campaigns are truly driving high-margin revenue versus burning ad spend?*
* *How do different attribution models (First-Touch, Last-Touch, Linear) reshape channel performance?*
* *How can we report macro campaign budgets alongside micro web interaction touchpoints without Cartesian fan-out bugs?*

### The Challenge: Cartesian Fan-Out & Multi-Grain Aggregation
In traditional relational data warehouses, joining upstream marketing budgets (coarse grain: 1 row per campaign) with downstream web events and purchase line items (fine leaf grain: millions of rows) causes a **Cartesian fan-out explosion**. Upstream budget numbers get duplicated across every leaf line item, turning a \$60,000 budget into a fictitious \$66.7 Billion!

Analytics engineers typically resort to messy subqueries, CTEs, or dangerous `ANY_VALUE()` workarounds that obscure data integrity and hurt query performance.

### The Solution: BigQuery Graph & Semantic Measures
Google BigQuery solves this architectural challenge natively:
1. **Property Graph Model (`CREATE PROPERTY GRAPH`)**: Unifies marketing campaigns, web touchpoints, customer profiles, orders, order items, and product catalogs into a single topological mesh.
2. **Semantic `MEASURE`s**: Encapsulates aggregation formulas (e.g., `MEASURE(SUM(total_budget))`, `MEASURE(SUM(cpc_cost))`, `MEASURE(COUNT(id))`) directly inside the graph schema at each entity's native grain.
3. **`GRAPH_EXPAND` & `AGG()`**: Enables multi-grain reporting across upstream and downstream nodes in a single declarative query without row duplication.
4. **`GRAPH_TABLE` & ISO GQL**: Enables expressive multi-hop graph path traversals to connect touchpoints across 4 hops to product cost-of-goods-sold (COGS) and compute True Gross Profit.
5. **Zero-Copy Public Data**: Built on top of Google Cloud's public `thelook_ecommerce` dataset (`bigquery-public-data.thelook_ecommerce.*`), requiring **zero data approvals or manual file ingestion**.

---

## 2. Prerequisites & Environment Setup
Duration: 5

### Google Cloud Project Requirements
To complete this codelab, you will need:
* A Google Cloud Project with billing enabled.
* An active BigQuery Enterprise Edition reservation (required for BigQuery Property Graph and Semantic Measures).
* BigQuery Admin and Service Usage Admin IAM permissions.

### Set Environment Variables
Open Cloud Shell and set your project and region environment variables:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="US"
export RESERVATION_NAME="graph-enterprise-reservation"

echo "Project ID: ${PROJECT_ID}"
echo "Region:     ${REGION}"
```

### Enable Required Google Cloud APIs
Ensure the BigQuery and BigQuery Reservation APIs are enabled:

```bash
gcloud services enable \
  bigquery.googleapis.com \
  bigqueryreservation.googleapis.com \
  --project=${PROJECT_ID}
```

### Create BigQuery Enterprise Reservation & Assignment
BigQuery Property Graph and Semantic Measures are Enterprise Edition features. Create a lightweight reservation with 0 baseline slots and up to 100 autoscaling slots:

```bash
# 1. Create BigQuery Enterprise reservation (0 baseline, 100 max autoscaling slots)
bq mk --reservation \
  --project_id=${PROJECT_ID} \
  --location=${REGION} \
  --edition=ENTERPRISE \
  --slots=0 \
  --autoscale_max_slots=100 \
  ${RESERVATION_NAME}

# 2. Assign your project to the reservation for query execution
bq mk --reservation_assignment \
  --project_id=${PROJECT_ID} \
  --location=${REGION} \
  --reservation_name=${RESERVATION_NAME} \
  --job_type=QUERY \
  --assignee_id=${PROJECT_ID} \
  --assignee_type=PROJECT
```

---

## 3. Creating the Schema and Tables
Duration: 10

### Architecture Diagram

The diagram below illustrates our unified enterprise property graph topology:

```
[campaigns] <──(generated_by)── [touchpoints] <──(engaged_with)── [users]
                                       │
                                  (influenced)
                                       ▼
[products] <──(is_product)── [order_items] ──(belongs_to)──> [orders]
```

### Zero-Copy Architecture via Public Dataset
Instead of downloading gigabytes of CSV files or needing special data approval, we reference Google's pre-approved public dataset directly:
* **Node Tables**:
  * `bigquery-public-data.thelook_ecommerce.users`: Registered e-commerce shoppers.
  * `bigquery-public-data.thelook_ecommerce.orders`: Completed e-commerce purchases.
  * `bigquery-public-data.thelook_ecommerce.order_items`: Individual purchased items with transaction prices.
  * `bigquery-public-data.thelook_ecommerce.products`: Merchandise catalog with cost of goods sold (COGS) and retail prices.
* **Marketing Reference & Touchpoint Views** (in your local `thelook_graph` dataset):
  * `marketing_campaigns`: Upstream campaign budgets, channel groupings, and target ROAS goals.
  * `touchpoints`: Enriched view over public `events`, adding specific Q4 ad campaign tags and benchmark CPC costs.
  * `edge_influenced`: Normalized attribution weights connecting touchpoints to orders within a 30-day conversion window.

### Create Dataset and Reference Tables DDL
Execute the following SQL in BigQuery Studio (or run [`sql/01_setup_schema_and_graph.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/01_setup_schema_and_graph.sql)):

```sql
-- 1. Create Graph Workspace Dataset
CREATE SCHEMA IF NOT EXISTS `thelook_graph`
OPTIONS (
  location = 'US',
  description = 'Marketing Attribution & ROAS Graph using thelook_ecommerce'
);

-- 2. Create Marketing Campaigns Reference View
CREATE OR REPLACE VIEW `thelook_graph.marketing_campaigns` AS
SELECT 'Paid Search' AS channel, 'Q4_Search_Generic_Audio' AS campaign_name, 1500000.0 AS total_budget, 4.0 AS target_roas UNION ALL
SELECT 'Paid Search', 'Q4_Search_Brand_Electronics', 1100000.0, 5.0 UNION ALL
SELECT 'Paid Social', 'Q4_Meta_IG_Retargeting', 250000.0, 4.5 UNION ALL
SELECT 'Video', 'Q4_YouTube_Video_Awareness', 220000.0, 2.5 UNION ALL
SELECT 'Paid Social', 'Q4_TikTok_Prospecting_GenZ', 150000.0, 3.0 UNION ALL
SELECT 'Email Marketing', 'Q4_Email_Cart_Abandonment', 75000.0, 10.0 UNION ALL
SELECT 'Email Marketing', 'Q4_Email_VIP_Weekly_Drop', 60000.0, 8.0 UNION ALL
SELECT 'Organic', 'Organic_Search_SEO', 25000.0, 15.0;

-- 3. Create Enriched Touchpoints View (over public web events)
CREATE OR REPLACE VIEW `thelook_graph.touchpoints` AS
SELECT
  e.id AS touchpoint_id,
  e.user_id,
  e.session_id,
  e.created_at,
  e.event_type,
  e.browser,
  e.traffic_source,
  CASE
    WHEN e.traffic_source = 'Adwords' AND MOD(e.id, 2) = 0 THEN 'Q4_Search_Generic_Audio'
    WHEN e.traffic_source = 'Adwords' THEN 'Q4_Search_Brand_Electronics'
    WHEN e.traffic_source = 'Facebook' AND MOD(e.id, 2) = 0 THEN 'Q4_Meta_IG_Retargeting'
    WHEN e.traffic_source = 'Facebook' THEN 'Q4_TikTok_Prospecting_GenZ'
    WHEN e.traffic_source = 'YouTube' THEN 'Q4_YouTube_Video_Awareness'
    WHEN e.traffic_source = 'Email' AND MOD(e.id, 2) = 0 THEN 'Q4_Email_Cart_Abandonment'
    WHEN e.traffic_source = 'Email' THEN 'Q4_Email_VIP_Weekly_Drop'
    ELSE 'Organic_Search_SEO'
  END AS campaign_name,
  CASE
    WHEN e.traffic_source = 'Adwords' THEN 'Paid Search'
    WHEN e.traffic_source = 'Facebook' THEN 'Paid Social'
    WHEN e.traffic_source = 'YouTube' THEN 'Video'
    WHEN e.traffic_source = 'Email' THEN 'Email Marketing'
    ELSE 'Organic'
  END AS channel,
  CASE
    WHEN e.traffic_source = 'Adwords' AND MOD(e.id, 2) = 0 THEN 3.78
    WHEN e.traffic_source = 'Adwords' THEN 2.64
    WHEN e.traffic_source = 'Facebook' AND MOD(e.id, 2) = 0 THEN 1.85
    WHEN e.traffic_source = 'Facebook' THEN 0.99
    WHEN e.traffic_source = 'YouTube' THEN 0.85
    WHEN e.traffic_source = 'Email' AND MOD(e.id, 2) = 0 THEN 0.12
    WHEN e.traffic_source = 'Email' THEN 0.10
    ELSE 0.00
  END AS cpc_cost
FROM `bigquery-public-data.thelook_ecommerce.events` e;

-- 4. Create Attributed Edge Table: edge_influenced
CREATE OR REPLACE TABLE `thelook_graph.edge_influenced` AS
WITH ranked_touchpoints AS (
  SELECT
    t.touchpoint_id,
    o.order_id,
    t.campaign_name,
    t.channel,
    t.cpc_cost,
    t.created_at AS event_timestamp,
    o.created_at AS order_timestamp,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY t.created_at ASC) AS touchpoint_asc,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY t.created_at DESC) AS touchpoint_desc,
    COUNT(*) OVER (PARTITION BY o.order_id) AS total_touchpoints
  FROM `bigquery-public-data.thelook_ecommerce.orders` o
  JOIN `thelook_graph.touchpoints` t
    ON o.user_id = t.user_id 
   AND t.created_at <= o.created_at
   AND t.created_at >= TIMESTAMP_SUB(o.created_at, INTERVAL 30 DAY)
  WHERE o.status NOT IN ('Cancelled', 'Returned')
)
SELECT
  touchpoint_id,
  order_id,
  campaign_name,
  channel,
  cpc_cost,
  touchpoint_asc AS touchpoint_rank,
  total_touchpoints,
  ROUND(TIMESTAMP_DIFF(order_timestamp, event_timestamp, HOUR) / 24.0, 1) AS days_to_convert,
  IF(touchpoint_asc = 1, 1.0, 0.0) AS first_touch_weight,
  IF(touchpoint_desc = 1, 1.0, 0.0) AS last_touch_weight,
  ROUND(1.0 / total_touchpoints, 6) AS linear_weight
FROM ranked_touchpoints;
```

---

## 4. Declaring the Unified Property Graph with Semantic Measures
Duration: 10

### Unified Property Graph DDL
Execute the following DDL statement in BigQuery Studio to create `thelook_graph.eCommerce_Integrated`:

```sql
CREATE OR REPLACE PROPERTY GRAPH `thelook_graph.eCommerce_Integrated`
NODE TABLES (
  -- 1. Marketing Campaigns Node Table
  `thelook_graph.marketing_campaigns` AS campaigns
    KEY (campaign_name)
    LABEL campaigns PROPERTIES (
      campaign_name,
      channel,
      total_budget,
      target_roas,
      MEASURE(SUM(total_budget)) AS total_campaign_budget
    ),

  -- 2. Marketing Touchpoints Node Table
  `thelook_graph.touchpoints` AS touchpoints
    KEY (touchpoint_id)
    LABEL touchpoints PROPERTIES (
      touchpoint_id,
      user_id,
      session_id,
      campaign_name,
      channel,
      cpc_cost,
      event_type,
      browser,
      created_at,
      MEASURE(SUM(cpc_cost)) AS total_ad_spend,
      MEASURE(COUNT(touchpoint_id)) AS total_clicks,
      MEASURE(COUNT(DISTINCT user_id)) AS unique_reach
    ),

  -- 3. Users Node Table
  `bigquery-public-data.thelook_ecommerce.users` AS users
    KEY (id)
    LABEL users PROPERTIES (
      id,
      first_name,
      last_name,
      email,
      age,
      gender,
      country,
      traffic_source,
      created_at,
      MEASURE(COUNT(DISTINCT id)) AS total_users
    ),

  -- 4. Orders Node Table
  `bigquery-public-data.thelook_ecommerce.orders` AS orders
    KEY (order_id)
    LABEL orders PROPERTIES (
      order_id,
      user_id,
      status,
      created_at,
      num_of_item,
      MEASURE(COUNT(order_id)) AS total_orders
    ),

  -- 5. Order Items Node Table (Line-Item Financial Leaf Grain)
  `bigquery-public-data.thelook_ecommerce.order_items` AS order_items
    KEY (id)
    LABEL order_items PROPERTIES (
      id,
      order_id,
      user_id,
      product_id,
      sale_price,
      status,
      created_at,
      MEASURE(SUM(sale_price)) AS gross_revenue,
      MEASURE(COUNT(id)) AS total_items_sold
    ),

  -- 6. Products Catalog Node Table
  `bigquery-public-data.thelook_ecommerce.products` AS products
    KEY (id)
    LABEL products PROPERTIES (
      id,
      cost,
      category,
      name,
      brand,
      retail_price,
      department,
      MEASURE(AVG(cost)) AS avg_cost,
      MEASURE(AVG(retail_price)) AS avg_retail_price
    )
)
EDGE TABLES (
  -- Touchpoint -> Campaign (GENERATED_BY)
  `thelook_graph.touchpoints` AS touchpoint_campaign
    KEY (touchpoint_id)
    SOURCE KEY (touchpoint_id) REFERENCES touchpoints (touchpoint_id)
    DESTINATION KEY (campaign_name) REFERENCES campaigns (campaign_name)
    LABEL GENERATED_BY NO PROPERTIES,

  -- User -> Touchpoint (ENGAGED_WITH)
  `thelook_graph.touchpoints` AS user_touchpoint
    KEY (touchpoint_id)
    SOURCE KEY (user_id) REFERENCES users (id)
    DESTINATION KEY (touchpoint_id) REFERENCES touchpoints (touchpoint_id)
    LABEL ENGAGED_WITH NO PROPERTIES,

  -- Touchpoint -> Order (INFLUENCED)
  `thelook_graph.edge_influenced` AS edge_influenced
    KEY (touchpoint_id, order_id)
    SOURCE KEY (touchpoint_id) REFERENCES touchpoints (touchpoint_id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL INFLUENCED PROPERTIES (
      campaign_name,
      channel,
      cpc_cost,
      touchpoint_rank,
      total_touchpoints,
      days_to_convert,
      first_touch_weight,
      last_touch_weight,
      linear_weight
    ),

  -- Order Item -> Order (BELONGS_TO)
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_order
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL BELONGS_TO NO PROPERTIES,

  -- Order Item -> Product (IS_PRODUCT)
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_product
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (product_id) REFERENCES products (id)
    LABEL IS_PRODUCT NO PROPERTIES
);
```

---

## 5. Introspecting Semantic Measures via INFORMATION_SCHEMA
Duration: 5

BigQuery Property Graphs surface their declared semantic measures in `INFORMATION_SCHEMA.PROPERTY_GRAPHS`. We can introspect these dynamically:

```sql
SELECT
  JSON_VALUE(node_table_json, "$.name") AS node_table_name,
  JSON_VALUE(prop_json, "$.name") AS measure_name,
  JSON_VALUE(prop_json, "$.expression") AS measure_expression,
  CONCAT("MEASURE<", JSON_VALUE(prop_json, "$.dataType.typeKind"), ">") AS measure_type
FROM `thelook_graph.INFORMATION_SCHEMA.PROPERTY_GRAPHS`,
UNNEST(JSON_EXTRACT_ARRAY(property_graph_metadata_json, "$.nodeTables")) AS node_table_json,
UNNEST(JSON_EXTRACT_ARRAY(node_table_json, "$.labelAndProperties[0].properties")) AS prop_json
WHERE JSON_VALUE(prop_json, "$.expressionKind") = "MEASURE"
ORDER BY node_table_name, measure_name;
```

### Query Output

| node_table_name | measure_name | measure_expression | measure_type |
| :--- | :--- | :--- | :--- |
| `campaigns` | `total_campaign_budget` | `SUM(total_budget)` | `MEASURE<FLOAT64>` |
| `order_items` | `gross_revenue` | `SUM(sale_price)` | `MEASURE<FLOAT64>` |
| `order_items` | `total_items_sold` | `COUNT(id)` | `MEASURE<INT64>` |
| `orders` | `total_orders` | `COUNT(order_id)` | `MEASURE<INT64>` |
| `products` | `avg_cost` | `AVG(cost)` | `MEASURE<FLOAT64>` |
| `products` | `avg_retail_price` | `AVG(retail_price)` | `MEASURE<FLOAT64>` |
| `touchpoints` | `total_ad_spend` | `SUM(cpc_cost)` | `MEASURE<FLOAT64>` |
| `touchpoints` | `total_clicks` | `COUNT(touchpoint_id)` | `MEASURE<INT64>` |
| `touchpoints` | `unique_reach` | `COUNT(DISTINCT user_id)` | `MEASURE<INT64>` |
| `users` | `total_users` | `COUNT(DISTINCT id)` | `MEASURE<INT64>` |

---

## 6. Benchmark: Demonstrating the Cartesian Fan-Out Multiplier
Duration: 5

To understand why BigQuery Graph with Semantic Measures is an essential architecture, let's run a standard relational SQL join combining marketing campaigns with leaf-level order items:

```sql
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
```

### Benchmark Results

| channel | campaign_name | actual_campaign_budget | joined_rows | blown_up_budget | budget_multiplication_factor | total_gross_sales |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Email Marketing** | `Q4_Email_VIP_Weekly_Drop` | \$60,000 | 1,111,635 | **\$66,698,100,000** | **1,111,635x** | \$66,431,873.96 |
| **Email Marketing** | `Q4_Email_Cart_Abandonment` | \$75,000 | 1,111,086 | **\$83,331,450,000** | **1,111,086x** | \$66,390,491.05 |
| **Paid Search** | `Q4_Search_Generic_Audio` | \$1,500,000 | 733,982 | **\$1,100,973,000,000** | **733,982x** | \$43,597,076.89 |
| **Paid Search** | `Q4_Search_Brand_Electronics` | \$1,100,000 | 733,939 | **\$807,332,900,000** | **733,939x** | \$43,609,883.79 |
| **Video** | `Q4_YouTube_Video_Awareness` | \$220,000 | 490,451 | **\$107,899,220,000** | **490,451x** | \$29,053,242.49 |
| **Organic** | `Organic_Search_SEO` | \$25,000 | 245,179 | **\$6,129,475,000** | **245,179x** | \$14,533,090.41 |
| **Paid Social** | `Q4_Meta_IG_Retargeting` | \$250,000 | 244,183 | **\$61,045,750,000** | **244,183x** | \$14,675,700.48 |
| **Paid Social** | `Q4_TikTok_Prospecting_GenZ` | \$150,000 | 244,056 | **\$36,608,400,000** | **244,056x** | \$14,654,839.55 |

> [!CAUTION]
> Notice how Email VIP's \$60,000 budget is multiplied over **1.1 million times** into \$66.7 Billion! This error happens because upstream rows are duplicated across downstream paths.

---

## 7. Use Case 1: Multi-Touch Marketing Attribution Comparison
Duration: 8

Using `GRAPH_TABLE`, we compare First-Touch, Last-Touch, and Linear Attribution models across our ad campaigns:

```sql
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
```

### Query Output

| campaign_name | channel | first_touch_revenue | last_touch_revenue | linear_revenue |
| :--- | :--- | :--- | :--- | :--- |
| `Q4_Email_VIP_Weekly_Drop` | Email Marketing | \$1,845,315.77 | \$1,863,925.04 | **\$1,843,829.27** |
| `Q4_Email_Cart_Abandonment` | Email Marketing | \$1,836,227.46 | \$1,832,522.48 | **\$1,843,706.49** |
| `Q4_Search_Brand_Electronics` | Paid Search | \$1,204,988.16 | \$1,196,742.64 | **\$1,202,490.39** |
| `Q4_Search_Generic_Audio` | Paid Search | \$1,206,705.37 | \$1,212,892.37 | **\$1,201,800.30** |
| `Q4_YouTube_Video_Awareness` | Video | \$786,474.26 | \$789,685.75 | **\$791,187.97** |
| `Organic_Search_SEO` | Organic | \$414,224.82 | \$405,306.72 | **\$409,566.57** |
| `Q4_Meta_IG_Retargeting` | Paid Social | \$410,408.31 | \$402,723.63 | **\$401,409.26** |
| `Q4_TikTok_Prospecting_GenZ` | Paid Social | \$389,434.35 | \$389,979.87 | **\$399,775.09** |

---

## 8. Use Case 2: 4-Hop Campaign Profitability & Gross Margin %
Duration: 8

Attributed revenue alone doesn't tell us if campaigns are profitable. By traversing 4 hops from touchpoint to product catalog, we deduct product COGS to compute True Gross Profit:

```sql
SELECT
  campaign_name,
  channel,
  ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
  ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
  ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit,
  ROUND(SAFE_DIVIDE(SUM((sale_price - cost) * linear_weight), SUM(sale_price * linear_weight)) * 100, 2) AS gross_margin_pct
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (t:touchpoints)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
  COLUMNS (
    t.campaign_name AS campaign_name,
    t.channel AS channel,
    oi.sale_price,
    p.cost,
    i.linear_weight
  )
)
GROUP BY campaign_name, channel
ORDER BY gross_profit DESC;
```

### Query Output

| campaign_name | channel | attributed_revenue | attributed_cogs | gross_profit | gross_margin_pct |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Q4_Email_Cart_Abandonment` | Email Marketing | \$1,843,706.49 | \$885,737.40 | **\$957,969.09** | 51.96% |
| `Q4_Email_VIP_Weekly_Drop` | Email Marketing | \$1,843,829.27 | \$885,979.08 | **\$957,850.19** | 51.95% |
| `Q4_Search_Brand_Electronics` | Paid Search | \$1,202,490.39 | \$578,564.40 | **\$623,926.00** | 51.89% |
| `Q4_Search_Generic_Audio` | Paid Search | \$1,201,800.30 | \$578,539.58 | **\$623,260.72** | 51.86% |
| `Q4_YouTube_Video_Awareness` | Video | \$791,187.97 | \$380,320.71 | **\$410,867.26** | 51.93% |
| `Organic_Search_SEO` | Organic | \$409,566.57 | \$196,346.08 | **\$213,220.49** | 52.06% |
| `Q4_Meta_IG_Retargeting` | Paid Social | \$401,409.26 | \$193,276.98 | **\$208,132.28** | 51.85% |
| `Q4_TikTok_Prospecting_GenZ` | Paid Social | \$399,775.09 | \$192,436.82 | **\$207,338.27** | 51.86% |

---

## 9. Use Case 3: Multi-Grain Reporting with GRAPH_EXPAND & Measures
Duration: 8

Using `GRAPH_EXPAND` with declared `MEASURE`s and `AGG()`, we project macro budgets and micro interaction volumes in a single query without Cartesian explosion:

```sql
SELECT
  campaigns_channel AS channel,
  campaigns_campaign_name AS campaign_name,
  AGG(campaigns_total_campaign_budget) AS total_budget,
  AGG(touchpoints_total_clicks) AS total_clicks,
  AGG(touchpoints_unique_reach) AS unique_reach,
  ROUND(AGG(touchpoints_total_ad_spend), 2) AS total_ad_spend,
  ROUND(AGG(campaigns_total_campaign_budget) - AGG(touchpoints_total_ad_spend), 2) AS remaining_budget,
  ROUND(AGG(touchpoints_total_ad_spend) / NULLIF(AGG(touchpoints_total_clicks), 0), 2) AS effective_avg_cpc
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "touchpoints")
GROUP BY channel, campaign_name
ORDER BY total_ad_spend DESC;
```

### Query Output

| channel | campaign_name | total_budget | total_clicks | unique_reach | total_ad_spend | remaining_budget | effective_avg_cpc |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Paid Search** | `Q4_Search_Generic_Audio` | \$1,500,000 | 362,497 | 39,564 | \$1,370,238.66 | \$129,761.34 | **\$3.78** |
| **Paid Search** | `Q4_Search_Brand_Electronics` | \$1,100,000 | 362,605 | 39,564 | \$957,277.20 | \$142,722.80 | **\$2.64** |
| **Paid Social** | `Q4_Meta_IG_Retargeting` | \$250,000 | 120,597 | 16,039 | \$223,104.45 | \$26,895.55 | **\$1.85** |
| **Video** | `Q4_YouTube_Video_Awareness` | \$220,000 | 241,729 | 16,114 | \$205,469.65 | \$14,530.35 | **\$0.85** |
| **Paid Social** | `Q4_TikTok_Prospecting_GenZ` | \$150,000 | 120,740 | 16,039 | \$119,532.60 | \$30,467.40 | **\$0.99** |
| **Email Marketing** | `Q4_Email_Cart_Abandonment` | \$75,000 | 546,038 | 52,216 | \$65,524.56 | \$9,475.44 | **\$0.12** |
| **Email Marketing** | `Q4_Email_VIP_Weekly_Drop` | \$60,000 | 545,691 | 52,216 | \$54,569.10 | \$5,430.90 | **\$0.10** |
| **Organic** | `Organic_Search_SEO` | \$25,000 | 121,058 | 8,550 | \$0.00 | \$25,000.00 | **\$0.00** |

---

## 10. Use Case 4: Customer Conversion Journey Mapping (ISO GQL)
Duration: 8

Using pure ISO GQL, we inspect the end-to-end touchpoint journey for customer Paul (`user_id = 65516`):

```sql
GRAPH `thelook_graph.eCommerce_Integrated`
MATCH (u:users)-[:ENGAGED_WITH]->(t:touchpoints)-[i:INFLUENCED]->(o:orders)
WHERE u.id = 65516
RETURN
  u.id AS user_id,
  u.first_name,
  t.campaign_name,
  t.channel,
  t.event_type,
  i.touchpoint_rank,
  i.linear_weight,
  o.order_id
ORDER BY o.order_id, i.touchpoint_rank
LIMIT 10;
```

### Query Output

| user_id | first_name | campaign_name | channel | event_type | touchpoint_rank | linear_weight | order_id |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 65516 | Paul | `Q4_Email_VIP_Weekly_Drop` | Email Marketing | department | 1 | 0.012658 | 81973 |
| 65516 | Paul | `Q4_Email_Cart_Abandonment` | Email Marketing | product | 2 | 0.012658 | 81973 |
| 65516 | Paul | `Q4_Email_VIP_Weekly_Drop` | Email Marketing | cart | 3 | 0.012658 | 81973 |
| 65516 | Paul | `Q4_Email_Cart_Abandonment` | Email Marketing | department | 4 | 0.012658 | 81973 |
| 65516 | Paul | `Q4_Email_VIP_Weekly_Drop` | Email Marketing | product | 5 | 0.012658 | 81973 |

---

## 11. Use Case 5: Unified Executive ROAS Scorecard (Dual-View CTE)
Duration: 8

We fuse `GRAPH_EXPAND` (safe budget, reach, and ad spend) with `GRAPH_TABLE` (attributed gross profit) into a single, cohesive GoogleSQL query:

```sql
WITH marketing_funnel AS (
  SELECT
    campaigns_channel AS channel,
    campaigns_campaign_name AS campaign_name,
    AGG(campaigns_total_campaign_budget) AS total_budget,
    AGG(touchpoints_total_clicks) AS total_clicks,
    AGG(touchpoints_unique_reach) AS unique_reach,
    ROUND(AGG(touchpoints_total_ad_spend), 2) AS total_ad_spend,
    ROUND(AGG(campaigns_total_campaign_budget) - AGG(touchpoints_total_ad_spend), 2) AS remaining_budget,
    ROUND(AGG(touchpoints_total_ad_spend) / NULLIF(AGG(touchpoints_total_clicks), 0), 2) AS effective_avg_cpc
  FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "touchpoints")
  GROUP BY channel, campaign_name
),

sales_attribution AS (
  SELECT
    campaign_name,
    ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
    ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
    ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit
  FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
    MATCH (t:touchpoints)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
    COLUMNS (
      t.campaign_name AS campaign_name,
      oi.sale_price,
      p.cost,
      i.linear_weight
    )
  )
  GROUP BY campaign_name
)

SELECT
  m.channel,
  m.campaign_name,
  m.total_budget,
  m.total_ad_spend,
  m.remaining_budget,
  m.effective_avg_cpc,
  s.attributed_revenue,
  s.gross_profit,
  ROUND(s.attributed_revenue / NULLIF(m.total_ad_spend, 0), 2) AS roas_on_spend,
  ROUND(s.attributed_revenue / NULLIF(m.total_budget, 0), 2) AS roas_on_budget,
  ROUND(SAFE_DIVIDE(s.gross_profit, s.attributed_revenue) * 100, 2) AS gross_margin_pct
FROM marketing_funnel m
JOIN sales_attribution s ON m.campaign_name = s.campaign_name
ORDER BY s.gross_profit DESC;
```

### Executive Scorecard Output

| channel | campaign_name | total_budget | total_ad_spend | remaining_budget | effective_avg_cpc | attributed_revenue | gross_profit | roas_on_spend | roas_on_budget | gross_margin_pct |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Email Marketing** | `Q4_Email_Cart_Abandonment` | \$75,000 | \$65,524.56 | \$9,475.44 | \$0.12 | \$1,843,706.49 | **\$957,969.09** | **28.14x** | **24.58x** | 51.96% |
| **Email Marketing** | `Q4_Email_VIP_Weekly_Drop` | \$60,000 | \$54,569.10 | \$5,430.90 | \$0.10 | \$1,843,829.27 | **\$957,850.19** | **33.79x** | **30.73x** | 51.95% |
| **Paid Search** | `Q4_Search_Brand_Electronics` | \$1,100,000 | \$957,277.20 | \$142,722.80 | \$2.64 | \$1,202,490.39 | **\$623,926.00** | **1.26x** | **1.09x** | 51.89% |
| **Paid Search** | `Q4_Search_Generic_Audio` | \$1,500,000 | \$1,370,238.66 | \$129,761.34 | \$3.78 | \$1,201,800.30 | **\$623,260.72** | **0.88x** | **0.80x** | 51.86% |
| **Video** | `Q4_YouTube_Video_Awareness` | \$220,000 | \$205,469.65 | \$14,530.35 | \$0.85 | \$791,187.97 | **\$410,867.26** | **3.85x** | **3.60x** | 51.93% |
| **Organic** | `Organic_Search_SEO` | \$25,000 | \$0.00 | \$25,000.00 | \$0.00 | \$409,566.57 | **\$213,220.49** | NULL | **16.38x** | 52.06% |
| **Paid Social** | `Q4_Meta_IG_Retargeting` | \$250,000 | \$223,104.45 | \$26,895.55 | \$1.85 | \$401,409.26 | **\$208,132.28** | **1.80x** | **1.61x** | 51.85% |
| **Paid Social** | `Q4_TikTok_Prospecting_GenZ` | \$150,000 | \$119,532.60 | \$30,467.40 | \$0.99 | \$399,775.09 | **\$207,338.27** | **3.34x** | **2.67x** | 51.86% |

---

## 12. Conversational Analytics: Gemini Enterprise Agent Setup
Duration: 10

By connecting BigQuery Studio's Conversational Analytics (CA) engine to Gemini Enterprise, business users can query this property graph conversationally.

### Deployment Walkthrough
1. In the Google Cloud Console, navigate to **BigQuery** > **Studio**.
2. Expand your project and dataset `thelook_graph`.
3. Select **Create Data Agent** (or open **Data Canvas** with Conversational Analytics enabled).
4. Configure agent details:
   * **Name**: `Marketing-Attribution-Agent`
   * **Description**: `Answers questions about marketing campaigns, ad spend, multi-touch attribution, and customer conversion journeys.`
5. Attach Property Graph `thelook_graph.eCommerce_Integrated`.
6. Click **Deploy to Gemini Enterprise**.

---

## 13. Decision Guide: SUM() vs. Relational JOIN vs. GRAPH_TABLE vs. GRAPH_EXPAND
Duration: 5

When should you use each query operator?

```
+───────────────────────────+───────────────────────────────────────────────────────────────+
| Tool / Operator           | When to Use                                                   |
+───────────────────────────+───────────────────────────────────────────────────────────────+
| Plain SQL SUM()           | Single un-joined tables at their native grain.                |
| Relational JOIN           | Flat 1-to-1 foreign key lookups without many-to-many fan-out. |
| GRAPH_TABLE               | Multi-hop paths, traversals, and leaf-grain attributions.    |
| GRAPH_EXPAND + AGG()      | Multi-grain reporting across coarse and fine nodes.          |
+───────────────────────────+───────────────────────────────────────────────────────────────+
```

### Upstream vs. Downstream Variables
* **Upstream**: Coarse, top-of-funnel entities (e.g. `total_budget` on `campaigns`; 1 row per campaign).
* **Downstream**: Fine, leaf-grain interactions (e.g. `touchpoints`, `order_items`; hundreds of thousands of rows).
* **The Golden Rule**: Never aggregate an upstream variable using plain `SUM()` across a multi-table join. Use `GRAPH_EXPAND` with declared `MEASURE`s instead!

---

## 14. Conclusion & Key Takeaways
Duration: 2

Congratulations! You have built a zero-copy enterprise Marketing Attribution and ROAS Graph using BigQuery Graph, Semantic Measures, and Conversational Analytics.

### What You Learned
* How to overlay a property graph on Google's public dataset (`thelook_ecommerce`) with zero approvals.
* How to eliminate the 1,111,635x Cartesian budget multiplication error using declared Semantic `MEASURE`s.
* How to compute First-Touch, Last-Touch, and Linear Attribution in `GRAPH_TABLE`.
* How to trace 4 hops to product COGS to measure True Gross Profit and Margin %.
* How to generate executive scorecards combining `GRAPH_EXPAND` and `GRAPH_TABLE` in a single query.
