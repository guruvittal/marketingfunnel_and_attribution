# Marketing Attribution with BigQuery Graph & Measures

> **Google Developers Codelab**: Build a zero-copy multi-touch Marketing Attribution and ROAS Graph using BigQuery Graph (ISO GQL, Semantic Measures, and `GRAPH_EXPAND`) on `bigquery-public-data.thelook_ecommerce` (backed by `gs://sample-data-and-media/thelook_dataset_snapshot/`), and query it conversationally using a Conversational Analytics Data Agent deployed from BigQuery Studio to Gemini Enterprise.

---

## 📖 Codelab Overview

- **Codelab Source**: [`codelab.md`](./codelab.md)
- **Interactive HTML App**: [`index.html`](./index.html)
- **Production SQL Scripts**: [`sql/`](./sql/)
- **Unified Property Graph**:
  - `thelook_graph.eCommerce_Integrated`: Master 6-entity unified enterprise property graph with 9 declared semantic measures, powering multi-grain reporting (`GRAPH_EXPAND` via `start_node => "events"` and `start_node => "order_items"`), path traversals (`GRAPH_TABLE`), and pure ISO GQL journey mapping.
- **Gemini Enterprise Agent Specs**: [`agent/`](./agent/)
  - Agent Name: `Marketing-Attribution-Agent`
  - Setup Guide: [`agent/gemini_enterprise_setup.md`](./agent/gemini_enterprise_setup.md)
  - Sample Conversations: [`agent/sample_conversations.md`](./agent/sample_conversations.md)

---

## 🏛️ Architectural Highlights

1. **Zero-Copy Public Data Integration**:
   - `CREATE PROPERTY GRAPH` directly links Google Cloud's public dataset (`bigquery-public-data.thelook_ecommerce.*`) as node tables (`users`, `events`, `orders`, `order_items`, `products`).
   - Requires **zero data copying or approval delays**—users only maintain a lightweight local dataset (`thelook_graph`) for a 5-row reference view (`marketing_channels`) and an attribution edge table (`edge_influenced`).
2. **Elimination of the 432,247x Cartesian Fan-Out**:
   - Upstream variables (coarse grains like `weekly_budget` at 1 row per channel) inflate catastrophically when joined to downstream leaf-level events and order items (e.g., Email's $10,000 budget erroneously explodes to **$4,322,470,000** in relational joins).
   - Solved via **Semantic Measures** in `GRAPH_EXPAND` (safe aggregation at source grain) and mathematically normalized attribution weights ($\sum w_i = 1.0$) in `GRAPH_TABLE`.
3. **Architectural Decision Guide**:
   - Clear guidelines on when to use plain SQL `SUM()`, relational `JOIN`s, `GRAPH_TABLE()`, and `GRAPH_EXPAND()`.

---

## 🚀 Repository Structure

```
.
├── README.md                                  # Quickstart guide & repository index
├── codelab.md                                 # Google Codelab source (claat-compatible)
├── index.html                                 # Self-contained interactive Codelab Web App (Light Mode)
├── sql/
│   ├── 01_setup_schema_and_graph.sql          # Dataset, view, edge table, & Property Graph DDL (9 MEASUREs)
│   ├── 02_measure_introspection.sql           # INFORMATION_SCHEMA.PROPERTY_GRAPHS introspection
│   ├── 03_cartesian_fanout_benchmark.sql      # Cartesian explosion benchmark (Relational JOIN vs. Graph)
│   ├── 04_use_case_multi_touch_attribution.sql# Multi-touch attribution (First, Last, & Linear touch)
│   ├── 05_use_case_channel_profitability.sql  # 4-hop profitability & Gross Margin % traversal
│   ├── 06_use_case_graph_expand.sql           # Multi-grain reporting with GRAPH_EXPAND and AGG()
│   ├── 07_use_case_customer_journey.sql       # Pure ISO GQL customer journey traversal & TO_JSON()
│   ├── 08_use_case_combined_roas_scorecard.sql# Unified ROAS Scorecard (GRAPH_EXPAND + GRAPH_TABLE CTE)
│   └── 09_plain_sql_vs_graph_guide.sql        # Decision guide: SUM() vs. Relational JOIN vs. Graph
└── agent/
    ├── agent_card.json                        # Conversational Analytics Agent Card specification
    ├── gemini_enterprise_setup.md             # BigQuery Studio to Gemini Enterprise deployment guide
    └── sample_conversations.md                # Conversational analytics interaction trajectories
```

---

## 🎯 Verified Codelab Use Cases

| # | Use Case | Query Type | Purpose |
| :- | :--- | :--- | :--- |
| **1** | **Measure Introspection** | `INFORMATION_SCHEMA` | Unnest declared measures dynamically from graph metadata. |
| **2** | **Cartesian Fan-Out Benchmark** | Relational `JOIN` vs. Graph | Demonstrate the 432,247x upstream budget explosion and graph solution. |
| **3** | **Multi-Touch Attribution** | `GRAPH_TABLE` | Compare First-Touch, Last-Touch, and Linear attribution across 956K journeys. |
| **4** | **Channel Profitability** | `GRAPH_TABLE` (4-hop) | Traverse channel $\to$ event $\to$ order $\to$ item $\to$ product to compute Net Margin % (~51.9%). |
| **5** | **Multi-Grain Graph Rollup** | `GRAPH_EXPAND` + `AGG()` | Roll up events and order items simultaneously without row multiplication. |
| **6** | **Customer Conversion Journey** | Pure ISO GQL | Trace multi-session browsing journeys for high-intent converted users (e.g., User 65516). |
| **7** | **Executive ROAS Scorecard** | Dual-View CTE | Combine `GRAPH_EXPAND` (budget) with `GRAPH_TABLE` (profit) for True ROAS. |
| **8** | **Plain SQL vs. Graph Guide** | Comparative SQL | Step-by-step decision matrix from single-table `SUM()` to `GRAPH_EXPAND`. |

---

## 🛠️ Viewing the Interactive Codelab

Open `index.html` directly in any modern browser:

```bash
# Start a local web server
python3 -m http.server 8080

# Navigate to:
# http://localhost:8080
```
