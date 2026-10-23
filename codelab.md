# Marketing Attribution with BigQuery Graph & Measures

## 1. Introduction
Duration: 5

Measuring marketing return on ad spend (ROAS) and multi-touch customer attribution across modern e-commerce channels is notoriously difficult. Customer journeys are non-linear: a shopper might discover a brand through an Adwords search ad, browse products from an email newsletter, get retargeted on Facebook, and finally convert after clicking a YouTube video.

### Traditional Relational vs. BigQuery Graph

In traditional relational databases (like standard SQL data warehouses), modeling customer attribution requires joining disparate tables with varying cardinalities (Campaigns ➔ Events ➔ Orders ➔ Line Items ➔ Products). This leads to two critical problems:
1. **The Cartesian Join Explosion (Double Counting)**: Joining upstream marketing budgets (1 row per channel) to downstream order line items (hundreds of thousands of rows) multiplies the budget by the number of downstream rows. An email budget of **$10,000** balloons into **$4.32 Billion**!
2. **Complex, Fragile SQL**: Multi-hop path analysis requires deeply nested CTEs, recursive queries, or heavy dimensional preprocessing pipelines that duplicate storage and introduce synchronization latency.

**Google Cloud BigQuery** introduces two revolutionary capabilities to solve this natively:
* **BigQuery Property Graph**: Allows you to define graph models (nodes and edges) directly over existing BigQuery tables without moving, transforming, or duplicating data (**Zero-Copy Architecture**). You can query graph paths using ISO/IEC GQL (Graph Query Language) syntax and GoogleSQL's `GRAPH_TABLE` operator.
* **Semantic Measures (`MEASURE(...)`)**: Embeds business aggregation formulas directly into graph nodes. Combined with the **`GRAPH_EXPAND`** table-valued function, BigQuery automatically evaluates metrics at their correct entity grain, completely eliminating the Cartesian join explosion!

In this codelab, we use Google's official, pre-approved public dataset **`bigquery-public-data.thelook_ecommerce`** (backed by Cloud Storage snapshot `gs://sample-data-and-media/thelook_dataset_snapshot/`). This eliminates any data approval roadblocks, requires zero custom CSV downloads, and works out of the box in your Google Cloud project.

### 🎯 Core Learning Objectives & Milestones

In this hands-on lab, you will achieve the following key milestones:

```
[1. Setup & Schema] ──> [2. Property Graph & Measures] ──> [3. Fan-Out Benchmark] ──> [4. Attribution & ROAS] ──> [5. Gemini Agent]
```

1. **Deploy Zero-Copy Property Graph Modeling**: Create a unified enterprise property graph (`eCommerce_Integrated`) mapping directly over Google's public e-commerce tables.
2. **Eliminate Cartesian Fan-Out**: Contrast naive relational SQL joins (which multiply budgets by 432,000x) with BigQuery declared `MEASURE`s and `GRAPH_EXPAND`.
3. **Multi-Touch Marketing Attribution**: Compare First-Touch, Last-Touch, and Linear Attribution models using `GRAPH_TABLE`.
4. **End-to-End Profitability & Gross Margin**: Trace multi-hop conversions through to the product catalog to evaluate true Gross Margin by marketing channel.
5. **Unified Executive Scorecard**: Fuse `GRAPH_EXPAND` (safe budget rollups) and `GRAPH_TABLE` (profit attribution) on the same graph in a single query.
6. **Ground AI Agents in Gemini Enterprise**: Ground a Conversational Analytics Data Agent in BigQuery Studio with declared graph measures.

### What you'll need
* A Google Cloud project with billing enabled.
* A modern web browser (Google Chrome recommended).
* Basic knowledge of SQL.

### Cost Estimate
This codelab uses BigQuery Enterprise Edition features (Property Graph and Measures). Running this tutorial costs less than **$1.00 USD** in BigQuery compute when using autoscaling slots and cleaning up the reservation immediately after completion.

---

## 2. Setup and Requirements
Duration: 5

### Open Cloud Shell
Activate Google Cloud Shell by clicking the terminal icon in the upper-right corner of the Google Cloud Console.

### Set up Environment Variables
In Cloud Shell, set your project ID and target region:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="US"
export RESERVATION_NAME="graph-attribution-res"
export DATASET="thelook_graph"

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

The diagram below illustrates the unified property graph architecture. We overlay our graph on Google's public `thelook_ecommerce` dataset, adding a reference view for marketing channels and a pre-calculated attribution edge table:

```
[channels] <──(attributed_to)── [events] <──(generated_event)── [users]
                                   │
                              (influenced)
                                   ▼
[products] <──(is_product)── [order_items] ──(belongs_to)──> [orders]
```

