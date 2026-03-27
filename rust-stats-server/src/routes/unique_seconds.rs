use axum::extract::State;
use axum::Json;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;

use crate::error::AppError;
use crate::query::filters::QueryFilters;

#[derive(Debug, Deserialize)]
pub struct UniqueSecondsRequest {
    pub user_id: i64,
    pub start_time: f64,
    pub end_time: f64,
    pub projects: Option<Vec<String>>,
    pub coding_only: Option<bool>,
    pub gap_threshold_seconds: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct UniqueSecondsResponse {
    pub unique_seconds: i64,
}

pub async fn unique_seconds(
    State(pool): State<PgPool>,
    Json(req): Json<UniqueSecondsRequest>,
) -> Result<Json<UniqueSecondsResponse>, AppError> {
    let threshold = req.gap_threshold_seconds.unwrap_or(120.0);

    let filters = QueryFilters::build(
        Some(req.user_id),
        None,
        Some(req.start_time),
        Some(req.end_time),
        None,
        req.projects.as_deref(),
        None,
        req.coding_only,
        None,
    );

    // Get all timestamps ordered
    let sql = format!(
        "SELECT time FROM heartbeats WHERE {} ORDER BY time",
        filters.where_clause
    );

    let rows: Vec<(f64,)> = sqlx::query_as_with(&sql, filters.args)
        .fetch_all(&pool)
        .await?;

    // Walk consecutive pairs and sum gaps within threshold
    let mut total: f64 = 0.0;
    for window in rows.windows(2) {
        let gap = window[1].0 - window[0].0;
        if gap > 0.0 && gap <= threshold {
            total += gap;
        }
    }

    Ok(Json(UniqueSecondsResponse {
        unique_seconds: total as i64,
    }))
}
