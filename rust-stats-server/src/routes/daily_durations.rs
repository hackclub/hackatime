use axum::extract::State;
use axum::Json;
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::query::filters::QueryFilters;

#[derive(Debug, Deserialize)]
pub struct DailyDurationsRequest {
    pub user_id: i64,
    pub timezone: String,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub timeout_seconds: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct DailyDurationsResponse {
    pub durations: HashMap<String, i64>,
}

pub async fn daily_durations(
    State(pool): State<PgPool>,
    Json(req): Json<DailyDurationsRequest>,
) -> Result<Json<DailyDurationsResponse>, AppError> {
    let tz_str = validate_timezone(&req.timezone);
    let timeout = req.timeout_seconds.unwrap_or(120.0);

    let start_time = req.start_date.as_deref().and_then(|d| {
        NaiveDate::parse_from_str(d, "%Y-%m-%d")
            .ok()
            .map(|nd| nd.and_hms_opt(0, 0, 0).unwrap().and_utc().timestamp() as f64)
    });
    let end_time = req.end_date.as_deref().and_then(|d| {
        NaiveDate::parse_from_str(d, "%Y-%m-%d")
            .ok()
            .map(|nd| nd.and_hms_opt(23, 59, 59).unwrap().and_utc().timestamp() as f64)
    });

    let filters = QueryFilters::build(
        Some(req.user_id),
        None,
        start_time,
        end_time,
        None,
        None,
        None,
        None,
        None,
    );

    let date_expr = format!(
        "DATE_TRUNC('day', to_timestamp(\"time\") AT TIME ZONE '{}')",
        tz_str
    );

    let sql = format!(
        "SELECT day_group::date::text as day, COALESCE(SUM(diff), 0)::bigint as duration \
         FROM (SELECT {date_expr} as day_group, CASE \
           WHEN LAG(\"time\") OVER (PARTITION BY {date_expr} ORDER BY \"time\") IS NULL THEN 0 \
           ELSE LEAST(\"time\" - LAG(\"time\") OVER (PARTITION BY {date_expr} ORDER BY \"time\"), {timeout}) \
         END as diff FROM heartbeats WHERE {where_clause}) AS diffs \
         GROUP BY day \
         ORDER BY day",
        date_expr = date_expr,
        timeout = timeout,
        where_clause = filters.where_clause
    );

    let rows: Vec<(Option<String>, i64)> = sqlx::query_as_with(&sql, filters.args)
        .fetch_all(&pool)
        .await?;

    let mut durations = HashMap::new();
    for (day, dur) in rows {
        if let Some(d) = day {
            durations.insert(d, dur);
        }
    }

    Ok(Json(DailyDurationsResponse { durations }))
}

fn validate_timezone(tz: &str) -> String {
    match tz.parse::<chrono_tz::Tz>() {
        Ok(_) => tz.to_string(),
        Err(_) => "UTC".to_string(),
    }
}