### Zero-Copy Architecture via Public Dataset
Instead of downloading gigabytes of CSV files or needing special data approval, we reference Google's pre-approved public dataset directly:
* **Node Tables**:
  * `bigquery-public-data.thelook_ecommerce.users`: Registered e-commerce shoppers.
  * `bigquery-public-data.thelook_ecommerce.events`: Web interactions, browsing sessions, and traffic sources (Email, Adwords, Facebook, YouTube, Organic).
  * `bigquery-public-data.thelook_ecommerce.orders`: Completed e-commerce purchases.
  * `bigquery-public-data.thelook_ecommerce.order_items`: Individual purchased items with transaction prices.
  * `bigquery-public-data.thelook_ecommerce.products`: Merchandise catalog with cost of goods sold (COGS) and retail prices.
* **Marketing Reference & Attribution Tables** (in your local `thelook_graph` dataset):
  * `marketing_channels`: Upstream channel budgets, default CPC benchmarks, and target ROAS goals.
  * `edge_influenced`: Normalized attribution weights connecting events to orders within a 30-day conversion window.

### Create Dataset and Reference Tables DDL
Execute the following SQL in BigQuery Studio (or run [`sql/01_setup_schema_and_graph.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/01_setup_schema_and_graph.sql)):

```sql
-- 1. Create Graph Workspace Dataset
CREATE SCHEMA IF NOT EXISTS `thelook_graph`
OPTIONS (
  location = 'US',
  description = 'Marketing Attribution & ROAS Graph using thelook_ecommerce'
);

-- 2. Create Marketing Channels Reference View
CREATE OR REPLACE VIEW `thelook_graph.marketing_channels` AS
SELECT "Adwords" AS channel_name, 50000.0 AS weekly_budget, 1.50 AS default_cpc, 4.0 AS target_roas UNION ALL
SELECT "Facebook", 30000.0, 1.10, 3.5 UNION ALL
SELECT "YouTube", 25000.0, 0.85, 3.0 UNION ALL
SELECT "Email", 10000.0, 0.10, 8.0 UNION ALL
SELECT "Organic", 5000.0, 0.00, 10.0;

-- 3. Create Attributed Edge Table: edge_influenced
-- Pre-calculates First-Touch, Last-Touch, and Linear attribution weights over a 30-day window
CREATE OR REPLACE TABLE `thelook_graph.edge_influenced` AS
WITH ranked_touchpoints AS (
  SELECT
    e.id AS event_id,
    o.order_id,
    e.traffic_source,
    e.created_at AS event_timestamp,
    o.created_at AS order_timestamp,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY e.created_at ASC) AS touchpoint_asc,
    ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY e.created_at DESC) AS touchpoint_desc,
    COUNT(*) OVER (PARTITION BY o.order_id) AS total_touchpoints
  FROM `bigquery-public-data.thelook_ecommerce.orders` o
  JOIN `bigquery-public-data.thelook_ecommerce.events` e
    ON o.user_id = e.user_id 
   AND e.created_at <= o.created_at
   AND e.created_at >= TIMESTAMP_SUB(o.created_at, INTERVAL 30 DAY)
  WHERE o.status NOT IN ("Cancelled", "Returned")
)
SELECT 
  event_id,
  order_id,
  traffic_source,
  touchpoint_asc AS touchpoint_rank,
  total_touchpoints,
  IF(touchpoint_asc = 1, 1.0, 0.0) AS first_touch_weight,
  IF(touchpoint_desc = 1, 1.0, 0.0) AS last_touch_weight,
  ROUND(1.0 / total_touchpoints, 4) AS linear_weight
