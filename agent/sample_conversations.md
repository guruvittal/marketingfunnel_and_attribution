# Sample Conversational Analytics Interactions

Below are sample conversational interactions with the **Marketing-Attribution-Agent** in Gemini Enterprise grounded on `thelook_graph.eCommerce_Integrated`.

---

### Scenario 1: Customer Journey Discovery

**User Prompt:**
> "Show me the event history and conversion path for user 65516."

**Agent Reasoning & Action:**
- Identifies entity: `user_id = 65516` (Paul)
- Queries BigQuery Property Graph `thelook_graph.eCommerce_Integrated` traversing `channels -> events -> users -> orders`
- Formulates GQL query:
  ```sql
  GRAPH thelook_graph.eCommerce_Integrated
  MATCH (c:channels)<-[:TRAFFIC_SOURCE]-(ev:events)-[:TRIGGERED_BY]->(u:users WHERE u.id = 65516),
        (ev)-[inf:INFLUENCED]->(o:orders)
  RETURN u.first_name, u.last_name, c.channel_name, ev.traffic_source,
         inf.touchpoint_rank, inf.total_touchpoints, inf.linear_weight,
         o.order_id, o.status, o.num_of_item
  ORDER BY o.order_id, inf.touchpoint_rank;
  ```

**Agent Response:**
> User **Paul (ID: 65516)** has completed **2 distinct purchase orders** across a 4-touchpoint multi-channel journey:
>
> 1. **Order 81898 (Processing, 1 item)**:
>    - **Touch 1 (Rank 1 of 2)**: Adwords (`touchpoint_rank = 1`, Linear weight: 0.50)
>    - **Touch 2 (Rank 2 of 2)**: Adwords (`touchpoint_rank = 2`, Linear weight: 0.50)
>
> 2. **Order 81899 (Complete, 2 items)**:
>    - **Touch 1 (Rank 1 of 2)**: Adwords (`touchpoint_rank = 1`, Linear weight: 0.50)
>    - **Touch 2 (Rank 2 of 2)**: Adwords (`touchpoint_rank = 2`, Linear weight: 0.50)
>
> **Key Takeaway**: Paul's journeys were driven entirely via Paid Search (Adwords) touchpoints leading directly to repeat order completions.

---

### Scenario 2: Marketing Channel Profitability & ROAS

**User Prompt:**
> "Which channels delivered the highest Return on Ad Spend (ROAS) and Gross Profit?"

**Agent Reasoning & Action:**
- Runs a 4-hop traversal over `thelook_graph.eCommerce_Integrated` computing attributed revenue, COGS, gross profit, and margin %:
  ```sql
  SELECT
    channel_name,
    budget,
    total_attributed_revenue,
    gross_profit,
    ROUND(gross_profit / budget, 2) AS roas_on_budget,
    gross_margin_pct
  FROM (
    SELECT
      channel_name,
      ANY_VALUE(channel_budget) AS budget,
      ROUND(SUM(sale_price * linear_weight), 2) AS total_attributed_revenue,
      ROUND(SUM((sale_price - cost) * linear_weight), 2) AS gross_profit,
      ROUND(SUM((sale_price - cost) * linear_weight) / SUM(sale_price * linear_weight) * 100, 2) AS gross_margin_pct
    FROM GRAPH_TABLE(
      thelook_graph.eCommerce_Integrated
      MATCH (c:channels)<-[:TRAFFIC_SOURCE]-(ev:events)-[inf:INFLUENCED]->(o:orders)<-[:CONTAINS_ITEM]-(oi:order_items)-[:FOR_PRODUCT]->(p:products)
      COLUMNS (
        c.channel_name AS channel_name,
        c.weekly_budget AS channel_budget,
        oi.sale_price AS sale_price,
        p.cost AS cost,
        inf.linear_weight AS linear_weight
      )
    )
    GROUP BY channel_name
  )
  ORDER BY gross_profit DESC;
  ```

**Agent Response:**
> Here is the channel profitability and ROAS breakdown:
>
> | Marketing Channel | Weekly Budget | Attributed Revenue | Gross Profit | ROAS (on Budget) | Gross Margin % |
> | :--- | :--- | :--- | :--- | :--- | :--- |
> | **Search (Adwords)** | $50,000 | $11,607,936.56 | **$6,022,968.32** | **120.46x** | 51.89% |
> | **Social (Facebook)** | $30,000 | $3,454,924.95 | **$1,795,788.08** | **59.86x** | 51.98% |
> | **Email** | $10,000 | $3,416,664.13 | **$1,772,999.71** | **177.30x** | 51.89% |
> | **Video (YouTube)** | $25,000 | $2,306,446.54 | **$1,196,177.63** | **47.85x** | 51.86% |
> | **Organic** | $5,000 | $1,154,679.59 | **$600,767.14** | **120.15x** | 52.03% |
>
> **Strategic Insight**: Email generates the highest efficiency ratio (**177.30x ROAS**) due to its low budget and high retention, while Search (Adwords) provides the core revenue engine ($6.02M gross profit). Gross margin across all acquisition channels remains rock-solid at ~51.9%.

---

### Scenario 3: Fast Budget & Web Traffic Summary (GRAPH_EXPAND)

**User Prompt:**
> "How much web traffic and budget did we log across our marketing channels?"

**Agent Reasoning & Action:**
- Evaluates query using `GRAPH_EXPAND` on `eCommerce_Integrated` with `start_node => "events"`:
  ```sql
  SELECT
    channels_channel_name AS channel,
    AGG(channels_weekly_budget) AS weekly_budget,
    AGG(events_total_events) AS total_sessions,
    AGG(events_total_cart_additions) AS cart_additions,
    AGG(events_total_purchases) AS purchase_events
  FROM GRAPH_EXPAND("thelook_graph.eCommerce_Integrated", start_node => "events")
  GROUP BY channel
  ORDER BY total_sessions DESC;
  ```

**Agent Response:**
> Across our acquisition channels:
>
> | Channel | Weekly Budget | Total Web Sessions | Cart Additions | Purchase Events |
> | :--- | :--- | :--- | :--- | :--- |
> | **Search (Adwords)** | $50,000 | 1,697,639 | 596,569 | 181,759 |
> | **Social (Facebook)** | $30,000 | 509,491 | 179,305 | 54,640 |
> | **Email** | $10,000 | 509,305 | 178,054 | 54,604 |
> | **Video (YouTube)** | $25,000 | 338,421 | 118,521 | 36,477 |
> | **Organic** | $5,000 | 169,322 | 59,505 | 18,172 |
>
> **Cart-to-Purchase Conversion**: Adwords converts 30.5% of cart additions into purchase events, while Email and Facebook maintain identical 30.7% conversion efficiencies.
