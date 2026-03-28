use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;

use super::filters::QueryFilters;

const ALLOWED_GROUP_COLUMNS: &[&str] = &[
    "project",
    "language",
    "editor",
    "operating_system",
    "user_id",
    "category",
    "machine",
];

pub async fn query_duration_ungrouped(
    pool: &PgPool,
    filters: QueryFilters,
    timeout: f64,
) -> Result<i64, AppError> {
    let sql = format!(
        "SELECT COALESCE(SUM(diff), 0)::bigint as total \
         FROM (SELECT CASE \
           WHEN LAG(\"time\") OVER (ORDER BY \"time\") IS NULL THEN 0 \
           ELSE LEAST(\"time\" - LAG(\"time\") OVER (ORDER BY \"time\"), {timeout}) \
         END as diff \
         FROM heartbeats WHERE {where_clause}) AS diffs",
        timeout = timeout,
        where_clause = filters.where_clause
    );

    let row: (i64,) = sqlx::query_as_with(&sql, filters.args)
        .fetch_one(pool)
        .await?;

    Ok(row.0)
}

pub async fn query_duration_grouped(
    pool: &PgPool,
    filters: QueryFilters,
    group_by: &str,
    timeout: f64,
    limit: Option<i64>,
    min_seconds: Option<i64>,
) -> Result<HashMap<String, i64>, AppError> {
    if !ALLOWED_GROUP_COLUMNS.contains(&group_by) {
        return Err(AppError::BadRequest(format!(
            "Invalid group_by column: {}",
            group_by
        )));
    }

    let col_expr = if group_by == "user_id" {
        "CAST(user_id AS TEXT)".to_string()
    } else {
        format!("\"{}\"", group_by)
    };

    let mut sql = format!(
        "SELECT grouped_col, COALESCE(SUM(diff), 0)::bigint as duration \
         FROM (SELECT {col_expr} as grouped_col, CASE \
           WHEN LAG(\"time\") OVER (PARTITION BY {col_expr} ORDER BY \"time\") IS NULL THEN 0 \
           ELSE LEAST(\"time\" - LAG(\"time\") OVER (PARTITION BY {col_expr} ORDER BY \"time\"), {timeout}) \
         END as diff \
         FROM heartbeats WHERE {where_clause}) AS diffs \
         GROUP BY grouped_col",
        col_expr = col_expr,
        timeout = timeout,
        where_clause = filters.where_clause
    );

    if let Some(min) = min_seconds {
        sql.push_str(&format!(" HAVING COALESCE(SUM(diff), 0) >= {}", min));
    }

    sql.push_str(" ORDER BY duration DESC");

    if let Some(lim) = limit {
        sql.push_str(&format!(" LIMIT {}", lim));
    }

    let rows: Vec<(Option<String>, i64)> = sqlx::query_as_with(&sql, filters.args)
        .fetch_all(pool)
        .await?;

    let mut map = HashMap::new();
    for (key, val) in rows {
        if let Some(k) = key {
            map.insert(k, val);
        }
    }
    Ok(map)
}
