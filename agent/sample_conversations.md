# Sample Conversational Analytics Interactions

Below are sample conversational interactions with the **Marketing-Attribution-Agent** in Gemini Enterprise grounded on `thelook_graph.eCommerce_Integrated`.

---

### Scenario 1: Customer Journey Discovery

**User Prompt:**
> "Show me the touchpoint history and conversion path for user 65516."

**Agent Reasoning & Action:**
- Identifies entity: `user_id = 65516` (Paul)
- Queries BigQuery Property Graph `thelook_graph.eCommerce_Integrated` traversing `users -> touchpoints -> orders`
- Formulates GQL query:
  ```sql
  GRAPH thelook_graph.eCommerce_Integrated
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
  LIMIT 5;
  ```

**Agent Response:**
> User **Paul (ID: 65516)** has completed purchase orders influenced by an email nurturing sequence across **Email Marketing**:
>
> 1. **Order 81973**:
>    - **Touch 1 (Rank 1)**: `Q4_Email_VIP_Weekly_Drop` (department browse, linear weight: 0.012658)
>    - **Touch 2 (Rank 2)**: `Q4_Email_Cart_Abandonment` (product detail view, linear weight: 0.012658)
>    - **Touch 3 (Rank 3)**: `Q4_Email_VIP_Weekly_Drop` (cart review, linear weight: 0.012658)
>    - **Touch 4 (Rank 4)**: `Q4_Email_Cart_Abandonment` (department browse, linear weight: 0.012658)
>    - **Touch 5 (Rank 5)**: `Q4_Email_VIP_Weekly_Drop` (product detail view, linear weight: 0.012658)
>
> **Key Takeaway**: Paul was nurtured primarily through alternating VIP Weekly Drop and Cart Abandonment email campaigns leading up to his checkout.

---

### Scenario 2: Campaign Profitability & Margin Analysis

**User Prompt:**
> "Which marketing campaigns delivered the highest Gross Profit and Gross Margin?"

**Agent Reasoning & Action:**
- Runs a 4-hop traversal over `thelook_graph.eCommerce_Integrated` computing attributed revenue, COGS, gross profit, and gross margin %:
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

**Agent Response:**
> Here is the campaign profitability and gross margin breakdown:
>
> | Campaign Name | Channel | Attributed Revenue | Attributed COGS | Gross Profit | Gross Margin % |
> | :--- | :--- | :--- | :--- | :--- | :--- |
> | `Q4_Email_Cart_Abandonment` | Email Marketing | $1,843,706.49 | $885,737.40 | **$957,969.09** | 51.96% |
> | `Q4_Email_VIP_Weekly_Drop` | Email Marketing | $1,843,829.27 | $885,979.08 | **$957,850.19** | 51.95% |
> | `Q4_Search_Brand_Electronics` | Paid Search | $1,202,490.39 | $578,564.40 | **$623,926.00** | 51.89% |
> | `Q4_Search_Generic_Audio` | Paid Search | $1,201,800.30 | $578,539.58 | **$623,260.72** | 51.86% |
> | `Q4_YouTube_Video_Awareness` | Video | $791,187.97 | $380,320.71 | **$410,867.26** | 51.93% |
> | `Organic_Search_SEO` | Organic | $409,566.57 | $196,346.08 | **$213,220.49** | 52.06% |
> | `Q4_Meta_IG_Retargeting` | Paid Social | $401,409.26 | $193,276.98 | **$208,132.28** | 51.85% |
> | `Q4_TikTok_Prospecting_GenZ` | Paid Social | $399,775.09 | $192,436.82 | **$207,338.27** | 51.86% |
>
> **Strategic Insight**: Email campaigns deliver the highest total profit contribution (~$958K each). Gross margin across all acquisition campaigns remains remarkably stable at ~51.9%.

---

### Scenario 3: Executive Marketing Scorecard (GRAPH_EXPAND)

**User Prompt:**
> "Show me the ad spend, budget, clicks, and effective CPC across all Q4 campaigns."

**Agent Reasoning & Action:**
- Evaluates query using `GRAPH_EXPAND` on `eCommerce_Integrated` with `start_node => "touchpoints"`:
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

**Agent Response:**
> Across our 8 marketing campaigns:
>
> | Channel | Campaign Name | Total Budget | Total Clicks | Unique Reach | Total Ad Spend | Remaining Budget | Effective Avg CPC |
> | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
> | **Paid Search** | `Q4_Search_Generic_Audio` | $1,500,000 | 362,497 | 39,564 | $1,370,238.66 | $129,761.34 | **$3.78** |
> | **Paid Search** | `Q4_Search_Brand_Electronics` | $1,100,000 | 362,605 | 39,564 | $957,277.20 | $142,722.80 | **$2.64** |
> | **Paid Social** | `Q4_Meta_IG_Retargeting` | $250,000 | 120,597 | 16,039 | $223,104.45 | $26,895.55 | **$1.85** |
> | **Video** | `Q4_YouTube_Video_Awareness` | $220,000 | 241,729 | 16,114 | $205,469.65 | $14,530.35 | **$0.85** |
> | **Paid Social** | `Q4_TikTok_Prospecting_GenZ` | $150,000 | 120,740 | 16,039 | $119,532.60 | $30,467.40 | **$0.99** |
> | **Email Marketing** | `Q4_Email_Cart_Abandonment` | $75,000 | 546,038 | 52,216 | $65,524.56 | $9,475.44 | **$0.12** |
> | **Email Marketing** | `Q4_Email_VIP_Weekly_Drop` | $60,000 | 545,691 | 52,216 | $54,569.10 | $5,430.90 | **$0.10** |
> | **Organic** | `Organic_Search_SEO` | $25,000 | 121,058 | 8,550 | $0.00 | $25,000.00 | **$0.00** |
>
> **Spend Pacing**: Paid Search campaigns have consumed over 87% of allocated budgets at higher CPCs ($2.64 - $3.78), while Email campaigns deliver high reach (>52K unique users) at low cost ($0.10 - $0.12 CPC).