FROM ranked_touchpoints;
```

---

## 4. Verifying Public & Marketing Reference Data
Duration: 5

Because the dataset is pre-approved and publicly accessible in Google Cloud, no CSV data loading or bucket creation is needed!

### Verify Data Access & Row Counts
Run this query in BigQuery Studio to verify table connectivity:

```sql
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM `bigquery-public-data.thelook_ecommerce.users` UNION ALL
SELECT 'events', COUNT(*) FROM `bigquery-public-data.thelook_ecommerce.events` UNION ALL
SELECT 'orders', COUNT(*) FROM `bigquery-public-data.thelook_ecommerce.orders` UNION ALL
SELECT 'order_items', COUNT(*) FROM `bigquery-public-data.thelook_ecommerce.order_items` UNION ALL
SELECT 'products', COUNT(*) FROM `bigquery-public-data.thelook_ecommerce.products` UNION ALL
SELECT 'marketing_channels', COUNT(*) FROM `thelook_graph.marketing_channels` UNION ALL
SELECT 'edge_influenced', COUNT(*) FROM `thelook_graph.edge_influenced`;
```

#### Expected Row Counts:
| Table Name | Source | Row Count | Description |
| :--- | :--- | :--- | :--- |
| `users` | `bigquery-public-data.thelook_ecommerce` | **100,000** | Registered global shoppers |
| `events` | `bigquery-public-data.thelook_ecommerce` | **~2,431,963** | Web traffic events & channel touchpoints |
| `orders` | `bigquery-public-data.thelook_ecommerce` | **~125,226** | E-commerce orders |
| `order_items` | `bigquery-public-data.thelook_ecommerce` | **~181,759** | Line-item transactions with sale price |
| `products` | `bigquery-public-data.thelook_ecommerce` | **~29,120** | Product catalog with COGS & retail price |
| `marketing_channels` | `thelook_graph` (View) | **5** | Channel budgets & ROAS targets |
| `edge_influenced` | `thelook_graph` (Table) | **~956,420** | 30-day touchpoint attribution edges |

---

## 5. Defining the Unified Property Graph & Semantic Measures
Duration: 10

### 🎯 Milestone Checkpoint 1: Zero-Copy Property Graph Modeling

Rather than maintaining separate graphs or copying millions of rows, BigQuery Property Graph maps directly to public tables and local views. In this step, we create the single, unified enterprise property graph:
* **`thelook_graph.eCommerce_Integrated`**: A **master multi-entity graph** connecting marketing channels, web events, users, orders, order items, and products.

### How a Single Graph Powers Both Workflows
1. **Multi-Grain Rollups (`GRAPH_EXPAND`)**: Uses `start_node => "events"` or `start_node => "order_items"` to safely report upstream budgets and downstream volumes without fan-out inflation.
2. **Multi-Hop Network Traversals (`GRAPH_TABLE` & pure ISO GQL)**: Traverses deep non-linear paths across events, orders, order items, and product costs.

```sql
CREATE OR REPLACE PROPERTY GRAPH `thelook_graph.eCommerce_Integrated`
NODE TABLES (
  -- Users Node Table
  `bigquery-public-data.thelook_ecommerce.users` AS users
    KEY (id)
    LABEL users PROPERTIES (
      id, first_name, last_name, email, age, gender, country, traffic_source, created_at,
      MEASURE(COUNT(DISTINCT id)) AS total_users
    ),

  -- Events Node Table (Web Traffic & Touchpoint Interactions)
  `bigquery-public-data.thelook_ecommerce.events` AS events
    KEY (id)
    LABEL events PROPERTIES (
      id, user_id, session_id, created_at, traffic_source, event_type, browser, city, state,
      MEASURE(COUNT(id)) AS total_events,
      MEASURE(COUNT(DISTINCT session_id)) AS total_sessions
    ),

  -- Orders Node Table (Commercial Transactions)
  `bigquery-public-data.thelook_ecommerce.orders` AS orders
    KEY (order_id)
    LABEL orders PROPERTIES (
      order_id, user_id, status, created_at, num_of_item,
      MEASURE(COUNT(order_id)) AS total_orders
    ),

  -- Order Items Node Table (Line-Item Financial Leaf Grain)
  `bigquery-public-data.thelook_ecommerce.order_items` AS order_items
    KEY (id)
    LABEL order_items PROPERTIES (
      id, order_id, user_id, product_id, sale_price, status, created_at,
      MEASURE(SUM(sale_price)) AS gross_revenue,
      MEASURE(COUNT(id)) AS total_items_sold
    ),

  -- Products Catalog Node Table
  `bigquery-public-data.thelook_ecommerce.products` AS products
    KEY (id)
    LABEL products PROPERTIES (
      id, cost, category, name, brand, retail_price, department,
      MEASURE(AVG(cost)) AS avg_cost,
      MEASURE(AVG(retail_price)) AS avg_retail_price
    ),

  -- Marketing Channels Node Table (Upstream Budget & Targets)
  `thelook_graph.marketing_channels` AS channels
    KEY (channel_name)
    LABEL channels PROPERTIES (
      channel_name, weekly_budget, target_roas,
      MEASURE(SUM(weekly_budget)) AS total_budget
    )
)
EDGE TABLES (
  -- Event -> Channel
  `bigquery-public-data.thelook_ecommerce.events` AS event_channel
    KEY (id)
    SOURCE KEY (id) REFERENCES events (id)
    DESTINATION KEY (traffic_source) REFERENCES channels (channel_name)
    LABEL ATTRIBUTED_TO NO PROPERTIES,

  -- User -> Event
  `bigquery-public-data.thelook_ecommerce.events` AS user_event
    KEY (id)
    SOURCE KEY (user_id) REFERENCES users (id)
    DESTINATION KEY (id) REFERENCES events (id)
    LABEL GENERATED_EVENT NO PROPERTIES,

  -- Event -> Order (Attribution Edge with Weights)
  `thelook_graph.edge_influenced` AS edge_influenced
    KEY (event_id, order_id)
    SOURCE KEY (event_id) REFERENCES events (id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL INFLUENCED PROPERTIES (
      touchpoint_rank, total_touchpoints, first_touch_weight, last_touch_weight, linear_weight
    ),

  -- Order Item -> Order
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_order
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (order_id) REFERENCES orders (order_id)
    LABEL BELONGS_TO NO PROPERTIES,

  -- Order Item -> Product
  `bigquery-public-data.thelook_ecommerce.order_items` AS item_product
    KEY (id)
    SOURCE KEY (id) REFERENCES order_items (id)
    DESTINATION KEY (product_id) REFERENCES products (id)
    LABEL IS_PRODUCT NO PROPERTIES
);
```

> [!NOTE]
> **Schema Cleanliness**: Structural edges (`ATTRIBUTED_TO`, `GENERATED_EVENT`, `BELONGS_TO`, `IS_PRODUCT`) use `NO PROPERTIES`. Properties are defined only on `INFLUENCED`, where the attribution weights and rankings reside.

---

## 6. Inspecting Graph Schema, Semantic Measures & Paths
Duration: 8

### 🎯 Milestone Checkpoint 2: Inspecting Semantic Measures & Graph Schema

#### 1. Inspect Declared Measures via INFORMATION_SCHEMA
Because measures are registered within the Property Graph schema, they are cataloged under `INFORMATION_SCHEMA.PROPERTY_GRAPHS`. Execute [`sql/02_measure_introspection.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/02_measure_introspection.sql):

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

