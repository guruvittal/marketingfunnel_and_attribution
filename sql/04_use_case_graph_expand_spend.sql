-- ============================================================================
-- Use Case 1: Campaign Budget vs. Actual Ad Spend Rollup (GRAPH_EXPAND)
-- Graph: eCommerce_Integrated (Unified Single Graph)
-- Operator: Standard GoogleSQL GRAPH_EXPAND with start_node => "touchpoints" & AGG()
-- Scenario: Executive & BI rollup of campaign budgets against touchpoint ad spend and click volume
--           without Cartesian budget explosion, extracting the marketing branch from the master mesh graph.
-- ============================================================================

SELECT
    campaigns_channel AS channel,
    campaigns_campaign_name AS campaign_name,
    AGG(campaigns_total_campaign_budget) AS total_budget,
    AGG(touchpoints_total_clicks) AS total_clicks,
    ROUND(AGG(touchpoints_total_ad_spend), 2) AS total_ad_spend,
    ROUND(AGG(campaigns_total_campaign_budget) - AGG(touchpoints_total_ad_spend), 2) AS remaining_budget,
    ROUND(AGG(touchpoints_total_ad_spend) / NULLIF(AGG(touchpoints_total_clicks), 0), 2) AS effective_avg_cpc
FROM GRAPH_EXPAND("eRetail_marketing.eCommerce_Integrated", start_node => "touchpoints")
GROUP BY channel, campaign_name
ORDER BY total_ad_spend DESC;
