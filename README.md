# Marketing Attribution with BigQuery Graph & Measures

> **Google Developers Codelab**: Build a multi-touch Marketing Attribution and ROAS Graph using BigQuery Graph (ISO GQL, Semantic Measures, and `GRAPH_EXPAND`), and query it conversationally using a Conversational Analytics Data Agent deployed from BigQuery Studio to Gemini Enterprise.

---

## 📖 Codelab Overview

- **Codelab File**: [`codelab.md`](./codelab.md)
- **Interactive HTML Preview**: [`index.html`](./index.html)
- **SQL Scripts**: [`sql/`](./sql/)
- **Grounded Property Graph**:
  - `eRetail_marketing.eCommerce_Integrated`: Master 6-entity unified enterprise property graph with semantic measures, powering both `GRAPH_EXPAND` (via `start_node => "touchpoints"`) and multi-hop network traversals (`GRAPH_TABLE` and ISO GQL).
- **Gemini Enterprise Agent Specs**: [`agent/`](./agent/)
  - Agent Name: `Marketing-Attribution-Agent`
  - Setup Guide: [`agent/gemini_enterprise_setup.md`](./agent/gemini_enterprise_setup.md)
  - Sample Conversations: [`agent/sample_conversations.md`](./agent/sample_conversations.md)

---

## 🚀 Repository Structure

```
.
├── README.md                           # Quickstart guide & repository index
├── codelab.md                          # Google Codelab source (claat-compatible)
├── index.html                          # Self-contained interactive Google Codelab Web App
├── data/                               # Sample dataset CSVs (506 KB)
│   ├── campaigns.csv                   # 8 Marketing ad campaigns
│   ├── customers.csv                   # 1,000 Customers
│   ├── edge_influenced.csv             # 1,728 Multi-touch attribution links
│   ├── order_items.csv                 # 1,544 Line items
│   ├── orders.csv                      # 800 Orders
│   ├── products.csv                    # 8 Products
│   └── touchpoints.csv                 # 5,000 Marketing touchpoints
├── sql/
│   ├── 01_setup_schema.sql             # BigQuery schema & table definitions
│   ├── 02_load_sample_data.sql         # Seed data loader (LOAD DATA from public GCS or data/)
│   ├── 03_create_property_graph.sql    # Unified Property Graph DDL (eCommerce_Integrated with MEASUREs)
│   ├── 04_use_case_graph_expand_spend.sql# Use Case 1: Campaign budget vs. ad spend rollup (GRAPH_EXPAND + start_node)
│   ├── 05_use_case_customer_journey.sql# Use Case 2: Customer journey traversal (Pure ISO GQL)
│   ├── 06_use_case_roas_analysis.sql   # Use Case 3: GRAPH_TABLE ROAS & Gross Profitability query
│   ├── 07_use_case_product_influence.sql# Use Case 4: Product-level campaign influence query
│   └── 08_use_case_combined_roas_scorecard.sql # Use Case 5: Unified Executive ROAS Scorecard (Dual Views on Single Graph)
└── agent/
    ├── agent_card.json                 # Agent Card specification
    ├── gemini_enterprise_setup.md      # Gemini Enterprise registration walkthrough
    └── sample_conversations.md         # Conversational Analytics interactions & trajectories
```

---

## 🎯 The 5 Core Use Cases

1. **Use Case 1: Campaign Budget vs. Ad Spend Rollup** (`eCommerce_Integrated` | `GRAPH_EXPAND` + `AGG()`)
   - Standard relational SQL rollup for BI tools and executive scorecards extracting the marketing branch via `start_node => "touchpoints"`.
2. **Use Case 2: Multi-Touch Customer Journey** (`eCommerce_Integrated` | Pure ISO GQL)
   - Traces cross-channel touchpoint paths and device shifts prior to orders.
3. **Use Case 3: Net ROAS & Gross Profitability** (`eCommerce_Integrated` | `GRAPH_TABLE`)
   - Deducts product COGS from attributed net revenue to evaluate actual profit contribution.
4. **Use Case 4: Product Category Influence** (`eCommerce_Integrated` | `GRAPH_TABLE`)
   - 5-hop path traversal correlating marketing channels with specific merchandise sales.
5. **Use Case 5: Unified Executive ROAS Scorecard** (Dual Views on Single Graph CTE Query)
   - Combines `GRAPH_EXPAND` and `GRAPH_TABLE` on `eCommerce_Integrated` to compute True ROAS on Actual Spend vs. ROAS on Budget.

---

## 🛠️ Viewing the Interactive Codelab

Open `index.html` directly in any web browser:
```bash
google-chrome index.html
# OR start a local server
python3 -m http.server 8080
```
