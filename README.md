# Marketing Attribution with BigQuery Graph & Measures

> **Google Developers Codelab**: Build a zero-copy multi-touch Marketing Attribution and ROAS Graph using BigQuery Graph (ISO GQL, Semantic Measures, and `GRAPH_EXPAND`) on `bigquery-public-data.thelook_ecommerce`, and query it conversationally using a Conversational Analytics Data Agent deployed from BigQuery Studio to Gemini Enterprise.

---

## 📖 Codelab Overview

- **Codelab Source**: [`codelab.md`](./codelab.md)
- **Interactive HTML App**: [`index.html`](./index.html)
- **Production SQL Scripts**: [`sql/`](./sql/)
- **Unified Property Graph**:
  - `thelook_graph.eCommerce_Integrated`: Master 6-entity unified enterprise property graph with 10 declared semantic measures, powering multi-grain reporting (`GRAPH_EXPAND` via `start_node => "touchpoints"`), path traversals (`GRAPH_TABLE`), and pure ISO GQL journey mapping.
- **Gemini Enterprise Agent Specs**: [`agent/`](./agent/)
  - Agent Name: `Marketing-Attribution-Agent`
  - Setup Guide: [`agent/gemini_enterprise_setup.md`](./agent/gemini_enterprise_setup.md)
  - Sample Conversations: [`agent/sample_conversations.md`](./agent/sample_conversations.md)

---

## 🏛️ Architectural Highlights

1. **Zero-Copy Public Data Integration**:
   - `CREATE PROPERTY GRAPH` directly links Google Cloud's public dataset (`bigquery-public-data.thelook_ecommerce.*`) as node tables (`users`, `orders`, `order_items`, `products`).
   - Requires **zero data copying or approval delays**—users only maintain a lightweight local dataset (`thelook_graph`) for an 8-campaign reference view (`marketing_campaigns`), an enriched touchpoints view (`touchpoints`), and an attribution edge table (`edge_influenced`).
2. **Elimination of the 1,111,635x Cartesian Fan-Out**:
   - Upstream variables (coarse grains like `total_budget` at 1 row per campaign) inflate catastrophically when joined to downstream leaf-level events and order items (e.g., Email VIP's $60,000 budget erroneously explodes to **$66,698,100,000** in relational joins).
   - Solved via **Semantic Measures** in `GRAPH_EXPAND` (safe aggregation at source grain) and mathematically normalized attribution weights ($\sum w_i = 1.0$) in `GRAPH_TABLE`.
3. **Rich 8-Column Executive Marketing Scorecard**:
   - Combined `GRAPH_EXPAND` with declared `MEASURE`s to report macro budget, clicks, unique reach, total ad spend, remaining budget, and effective CPC across all 8 campaigns.
4. **Unified Single-Graph Dual CTE Paradigm**:
   - Fuses `GRAPH_EXPAND` (safe budget and spend rollup) and `GRAPH_TABLE` (4-hop profit attribution to COGS) on the same graph in a single query to compute True ROAS on Spend vs. ROAS on Budget.
5. **Architectural Decision Guide**:
   - Clear guidelines on when to use plain SQL `SUM()`, relational `JOIN`s, `GRAPH_TABLE()`, and `GRAPH_EXPAND()`.

---

## 🚀 Repository Structure

```
.
├── README.md                                  # Quickstart guide & repository index
├── codelab.md                                 # Google Codelab source (claat-compatible, 14 steps)
├── index.html                                 # Self-contained interactive Codelab Web App (Light Mode)
├── sql/
│   ├── 01_setup_schema_and_graph.sql          # Dataset, views, edge table, & Property Graph DDL (10 MEASUREs)
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

## 🎯 Verified Codelab Steps

| # | Step | Query Type | Purpose |
| :- | :--- | :--- | :--- |
| **1** | **Overview & Business Context** | Narrative | Architectural introduction and business goals. |
| **2** | **Prerequisites & Setup** | Bash / Cloud Shell | Project configuration, APIs, and BigQuery Enterprise reservation. |
| **3** | **Creating Schema & Tables** | DDL | Local reference views (`marketing_campaigns`, `touchpoints`) & attribution edge table. |
| **4** | **Declaring Property Graph & Measures** | DDL (`PROPERTY GRAPH`) | Master graph `eCommerce_Integrated` with 10 semantic measures. |
| **5** | **Measure Introspection** | `INFORMATION_SCHEMA` | Unnest declared measures dynamically from graph metadata. |
| **6** | **Cartesian Fan-Out Benchmark** | Relational `JOIN` vs. Graph | Demonstrate the 1,111,635x upstream budget explosion and graph solution. |
| **7** | **Multi-Touch Attribution** | `GRAPH_TABLE` | Compare First-Touch, Last-Touch, and Linear attribution across 8 campaigns. |
| **8** | **4-Hop Profitability & Margin** | `GRAPH_TABLE` (4-hop) | Traverse touchpoint $\to$ order $\to$ item $\to$ product to compute Gross Margin % (~51.9%). |
| **9** | **Multi-Grain Scorecard** | `GRAPH_EXPAND` + `AGG()` | 8-column executive scorecard tracking budget, clicks, reach, spend, and CPC. |
| **10** | **Customer Journey Mapping** | Pure ISO GQL | Trace multi-session browsing journeys for high-intent converted users (e.g., User 65516 / Paul). |
| **11** | **Unified Executive Scorecard** | Dual-View CTE | Combine `GRAPH_EXPAND` (spend & budget) with `GRAPH_TABLE` (profit) for True ROAS. |
| **12** | **Conversational Analytics Agent** | BigQuery Studio / CA | Ground AI agents in BigQuery Studio with semantic measures and deploy to Gemini Enterprise. |
| **13** | **Decision Guide & Clean Up** | Architecture Guide | Decision matrix from single-table `SUM()` to `GRAPH_EXPAND` + resource cleanup. |
| **14** | **Conclusion & Key Takeaways** | Summary | Milestone achievement summary and next steps. |

---

## 🛠️ Viewing the Interactive Codelab

Open `index.html` directly in any modern browser:

```bash
# Start a local web server
python3 -m http.server 8080

# Navigate to:
# http://localhost:8080
```
