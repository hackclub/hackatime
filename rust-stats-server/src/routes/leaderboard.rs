use axum::extract::State;
use axum::Json;
use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::leaderboard::{LeaderboardEntry, LeaderboardRequest, LeaderboardResponse};
use crate::query::duration::query_duration_grouped;
use crate::query::filters::{QueryFilterParams, QueryFilters};
use crate::query::streaks::query_streaks;

pub async fn leaderboard_compute(
    State(pool): State<PgPool>,
    Json(req): Json<LeaderboardRequest>,
) -> Result<Json<LeaderboardResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let min_seconds = req.min_seconds.unwrap_or(60);
    let coding_only = req.coding_only.unwrap_or(true);
    let include_streaks = req.include_streaks.unwrap_or(true);
    let exclude_red = req.exclude_trust_level_red.unwrap_or(true);
    let require_github = req.require_github_uid.unwrap_or(true);

    // Get eligible user IDs if not provided
    let user_ids = if let Some(ref ids) = req.user_ids {
        ids.clone()
    } else {
        // Query eligible users from the database
        let mut conditions = Vec::new();

        if exclude_red {
            // trust_level red = 2
            conditions.push("(trust_level IS NULL OR trust_level != 2)".to_string());
        }
        if require_github {
            conditions.push("github_uid IS NOT NULL".to_string());
            conditions.push("github_uid != ''".to_string());
        }

        let where_clause = if conditions.is_empty() {
            String::new()
        } else {
            format!("WHERE {}", conditions.join(" AND "))
        };

        let sql = format!("SELECT id FROM users {}", where_clause);
        let rows: Vec<(i64,)> = sqlx::query_as(&sql).fetch_all(&pool).await?;
        rows.into_iter().map(|(id,)| id).collect()
    };

    if user_ids.is_empty() {
        return Ok(Json(LeaderboardResponse { entries: vec![] }));
    }

    // Compute per-user durations
    let filters = QueryFilters::build(QueryFilterParams {
        user_ids: Some(&user_ids),
        start_time: Some(req.start_time),
        end_time: Some(req.end_time),
        coding_only: if coding_only { Some(true) } else { None },
        ..Default::default()
    });

    let durations =
        query_duration_grouped(&pool, filters, "user_id", timeout, None, Some(min_seconds)).await?;

    // Get qualifying user IDs
    let qualifying_ids: Vec<i64> = durations
        .keys()
        .filter_map(|k| k.parse::<i64>().ok())
        .collect();

    // Compute streaks if requested
    let streaks_map = if include_streaks && !qualifying_ids.is_empty() {
        query_streaks(&pool, &qualifying_ids, None, 900, timeout).await?
    } else {
        HashMap::new()
    };

    // Build entries sorted by total_seconds desc
    let mut entries: Vec<LeaderboardEntry> = durations
        .into_iter()
        .filter_map(|(uid_str, total)| {
            let uid = uid_str.parse::<i64>().ok()?;
            let streak = streaks_map.get(&uid_str).copied().unwrap_or(0);
            Some(LeaderboardEntry {
                user_id: uid,
                total_seconds: total,
                streak_count: streak,
            })
        })
        .collect();

    entries.sort_by(|a, b| b.total_seconds.cmp(&a.total_seconds));

    Ok(Json(LeaderboardResponse { entries }))
}
