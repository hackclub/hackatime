use axum::extract::State;
use axum::Json;
use serde_json::{json, Value};
use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::batch::{BatchRequest, BatchResponse};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::{QueryFilterParams, QueryFilters};

pub async fn batch(
    State(pool): State<PgPool>,
    Json(req): Json<BatchRequest>,
) -> Result<Json<BatchResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let mut results = HashMap::new();

    for query in &req.queries {
        let filters = QueryFilters::build(QueryFilterParams {
            user_id: Some(req.user_id),
            start_time: Some(req.start_time),
            end_time: Some(req.end_time),
            project: query.project.as_deref(),
            projects: query.projects.as_deref(),
            coding_only: query.coding_only,
            languages: query.languages.as_deref(),
            editors: query.editors.as_deref(),
            operating_systems: query.operating_systems.as_deref(),
            categories: query.categories.as_deref(),
            ..Default::default()
        });

        let value: Value = match query.query_type.as_str() {
            "ungrouped" => {
                let total = query_duration_ungrouped(&pool, filters, timeout).await?;
                json!({"total_seconds": total})
            }
            "grouped" => {
                let group_by = query.group_by.as_deref().ok_or_else(|| {
                    AppError::BadRequest("group_by required for grouped queries".into())
                })?;
                let groups = query_duration_grouped(
                    &pool,
                    filters,
                    group_by,
                    timeout,
                    query.limit,
                    query.min_seconds,
                )
                .await?;
                json!({"groups": groups})
            }
            other => {
                return Err(AppError::BadRequest(format!(
                    "Unknown query type: {}",
                    other
                )));
            }
        };

        results.insert(query.id.clone(), value);
    }

    Ok(Json(BatchResponse { results }))
}
