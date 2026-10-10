# Sample Conversational Analytics Interactions

Below are sample conversational interactions with the **Marketing-Attribution-Agent** in Gemini Enterprise.

---

### Scenario 1: Customer Journey Discovery

**User Prompt:**
> "Show me the touchpoint history and conversion path for customer CUST_0888."

**Agent Reasoning & Action:**
- Identifies entity: `customer_id = 'CUST_0888'`
- Queries BigQuery Property Graph `eCommerce_Integrated` traversing `customers -> touchpoints -> campaigns -> orders`
- Formulates GQL query:
  ```sql
  GRAPH `eRetail_marketing.eCommerce_Integrated`
  MATCH (c:campaigns)<-[g:GENERATED_BY]-(tp:touchpoints)-[i:INFLUENCED]->(o:orders),
        (cust:customers WHERE cust.customer_id = 'CUST_0888')-[e:ENGAGED_WITH]->(tp)
  RETURN cust.customer_id, c.campaign_name, c.channel, tp.touchpoint_id, tp.device_type, tp.cpc_cost, i.attribution_weight, i.touchpoint_rank, o.order_id
  ORDER BY o.order_id, i.touchpoint_rank;
  ```

**Agent Response:**
> Customer **CUST_0888** has completed **2 distinct purchase orders** across a 6-touchpoint multi-channel journey:
>
> 1. **Order ORD_0002 ($359.98)**:
>    - **Touch 1 (Rank 1)**: Email Marketing (*Q4_Email_Cart_Abandonment*, Mobile, $0.18 CPC) — 25% Attribution
>    - **Touch 2 (Rank 2)**: Paid Social (*Q4_Meta_IG_Retargeting*, Mobile, $1.65 CPC) — 25% Attribution
>    - **Touch 3 (Rank 3)**: Email Marketing (*Q4_Email_Cart_Abandonment*, Desktop, $0.16 CPC) — 25% Attribution
>    - **Touch 4 (Rank 4)**: Paid Social (*Q4_TikTok_Prospecting_GenZ*, Desktop, $0.98 CPC) — 25% Attribution
>
> 2. **Order ORD_0486 ($179.98)**:
>    - **Touch 1 (Rank 1)**: Paid Search (*Q4_Search_Generic_Audio*, Mobile, $4.72 CPC) — 50% Attribution
>    - **Touch 2 (Rank 2)**: Paid Search (*Q4_Search_Generic_Audio*, Mobile, $4.83 CPC) — 50% Attribution
>
> **Key Takeaway**: Customer `CUST_0888` converts across both Paid Social discovery and Paid Search intent, with high responsiveness to automated Cart Abandonment emails.

---

### Scenario 2: Campaign ROAS Benchmarking

**User Prompt:**
> "Which campaigns delivered the highest Return on Ad Spend (ROAS) against our targets?"

**Agent Reasoning & Action:**
- Runs `GRAPH_TABLE(...)` aggregation over `eCommerce_Integrated`, measuring budget vs attributed net revenue and gross profit.

**Agent Response:**
> Here is the performance breakdown for Q4 Marketing Campaigns:
>
> | Channel | Campaign Name | Weekly Budget | Target ROAS | Attributed Revenue | Actual ROAS | Status |
> | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
> | **Email Marketing** | `Q4_Email_Cart_Abandonment` | $625 | 8.0x | $79,468.16 | **127.15x** | ✅ Exceeded |
> | **Email Marketing** | `Q4_Email_VIP_Weekly_Drop` | $875 | 6.5x | $85,119.09 | **97.28x** | ✅ Exceeded |
> | **Affiliate** | `Q4_Affiliate_TechReview_Blogs` | $2,000 | 5.0x | $87,625.08 | **43.81x** | ✅ Exceeded |
> | **Affiliate** | `Q4_Affiliate_Coupon_Sites` | $1,500 | 4.0x | $60,884.49 | **40.59x** | ✅ Exceeded |
> | **Paid Search** | `Q4_Search_Brand_Electronics` | $3,000 | 4.5x | $79,053.28 | **26.35x** | ✅ Exceeded |
> | **Paid Social** | `Q4_Meta_IG_Retargeting` | $3,750 | 3.5x | $73,340.26 | **19.56x** | ✅ Exceeded |
> | **Paid Search** | `Q4_Search_Generic_Audio` | $4,500 | 3.0x | $69,880.90 | **15.53x** | ✅ Exceeded |
> | **Paid Social** | `Q4_TikTok_Prospecting_GenZ` | $5,500 | 2.2x | $75,214.12 | **13.68x** | ✅ Exceeded |
>
> **Strategic Insight**: Retention and retargeting channels (Email Cart Abandonment and Tech Review Affiliates) generated the highest ROAS multipliers, while Top-of-Funnel paid social (TikTok) provided broad prospecting reach to feed downstream retargeting pipelines.

