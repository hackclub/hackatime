use axum::extract::State;
use axum::Json;
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::duration::{
    DurationRequest, DurationResponse, GroupedDurationRequest, GroupedDurationResponse,
};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::QueryFilters;

pub async fn duration(
    State(pool): State<PgPool>,
    Json(req): Json<DurationRequest>,
) -> Result<Json<DurationResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);

    let filters = QueryFilters::build_extended(
        req.user_id,
        req.user_ids.as_deref(),
        req.start_time,
        req.end_time,
        req.project.as_deref(),
        req.projects.as_deref(),
        req.category.as_deref(),
        req.coding_only,
        req.categories_exclude.as_deref(),
        req.languages.as_deref(),
        req.editors.as_deref(),
        req.operating_systems.as_deref(),
        req.categories.as_deref(),
    );

    let total = query_duration_ungrouped(&pool, filters, timeout).await?;

    Ok(Json(DurationResponse {
        total_seconds: total,
    }))
}

pub async fn duration_grouped(
    State(pool): State<PgPool>,
    Json(req): Json<GroupedDurationRequest>,
) -> Result<Json<GroupedDurationResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);

    let filters = QueryFilters::build_extended(
        req.user_id,
        req.user_ids.as_deref(),
        req.start_time,
        req.end_time,
        req.project.as_deref(),
        req.projects.as_deref(),
        None,
        req.coding_only,
        req.categories_exclude.as_deref(),
        req.languages.as_deref(),
        req.editors.as_deref(),
        req.operating_systems.as_deref(),
        req.categories.as_deref(),
    );

    let groups =
        query_duration_grouped(&pool, filters, &req.group_by, timeout, req.limit, req.min_seconds)
            .await?;

    Ok(Json(GroupedDurationResponse { groups }))
}
