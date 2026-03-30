use axum::extract::State;
use axum::Json;
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::duration::{
    DurationRequest, DurationResponse, GroupedDurationRequest, GroupedDurationResponse,
};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::{QueryFilterParams, QueryFilters};

fn duration_filters(req: &DurationRequest) -> QueryFilterParams<'_> {
    QueryFilterParams {
        user_id: req.user_id,
        user_ids: req.user_ids.as_deref(),
        start_time: req.start_time,
        end_time: req.end_time,
        project: req.project.as_deref(),
        projects: req.projects.as_deref(),
        category: req.category.as_deref(),
        coding_only: req.coding_only,
        categories_exclude: req.categories_exclude.as_deref(),
        languages: req.languages.as_deref(),
        editors: req.editors.as_deref(),
        operating_systems: req.operating_systems.as_deref(),
        categories: req.categories.as_deref(),
    }
}

pub async fn duration(
    State(pool): State<PgPool>,
    Json(req): Json<DurationRequest>,
) -> Result<Json<DurationResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let filters = QueryFilters::build(&duration_filters(&req));

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

    let filters = QueryFilters::build(&QueryFilterParams {
        user_id: req.user_id,
        user_ids: req.user_ids.as_deref(),
        start_time: req.start_time,
        end_time: req.end_time,
        project: req.project.as_deref(),
        projects: req.projects.as_deref(),
        coding_only: req.coding_only,
        categories_exclude: req.categories_exclude.as_deref(),
        languages: req.languages.as_deref(),
        editors: req.editors.as_deref(),
        operating_systems: req.operating_systems.as_deref(),
        categories: req.categories.as_deref(),
        ..Default::default()
    });

    let groups = query_duration_grouped(
        &pool,
        filters,
        req.group_by,
        timeout,
        req.limit,
        req.min_seconds,
    )
    .await?;

    Ok(Json(GroupedDurationResponse { groups }))
}
