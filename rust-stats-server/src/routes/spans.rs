use axum::extract::State;
use axum::Json;
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::spans::{SpansRequest, SpansResponse};
use crate::query::filters::QueryFilters;
use crate::query::spans::query_spans;

pub async fn spans(
    State(pool): State<PgPool>,
    Json(req): Json<SpansRequest>,
) -> Result<Json<SpansResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let include_metadata = req.include_metadata.unwrap_or(false);

    let filters = QueryFilters::build(
        Some(req.user_id),
        None,
        req.start_time,
        req.end_time,
        req.project.as_deref(),
        req.projects.as_deref(),
        None,
        None,
        None,
    );

    let spans = query_spans(&pool, filters, timeout, include_metadata).await?;

    Ok(Json(SpansResponse { spans }))
}