**Query Results:**
| Node Table | Measure Name | Measure Expression | Measure Type |
| :--- | :--- | :--- | :--- |
| `channels` | `total_budget` | `SUM(weekly_budget)` | `MEASURE<FLOAT64>` |
| `events` | `total_events` | `COUNT(id)` | `MEASURE<INT64>` |
| `events` | `total_sessions` | `COUNT(DISTINCT session_id)` | `MEASURE<INT64>` |
| `order_items` | `gross_revenue` | `SUM(sale_price)` | `MEASURE<FLOAT64>` |
| `order_items` | `total_items_sold` | `COUNT(id)` | `MEASURE<INT64>` |
| `orders` | `total_orders` | `COUNT(order_id)` | `MEASURE<INT64>` |
| `products` | `avg_cost` | `AVG(cost)` | `MEASURE<FLOAT64>` |
| `products` | `avg_retail_price` | `AVG(retail_price)` | `MEASURE<FLOAT64>` |
| `users` | `total_users` | `COUNT(DISTINCT id)` | `MEASURE<INT64>` |

---

#### 2. The Cartesian Fan-Out Benchmark: Upstream vs. Downstream Variables

Why can't you simply run a standard SQL `SUM()` across joined tables?

Execute [`sql/03_cartesian_fanout_benchmark.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/03_cartesian_fanout_benchmark.sql) to see the Cartesian explosion in action:

```sql
SELECT
  channel_name,
  ANY_VALUE(weekly_budget) AS actual_budget,
  ROUND(SUM(weekly_budget), 2) AS blown_up_budget,
  COUNT(*) AS path_row_count,
  ROUND(SUM(weekly_budget) / ANY_VALUE(weekly_budget)) AS duplication_factor
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (c:channels)<-[:ATTRIBUTED_TO]-(e:events)-[i:INFLUENCED]->(o:orders)
  COLUMNS (c.channel_name, c.weekly_budget)
)
GROUP BY channel_name
ORDER BY path_row_count DESC;
```

**Benchmark Results:**
| Channel Name | Actual Budget | Blown-Up Budget (Naive SUM) | Path Row Count | Duplication Factor |
| :--- | :--- | :--- | :--- | :--- |
| **Email** | **$10,000.00** | **$4,322,470,000.00** ($4.32 Billion!) | 432,247 | **432,247x** |
| **Adwords** | **$50,000.00** | **$14,276,850,000.00** ($14.28 Billion!) | 285,537 | **285,537x** |
| **Facebook** | **$30,000.00** | **$2,857,890,000.00** ($2.86 Billion!) | 95,263 | **95,263x** |
| **YouTube** | **$25,000.00** | **$2,374,225,000.00** ($2.37 Billion!) | 94,969 | **94,969x** |
| **Organic** | **$5,000.00** | **$242,020,000.00** ($242 Million!) | 48,404 | **48,404x** |

> [!CAUTION]
> **Why did this happen?**
> * **Upstream Variables**: Defined at a coarse, top-of-funnel grain (e.g. `weekly_budget` at the Marketing Channel level). There is only **1 row** per channel.
> * **Downstream Variables**: Defined at a fine, bottom-of-funnel grain (e.g. `events` and `orders`). Each channel connects to hundreds of thousands of downstream paths.
> * When you perform a multi-hop graph match or relational `JOIN`, the upstream budget is repeated on every single path. Applying a naive `SUM(weekly_budget)` multiplies the budget by 432,000x!

---

#### 3. Architectural Decision Guide: Plain SQL vs. GRAPH_TABLE vs. GRAPH_EXPAND

| Approach | When to Use | Why? |
| :--- | :--- | :--- |
| **Plain SQL `SUM()` on Single Table** | Aggregating a column at its native table grain (e.g. `SELECT SUM(weekly_budget) FROM marketing_channels`). | 100% safe. No joins exist to multiply rows. |
| **Plain SQL `SUM()` across Multi-Table JOINs** | ❌ **ANTI-PATTERN** on 1:N or N:M relationships. | Causes catastrophic Cartesian duplication (e.g. $10k becomes $4.3 Billion). |
| **`GRAPH_TABLE`** | Network traversals, multi-hop paths, edge filtering, and **leaf-grain weighted aggregations**. | Evaluates row-level expressions across paths. Safe for revenue/COGS because weights sum to 1.0 ($\sum w_i = 1.0$). |
| **`GRAPH_EXPAND` + `AGG()`** | Multi-grain BI rollups combining upstream measures (e.g. channel budget) with downstream measures (e.g. total events). | Evaluates declared `MEASURE`s at their native entity grain independently, completely preventing fan-out errors. |

### Summary Rule of Thumb
* **Use `GRAPH_TABLE`** when you need paths, hops, and row-level expressions across connected nodes.
* **Use `GRAPH_EXPAND`** when you need multi-grain reporting and ROAS across hops using declared `MEASURE`s.
* **Use raw `SUM()`** only on single tables or on normalized leaf-grain columns inside `GRAPH_TABLE`.

---

## 7. Use Case 1: Campaign Budget vs. Actual Ad Spend Rollup (GRAPH_EXPAND)
Duration: 5

### Business Scenario
Marketing executives need a channel-level rollup of weekly budgets alongside total event volume and active sessions. They need this without writing complex subqueries or risking Cartesian duplication.

### Standard SQL Query with `GRAPH_EXPAND`
Execute [`sql/06_use_case_graph_expand.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/06_use_case_graph_expand.sql):

