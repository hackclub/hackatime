use axum::extract::State;
use axum::Json;
use chrono::{Duration, Utc};
use sqlx::postgres::PgArguments;
use sqlx::{Arguments, PgPool};

use crate::error::AppError;
use crate::models::leaderboard::{LeaderboardEntry, LeaderboardRequest, LeaderboardResponse};
use crate::query::duration::query_user_durations;
use crate::query::filters::{QueryFilterParams, QueryFilters};
use crate::query::streaks::query_streaks;

const TRUST_LEVEL_RED: i32 = 1;

fn eligible_users_query(
    requested_user_ids: Option<&[i64]>,
    exclude_red: bool,
    require_github: bool,
) -> (String, PgArguments) {
    let mut conditions = Vec::new();
    let mut args = PgArguments::default();
    let mut next_param = 1;

    if let Some(user_ids) = requested_user_ids {
        let placeholders = user_ids
            .iter()
            .map(|user_id| {
                let placeholder = format!("${next_param}");
                next_param += 1;
                let _ = args.add(*user_id);
                placeholder
            })
            .collect::<Vec<_>>();

        conditions.push(format!("id IN ({})", placeholders.join(", ")));
    }

    if exclude_red {
        conditions.push(format!("(trust_level IS NULL OR trust_level != {TRUST_LEVEL_RED})"));
    }

    if require_github {
        conditions.push("github_uid IS NOT NULL".to_string());
        conditions.push("github_uid != ''".to_string());
    }

    let where_clause = if conditions.is_empty() {
        String::new()
    } else {
        format!(" WHERE {}", conditions.join(" AND "))
    };

    (format!("SELECT id FROM users{where_clause}"), args)
}

async fn eligible_user_ids(
    pool: &PgPool,
    requested_user_ids: Option<&[i64]>,
    exclude_red: bool,
    require_github: bool,
) -> Result<Vec<i64>, AppError> {
    if matches!(requested_user_ids, Some([])) {
        return Ok(Vec::new());
    }

    let (sql, args) = eligible_users_query(requested_user_ids, exclude_red, require_github);
    let rows: Vec<(i64,)> = sqlx::query_as_with(&sql, args).fetch_all(pool).await?;

    Ok(rows.into_iter().map(|(id,)| id).collect())
}

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

    let user_ids =
        eligible_user_ids(&pool, req.user_ids.as_deref(), exclude_red, require_github).await?;

    if user_ids.is_empty() {
        return Ok(Json(LeaderboardResponse { entries: vec![] }));
    }

    let filters = QueryFilters::build(&QueryFilterParams {
        user_ids: Some(&user_ids),
        start_time: Some(req.start_time as f64),
        end_time: Some(req.end_time as f64),
        coding_only: if coding_only { Some(true) } else { None },
        ..Default::default()
    });

    let durations = query_user_durations(&pool, filters, timeout, None, Some(min_seconds)).await?;

    let qualifying_ids: Vec<i64> = durations.iter().map(|entry| entry.user_id).collect();
    let streak_start_date = Some((Utc::now() - Duration::days(30)).date_naive());

    let streaks_map = if include_streaks && !qualifying_ids.is_empty() {
        query_streaks(&pool, &qualifying_ids, streak_start_date, 900, timeout)
            .await?
            .into_iter()
            .map(|entry| (entry.user_id, entry.streak_count))
            .collect()
    } else {
        std::collections::HashMap::new()
    };

    let mut entries: Vec<LeaderboardEntry> = durations
        .into_iter()
        .map(|entry| {
            let streak_count = streaks_map.get(&entry.user_id).copied().unwrap_or_default();
            LeaderboardEntry {
                user_id: entry.user_id,
                total_seconds: entry.total_seconds,
                streak_count,
            }
        })
        .collect();

    entries.sort_by(|a, b| b.total_seconds.cmp(&a.total_seconds));

    Ok(Json(LeaderboardResponse { entries }))
}

#[cfg(test)]
mod tests {
    use super::eligible_users_query;

    #[test]
    fn filters_requested_ids_through_github_and_trust_checks() {
        let (sql, _args) = eligible_users_query(Some(&[12, 34]), true, true);

        assert_eq!(
            sql,
            "SELECT id FROM users WHERE id IN ($1, $2) AND (trust_level IS NULL OR trust_level != 1) AND github_uid IS NOT NULL AND github_uid != ''"
        );
    }

    #[test]
    fn omits_where_clause_when_no_filters_are_requested() {
        let (sql, _args) = eligible_users_query(None, false, false);

        assert_eq!(sql, "SELECT id FROM users");
    }
}