---

### Scenario 3: Product Category Campaign Influence

**User Prompt:**
> "Which marketing channels are driving the most revenue for our Audio and Accessories products?"

**Agent Reasoning & Action:**
- Queries `eCommerce_Integrated` traversing `campaigns -> touchpoints -> orders -> order_items -> products` using `GRAPH_TABLE`:
  ```sql
  SELECT
      prod.category AS category,
      prod.product_name AS product_name,
      c.channel AS channel,
      c.campaign_name AS campaign_name,
      COUNT(DISTINCT o.order_id) AS orders_count,
      ROUND(SUM(CAST(oi.net_revenue AS FLOAT64) * i.attribution_weight), 2) AS attributed_sales,
      ROUND(AVG(i.days_to_convert), 1) AS avg_days_to_convert
  FROM GRAPH_TABLE(
    `eRetail_marketing.eCommerce_Integrated`
    MATCH (c:campaigns)<-[g:GENERATED_BY]-(tp:touchpoints)-[i:INFLUENCED]->(o:orders)<-[b:BELONGS_TO]-(oi:order_items)-[p:IS_PRODUCT]->(prod:products)
    COLUMNS (
      c.campaign_name AS campaign_name,
      c.channel AS channel,
      prod.category AS category,
      prod.product_name AS product_name,
      o.order_id AS order_id,
      oi.net_revenue AS net_revenue,
      i.attribution_weight AS attribution_weight,
      i.days_to_convert AS days_to_convert
    )
  )
  WHERE prod.category IN ('Audio', 'Accessories')
  GROUP BY category, product_name, channel, campaign_name
  ORDER BY attributed_sales DESC
  LIMIT 5;
  ```

**Agent Response:**
> Here are the top channel drivers for **Audio** and **Accessories**:
>
> 1. **Noise-Canceling Headphones (Audio)**:
>    - Primary driver: **Paid Search** (*Q4_Search_Generic_Audio*) driving high-intent conversions with an average conversion cycle of **3.1 days**.
> 2. **Surround Soundbar 5.1 (Audio)**:
>    - Primary driver: **Affiliate Marketing** (*Q4_Affiliate_TechReview_Blogs*) driving high-ticket sales through detailed editorial reviews.
> 3. **RGB Mechanical Keyboard (Accessories)**:
>    - Primary driver: **Paid Social** (*Q4_Meta_IG_Retargeting*) delivering the fastest conversion velocity (**2.3 days**).
>
> **Strategic Recommendation**: Increase budget allocation to Tech Review Affiliates for premium Audio products, while leveraging Meta Instagram retargeting for impulse-driven Gaming Accessories.

---

### Scenario 4: Fast Budget & Ad Spend Summary (GRAPH_EXPAND)

**User Prompt:**
> "How much ad spend and clicks did we log across our paid search and social campaigns, and what is our remaining budget?"

**Agent Reasoning & Action:**
- Evaluates query using `GRAPH_EXPAND` on `eCommerce_Integrated` with `start_node => "touchpoints"` for rapid, on-demand rollup:
  ```sql
  SELECT
    campaigns_channel AS channel,
    campaigns_campaign_name AS campaign_name,
    AGG(campaigns_total_campaign_budget) AS budget,
    AGG(touchpoints_total_clicks) AS clicks,
    ROUND(AGG(touchpoints_total_ad_spend), 2) AS ad_spend,
    ROUND(AGG(campaigns_total_campaign_budget) - AGG(touchpoints_total_ad_spend), 2) AS remaining_budget
  FROM GRAPH_EXPAND("eRetail_marketing.eCommerce_Integrated", start_node => "touchpoints")
  WHERE campaigns_channel IN ('Paid Search', 'Paid Social')
  GROUP BY channel, campaign_name
  ORDER BY ad_spend DESC;
  ```

**Agent Response:**
> Across Paid Search and Paid Social:
>
> | Channel | Campaign | Budget | Actual Spend | Clicks | Remaining Budget |
> | :--- | :--- | :--- | :--- | :--- | :--- |
> | Paid Search | `Q4_Search_Generic_Audio` | $4,500 | $2,277.97 | 603 | $2,222.03 |
> | Paid Search | `Q4_Search_Brand_Electronics` | $3,000 | $1,711.55 | 649 | $1,288.45 |
> | Paid Social | `Q4_Meta_IG_Retargeting` | $3,750 | $1,251.24 | 676 | $2,498.76 |
> | Paid Social | `Q4_TikTok_Prospecting_GenZ` | $5,500 | $588.63 | 592 | $4,911.37 |
>
> **Budget Insight**: TikTok prospecting has $4,911.37 remaining budget with a low $0.99 CPC, indicating significant headroom for scale.
