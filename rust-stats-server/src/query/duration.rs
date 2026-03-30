use std::fmt::Write;

use sqlx::PgPool;

use crate::error::AppError;
use crate::models::common::{GroupBy, GroupedDurationEntry, UserDurationEntry};

use super::filters::QueryFilters;

fn into_grouped_duration_entries(rows: Vec<(Option<String>, i64)>) -> Vec<GroupedDurationEntry> {
    rows.into_iter()
        .map(|(name, total_seconds)| GroupedDurationEntry {
            name: name.unwrap_or_default(),
            total_seconds,
        })
        .collect()
}

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
    group_by: GroupBy,
    timeout: f64,
    limit: Option<i64>,
    min_seconds: Option<i64>,
) -> Result<Vec<GroupedDurationEntry>, AppError> {
    let column = group_by.column();
    let grouped_column = if matches!(group_by, GroupBy::UserId) {
        "CAST(user_id AS TEXT)".to_string()
    } else {
        format!("\"{column}\"")
    };

    let mut sql = format!(
        "SELECT grouped_col, COALESCE(SUM(diff), 0)::bigint as duration \
         FROM (SELECT {grouped_column} as grouped_col, CASE \
           WHEN LAG(\"time\") OVER (PARTITION BY {grouped_column} ORDER BY \"time\") IS NULL THEN 0 \
           ELSE LEAST(\"time\" - LAG(\"time\") OVER (PARTITION BY {grouped_column} ORDER BY \"time\"), {timeout}) \
         END as diff \
         FROM heartbeats WHERE {where_clause}) AS diffs \
         GROUP BY grouped_col",
        where_clause = filters.where_clause
    );

    if let Some(min_seconds) = min_seconds {
        let _ = write!(sql, " HAVING COALESCE(SUM(diff), 0) >= {min_seconds}");
    }

    sql.push_str(" ORDER BY duration DESC");

    if let Some(limit) = limit {
        let _ = write!(sql, " LIMIT {limit}");
    }

    let rows: Vec<(Option<String>, i64)> = sqlx::query_as_with(&sql, filters.args)
        .fetch_all(pool)
        .await?;

    Ok(into_grouped_duration_entries(rows))
}

pub async fn query_user_durations(
    pool: &PgPool,
    filters: QueryFilters,
    timeout: f64,
    limit: Option<i64>,
    min_seconds: Option<i64>,
) -> Result<Vec<UserDurationEntry>, AppError> {
    let durations =
        query_duration_grouped(pool, filters, GroupBy::UserId, timeout, limit, min_seconds)
            .await?
            .into_iter()
            .filter_map(|entry| {
                entry
                    .name
                    .parse::<i64>()
                    .ok()
                    .map(|user_id| UserDurationEntry {
                        user_id,
                        total_seconds: entry.total_seconds,
                    })
            })
            .collect();

    Ok(durations)
}

#[cfg(test)]
mod tests {
    use crate::models::common::GroupedDurationEntry;

    use super::into_grouped_duration_entries;

    #[test]
    fn keeps_an_empty_bucket_for_null_group_names() {
        let rows = vec![(None, 90), (Some("Rust".to_string()), 30)];

        assert_eq!(
            into_grouped_duration_entries(rows),
            vec![
                GroupedDurationEntry {
                    name: String::new(),
                    total_seconds: 90,
                },
                GroupedDurationEntry {
                    name: "Rust".to_string(),
                    total_seconds: 30,
                },
            ]
        );
    }
}