```sql
SELECT
  channels_channel_name AS channel,
  AGG(channels_total_budget) AS weekly_budget,
  AGG(events_total_events) AS total_events,
  AGG(events_total_sessions) AS total_sessions
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "events")
GROUP BY channel
ORDER BY total_events DESC;
```

> [!NOTE]
> **Multi-Root Resolution:** Because `eCommerce_Integrated` connects multiple root tables, specifying `start_node => "events"` tells BigQuery which branch of the graph to expand.

### Query Results
| Channel | Weekly Budget | Total Events | Total Sessions |
| :--- | :--- | :--- | :--- |
| **Email** | **$10,000.00** | 1,091,729 | 306,439 |
| **Adwords** | **$50,000.00** | 725,102 | 204,296 |
| **YouTube** | **$25,000.00** | 241,729 | 68,233 |
| **Facebook** | **$30,000.00** | 241,337 | 68,036 |
| **Organic** | **$5,000.00** | 121,058 | 34,159 |

Notice that `weekly_budget` is exact ($10,000 for Email, $50,000 for Adwords) despite rolling up over 1 million events!

---

## 8. Use Case 2: Multi-Touch Marketing Attribution Comparison (GRAPH_TABLE)
Duration: 5

### Business Scenario
Compare the revenue assigned to each marketing channel across three classic attribution models:
1. **First-Touch Attribution**: Gives 100% of the conversion credit to the customer's initial discovery channel.
2. **Last-Touch Attribution**: Gives 100% of the credit to the touchpoint immediately preceding the purchase.
3. **Linear Attribution**: Distributes credit equally across all touchpoints in the customer's 30-day journey.

