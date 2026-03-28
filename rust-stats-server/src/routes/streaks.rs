use axum::extract::State;
use axum::Json;
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::streaks::{StreaksRequest, StreaksResponse};
use crate::query::streaks::query_streaks;

pub async fn streaks(
    State(pool): State<PgPool>,
    Json(req): Json<StreaksRequest>,
) -> Result<Json<StreaksResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let min_daily = req.min_daily_seconds.unwrap_or(900);

    let streaks = query_streaks(
        &pool,
        &req.user_ids,
        req.start_date.as_deref(),
        min_daily,
        timeout,
    )
    .await?;

    Ok(Json(StreaksResponse { streaks }))
}
