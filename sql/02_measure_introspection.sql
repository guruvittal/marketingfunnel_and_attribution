-- ============================================================================
-- Step 5: Inspect Declared Semantic Measures via INFORMATION_SCHEMA
-- Graph: thelook_graph.eCommerce_Integrated
-- Description: Dynamically query BigQuery metadata to discover all declared
--              MEASURE definitions, target node tables, expressions, and types.
-- ============================================================================

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
