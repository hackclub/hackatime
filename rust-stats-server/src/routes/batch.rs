use axum::extract::State;
use axum::Json;
use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::batch::{BatchQuery, BatchRequest, BatchResponse, BatchResult};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::{QueryFilterParams, QueryFilters};

pub async fn batch(
    State(pool): State<PgPool>,
    Json(req): Json<BatchRequest>,
) -> Result<Json<BatchResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let mut results = HashMap::new();

    for query in &req.queries {
        let filters = QueryFilters::build(&QueryFilterParams {
            user_id: Some(req.user_id),
            start_time: Some(req.start_time),
            end_time: Some(req.end_time),
            project: query.filters().project.as_deref(),
            projects: query.filters().projects.as_deref(),
            coding_only: query.filters().coding_only,
            languages: query.filters().languages.as_deref(),
            editors: query.filters().editors.as_deref(),
            operating_systems: query.filters().operating_systems.as_deref(),
            categories: query.filters().categories.as_deref(),
            ..Default::default()
        });

        let value = match query {
            BatchQuery::Ungrouped { .. } => {
                let total = query_duration_ungrouped(&pool, filters, timeout).await?;
                BatchResult::Ungrouped {
                    total_seconds: total,
                }
            }
            BatchQuery::Grouped {
                group_by,
                limit,
                min_seconds,
                ..
            } => {
                let groups = query_duration_grouped(
                    &pool,
                    filters,
                    *group_by,
                    timeout,
                    *limit,
                    *min_seconds,
                )
                .await?;
                BatchResult::Grouped { groups }
            }
        };

        results.insert(query.id().to_owned(), value);
    }

    Ok(Json(BatchResponse { results }))
}