### Query with `GRAPH_TABLE`
Execute [`sql/04_use_case_multi_touch_attribution.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/04_use_case_multi_touch_attribution.sql):

```sql
SELECT
  channel,
  ROUND(SUM(sale_price * first_touch_weight), 2) AS first_touch_revenue,
  ROUND(SUM(sale_price * last_touch_weight), 2) AS last_touch_revenue,
  ROUND(SUM(sale_price * linear_weight), 2) AS linear_revenue
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (e:events)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)
  COLUMNS (
    e.traffic_source AS channel,
    oi.sale_price,
    i.first_touch_weight,
    i.last_touch_weight,
    i.linear_weight
  )
)
GROUP BY channel
ORDER BY linear_revenue DESC;
```

### Query Results
| Channel | First-Touch Revenue | Last-Touch Revenue | Linear Attributed Revenue |
| :--- | :--- | :--- | :--- |
| **Email** | $3,681,543.23 | $3,696,447.52 | **$3,686,696.80** |
| **Adwords** | $2,411,693.53 | $2,409,635.01 | **$2,403,729.97** |
| **Facebook** | $799,842.66 | $792,703.50 | **$800,999.57** |
| **YouTube** | $786,474.26 | $789,685.75 | **$791,000.88** |
| **Organic** | $414,224.82 | $405,306.72 | **$409,476.12** |

### Key Marketing Takeaways
* **Email dominates both discovery and closing**: Generating ~$3.69M under all models, demonstrating powerful retention and re-engagement.
* **Mathematical Integrity**: Because for every order $\sum \text{linear\_weight} = 1.0$, the total sum of linear attributed revenue across all channels ($8,091,903.34) exactly equals total gross merchandise volume.

---

## 9. Use Case 3: Channel Profit Contribution & Gross Margin Analysis (GRAPH_TABLE)
Duration: 5

### Business Scenario
Evaluating channels solely on revenue is misleading. A channel might generate high gross sales by promoting low-margin items. In this 4-hop traversal, we connect events to orders, line items, and product costs to evaluate true **Gross Profit** and **Gross Margin %**.

### 🎯 Milestone Checkpoint 3: Multi-Hop Profit Attribution at the Leaf Grain
Execute [`sql/05_use_case_channel_profitability.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/05_use_case_channel_profitability.sql):

```sql
SELECT
  channel,
  ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
  ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
  ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit,
  ROUND(SAFE_DIVIDE(SUM((sale_price - cost) * linear_weight), SUM(sale_price * linear_weight)) * 100, 2) AS gross_margin_pct
FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
  MATCH (e:events)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
  COLUMNS (
    e.traffic_source AS channel,
    oi.sale_price,
    p.cost,
    i.linear_weight
  )
)
GROUP BY channel
ORDER BY gross_profit DESC;
```

### Query Results
| Channel | Attributed Revenue | Attributed COGS | Gross Profit Contribution | Gross Margin % |
| :--- | :--- | :--- | :--- | :--- |
| **Email** | $3,686,696.80 | $1,771,312.91 | **$1,915,383.88** | **51.95%** |
| **Adwords** | $2,403,729.97 | $1,156,833.86 | **$1,246,896.10** | **51.87%** |
| **Facebook** | $800,999.57 | $385,624.62 | **$415,374.95** | **51.86%** |
| **YouTube** | $791,000.88 | $380,231.04 | **$410,769.83** | **51.93%** |
| **Organic** | $409,476.12 | $196,302.61 | **$213,173.51** | **52.06%** |

Gross margins are remarkably consistent across channels (~51.9%), proving that all channels drive a healthy merchandise product mix.

---

## 10. Use Case 4: Category Performance & Customer Journey
Duration: 5

### Product Category Rollup with `GRAPH_EXPAND`
Using `start_node => "order_items"`, we can roll up category revenue and unit sales:

```sql
SELECT
  products_category AS category,
  AGG(order_items_gross_revenue) AS category_revenue,
  AGG(order_items_total_items_sold) AS items_sold,
  AGG(products_avg_cost) AS avg_item_cost,
  AGG(products_avg_retail_price) AS avg_item_retail_price
FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "order_items")
GROUP BY category
ORDER BY category_revenue DESC
LIMIT 5;
```

### Query Results:
| Category | Category Revenue | Items Sold | Avg Item Cost | Avg Retail Price |
| :--- | :--- | :--- | :--- | :--- |
| **Outerwear & Coats** | $986,751.74 | 6,477 | $67.45 | $152.35 |
| **Jeans** | $947,438.95 | 9,376 | $46.82 | $101.05 |
| **Sweaters** | $628,585.78 | 8,099 | $36.12 | $77.61 |
| **Swim** | $484,543.54 | 8,250 | $26.90 | $58.73 |
| **Suits & Sport Coats**| $481,266.09 | 3,716 | $61.20 | $129.51 |

---

### Customer Journey Traversal (Pure ISO GQL)
Trace how active shopper **Paul** (`user_id = 65516`) interacted with touchpoints across Adwords prior to placing orders:

```sql
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
LIMIT 5;
```

