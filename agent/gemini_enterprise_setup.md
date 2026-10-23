# BigQuery Conversational Analytics & Gemini Enterprise Deployment Guide

This guide documents how the **Marketing-Attribution-Agent** is created and grounded in BigQuery Studio using **Conversational Analytics (CA)** on top of BigQuery Graph, and deployed directly to **Gemini Enterprise**.

---

## Architecture Overview

The agent is powered by Google's BigQuery Conversational Analytics engine, grounded directly on the unified Property Graph schema (`thelook_graph.eCommerce_Integrated`) spanning `bigquery-public-data.thelook_ecommerce` and local attribution views.

```
+───────────────────────────────────────────────────+
| BigQuery Studio / Data Canvas                     |
| (Unified Property Graph: eCommerce_Integrated     |
|  & Semantic MEASUREs)                             |
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

When a business user asks a natural language question (e.g., *"Which marketing channel had the best ROAS?"*):
1. The agent translates user intent into a valid ISO GQL or GoogleSQL graph query (`GRAPH ... MATCH ...`, `GRAPH_TABLE(...)`, or `GRAPH_EXPAND(..., start_node => "events")`).
2. Dispatches the query securely to BigQuery.
3. Interprets the multi-touch attribution results and returns formatted analytical insights, data tables, and actionable business recommendations.

---

## Step-by-Step: Creation and Deployment in BigQuery Studio

### Step 1: Ground on BigQuery Property Graph
1. Navigate to **BigQuery** > **Studio** in the Google Cloud Console.
2. In the Explorer pane, expand your project and dataset `thelook_graph`.
3. Verify that the Property Graph `eCommerce_Integrated` and its underlying tables/views are present.

### Step 2: Create the Conversational Analytics Data Agent
1. In BigQuery Studio, select **Create Data Agent** (or use **Data Canvas** with Conversational Analytics enabled).
2. Configure agent metadata:
   - **Display Name**: `Marketing-Attribution-Agent`
   - **Description**: `Answers questions about marketing touchpoints, attribution graphs, channel ROAS, and customer conversion journeys using thelook_ecommerce.`
3. Select the data sources: Attach dataset `thelook_graph` and Property Graph `eCommerce_Integrated`.

### Step 3: Deploy to Gemini Enterprise
1. In the agent configuration screen, click **Deploy to Gemini Enterprise**.
2. Select your target Gemini Enterprise application / workspace.
3. Click **Deploy**.

Once deployed, the agent is immediately discoverable and callable within Gemini Enterprise.

---

## Conversational Interaction Flow

```
[Business Executive]
       │
       ▼ (Natural Language Question: "What was our net ROAS on Search vs Email?")
[Gemini Enterprise Copilot]
       │
       ▼ (Routed to Agent)
[Marketing-Attribution-Agent (Conversational Analytics)]
       │
       ├─► Generates GRAPH_TABLE on eCommerce_Integrated (profit attribution)
       ├─► OR generates GRAPH_EXPAND on eCommerce_Integrated (macro budget rollups via start_node)
       │
       ▼
[BigQuery Engine]
       │
       ▼ (Returns Attributed Profit & Spend Data)
[Agent Synthesis & Natural Language Response]
       │
       ▼
"Email marketing delivered the highest ROAS at 341.6x ($1.77M gross profit on a $10K budget).
Adwords generated $6.02M gross profit with a 241.1x ROAS on a $50K budget across 876K sessions."
```
