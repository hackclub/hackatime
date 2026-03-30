use axum::extract::State;
use axum::Json;
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::spans::{SpansRequest, SpansResponse};
use crate::query::filters::{QueryFilterParams, QueryFilters};
use crate::query::spans::query_spans;

pub async fn spans(
    State(pool): State<PgPool>,
    Json(req): Json<SpansRequest>,
) -> Result<Json<SpansResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let include_metadata = req.include_metadata.unwrap_or(false);

    let filters = QueryFilters::build(&QueryFilterParams {
        user_id: Some(req.user_id),
        start_time: req.start_time,
        end_time: req.end_time,
        project: req.project.as_deref(),
        projects: req.projects.as_deref(),
        ..Default::default()
    });

    let spans = query_spans(&pool, filters, timeout, include_metadata).await?;

    Ok(Json(SpansResponse { spans }))
}