**Results:**
| User ID | First Name | Traffic Source | Event Type | Touchpoint Rank | Linear Weight | Order ID |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 65516 | Paul | Adwords | department | 16 | 0.0370 | 81975 |
| 65516 | Paul | Adwords | department | 16 | 0.0127 | 81973 |
| 65516 | Paul | Adwords | department | 16 | 0.0119 | 81976 |
| 65516 | Paul | Adwords | department | 16 | 0.0112 | 81974 |
| 65516 | Paul | Adwords | cart | 67 | 0.0127 | 81973 |

---

## 11. Use Case 5: Unified Executive ROAS Scorecard (Dual Views on a Single Graph)
Duration: 10

### Business Scenario
The Chief Marketing Officer needs a unified scorecard that brings together:
1. **Top-of-Funnel Marketing Measures**: Weekly budget and total sessions from `eCommerce_Integrated` via `GRAPH_EXPAND(..., start_node => "events")`.
2. **Bottom-of-Funnel Profit Attribution**: Attributed revenue, COGS, and gross profit from `eCommerce_Integrated` via `GRAPH_TABLE`.
3. **True ROAS on Budget**: Attributed Revenue divided by Budget.

### Unified Single-Graph Dual Query
Execute [`sql/08_use_case_combined_roas_scorecard.sql`](file:///home/guruvittal/mktg_graph_codelab/sql/08_use_case_combined_roas_scorecard.sql):

```sql
WITH marketing_funnel AS (
  -- 1. Top-of-funnel marketing metrics from eCommerce_Integrated via GRAPH_EXPAND
  SELECT
    channels_channel_name AS channel,
    AGG(channels_total_budget) AS weekly_budget,
    AGG(events_total_events) AS total_events,
    AGG(events_total_sessions) AS total_sessions
  FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "events")
  GROUP BY channel
),

sales_attribution AS (
  -- 2. Bottom-of-funnel 4-hop profit attribution from eCommerce_Integrated via GRAPH_TABLE
  SELECT
    channel,
    ROUND(SUM(sale_price * linear_weight), 2) AS attributed_revenue,
    ROUND(SUM(cost * linear_weight), 2) AS attributed_cogs,
    ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit
  FROM GRAPH_TABLE(`thelook_graph.eCommerce_Integrated`
    MATCH (e:events)-[i:INFLUENCED]->(o:orders)<-[:BELONGS_TO]-(oi:order_items)-[:IS_PRODUCT]->(p:products)
    COLUMNS (
      e.traffic_source AS channel,
      oi.sale_price,
      p.cost,
      i.linear_weight
    )
  )
  GROUP BY channel
)

SELECT
  m.channel,
  m.weekly_budget,
  m.total_events,
  m.total_sessions,
  s.attributed_revenue,
  s.attributed_cogs,
  s.gross_profit,
  ROUND(s.attributed_revenue / NULLIF(m.weekly_budget, 0), 2) AS roas_on_budget,
  ROUND(SAFE_DIVIDE(s.gross_profit, s.attributed_revenue) * 100, 2) AS gross_margin_pct
FROM marketing_funnel m
JOIN sales_attribution s
  ON m.channel = s.channel
ORDER BY s.attributed_revenue DESC;
```

### Query Results
| Channel | Weekly Budget | Total Events | Total Sessions | Attributed Revenue | Attributed COGS | Gross Profit | ROAS on Budget | Gross Margin % |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Email** | $10,000.00 | 1,091,729 | 306,439 | **$3,686,696.80** | $1,771,312.91 | **$1,915,383.88** | **368.67x** | 51.95% |
| **Adwords** | $50,000.00 | 725,102 | 204,296 | **$2,403,729.97** | $1,156,833.86 | **$1,246,896.10** | **48.07x** | 51.87% |
| **Facebook** | $30,000.00 | 241,337 | 68,036 | **$800,999.57** | $385,624.62 | **$415,374.95** | **26.70x** | 51.86% |
| **YouTube** | $25,000.00 | 241,729 | 68,233 | **$791,000.88** | $380,231.04 | **$410,769.83** | **31.64x** | 51.93% |
| **Organic** | $5,000.00 | 121,058 | 34,159 | **$409,476.12** | $196,302.61 | **$213,173.51** | **81.90x** | 52.06% |

---

## 12. Conversational Analytics Agent in BigQuery Studio & Gemini Enterprise
Duration: 10

### Overview of Marketing-Attribution-Agent

To make these graph insights accessible to non-technical executives, deploy a **Conversational Analytics (CA)** data agent directly from **BigQuery Studio** to **Gemini Enterprise**.

### 🎯 Milestone Checkpoint 4: Grounding AI Agents with Semantic Graph Measures
Grounding LLMs on raw tables often leads to calculation errors when computing complex metrics like ROAS or Gross Margin. Because our Property Graph `eCommerce_Integrated` defines semantic measures (`total_budget`, `gross_revenue`, `total_events`, `avg_cost`), the agent leverages these pre-defined formulas to query data reliably and answer executive questions with high fidelity.

```
+───────────────────────────────────────────────────+
| BigQuery Studio / Data Canvas                     |
| (Property Graph: eCommerce_Integrated             |
|  with Semantic MEASUREs)                          |
+─────────────────────────┬─────────────────────────+
                          │ 1. Create & Ground CA Data Agent
                          ▼
+───────────────────────────────────────────────────+
| Conversational Analytics Agent                    |
| (Marketing-Attribution-Agent)                     |
+─────────────────────────┬─────────────────────────+
                          │ 2. Deploy to Gemini Enterprise
                          ▼
+───────────────────────────────────────────────────+
| Gemini Enterprise Chat / Copilot                  |
| (Business User Natural Language)                  |
+───────────────────────────────────────────────────+
```

### Steps to Create and Deploy from BigQuery Studio

1. **Open BigQuery Studio**:
   - In the Google Cloud Console, navigate to **BigQuery** > **Studio**.
   - Open dataset `thelook_graph` and verify the Property Graph: `eCommerce_Integrated`.

2. **Create the Conversational Analytics Agent**:
   - Select **Create Data Agent** (or open **Data Canvas** with Conversational Analytics enabled).
   - Display Name: `Marketing-Attribution-Agent`
   - Description: *"Answers questions about marketing touchpoints, attribution graphs, channel ROAS, and customer conversion journeys."*
   - Data Sources: Attach dataset `thelook_graph` and Property Graph `eCommerce_Integrated`.

3. **Deploy to Gemini Enterprise**:
   - In the agent panel, click **Deploy to Gemini Enterprise**.
   - Select your target Gemini Enterprise application.
   - Click **Deploy**. The agent is immediately published and available to authorized users.

---

## 13. Clean Up
Duration: 2

To prevent unwanted charges in your Google Cloud account after completing this lab, clean up the resources:

```sql
-- 1. Drop Property Graph and Dataset
DROP PROPERTY GRAPH IF EXISTS `thelook_graph.eCommerce_Integrated`;
DROP SCHEMA IF EXISTS `thelook_graph` CASCADE;
```

In Cloud Shell, delete the BigQuery reservation:

```bash
# Delete reservation assignment
bq rm --reservation_assignment \
  --project_id=${PROJECT_ID} \
  --location=${REGION} \
  ${RESERVATION_NAME}.QUERY_PROJECT_${PROJECT_ID}

# Delete reservation
bq rm --reservation \
  --project_id=${PROJECT_ID} \
  --location=${REGION} \
  ${RESERVATION_NAME}
```

---

## 14. Conclusion
Duration: 1

Congratulations! You have successfully built an end-to-end Marketing Attribution & ROAS Analysis Property Graph with BigQuery Graph and integrated it with a Conversational Analytics Agent deployed in Gemini Enterprise.

### 🏆 Goal Achievement Summary
- [x] **Zero-Copy Property Graph Modeling**: Constructed the single master graph `eCommerce_Integrated` directly over Google's public `thelook_ecommerce` dataset without data duplication or approval hurdles.
- [x] **Semantic Measures (`MEASURE(...)`)**: Embedded pre-aggregated business formulas (`total_budget`, `gross_revenue`, `total_events`, `avg_cost`) directly into graph nodes.
- [x] **Multi-Grain Reporting with `GRAPH_EXPAND`**: Flattened the marketing hierarchy on demand with `GRAPH_EXPAND(..., start_node => "events")` and `AGG()` for fast, on-demand reporting without fan-out inflation.
- [x] **Multi-Touch Marketing Attribution**: Compared First-Touch, Last-Touch, and Linear Attribution models using `GRAPH_TABLE` with normalized weights ($\sum w_i = 1.0$).
- [x] **Unified Single-Graph Dual Paradigm**: Fused `GRAPH_EXPAND` and `GRAPH_TABLE` on the same graph in a single GoogleSQL CTE query to compare True ROAS on Budget against gross margin.
- [x] **Conversational Agent Grounding**: Grounded a Conversational Analytics Data Agent in BigQuery Studio with semantic graph measures and deployed it to Gemini Enterprise.

### Next Steps & Further Reading
- [BigQuery Property Graph Documentation](https://cloud.google.com/bigquery/docs/graph-overview)
- [ISO GQL in GoogleSQL](https://cloud.google.com/bigquery/docs/reference/standard-sql/graph-query-language)
- [GRAPH_EXPAND Documentation](https://cloud.google.com/bigquery/docs/reference/standard-sql/graph-query-language#graph_expand)
- [Gemini Enterprise Agent Studio](https://cloud.google.com/gemini/docs/enterprise)
