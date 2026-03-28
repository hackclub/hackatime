use axum::extract::State;
use axum::Json;
use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::summary::{GroupEntry, SummaryRequest, SummaryResponse};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::QueryFilters;

pub async fn summary(
    State(pool): State<PgPool>,
    Json(req): Json<SummaryRequest>,
) -> Result<Json<SummaryResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let limit = req.limit;

    // Build filters for the total
    let filters = QueryFilters::build(
        req.user_id,
        None,
        req.start_time,
        req.end_time,
        None,
        req.projects.as_deref(),
        None,
        req.coding_only,
        req.categories_exclude.as_deref(),
    );

    let total = query_duration_ungrouped(&pool, filters, timeout).await?;

    // Calculate daily average
    let start = req.start_time.unwrap_or(0.0);
    let end = req.end_time.unwrap_or_else(|| chrono::Utc::now().timestamp() as f64);
    let days = ((end - start) / 86400.0).max(1.0);
    let daily_avg = total as f64 / days;

    // Build grouped results
    let groups = if let Some(ref group_by_list) = req.group_by {
        let mut group_map = HashMap::new();
        for group_by in group_by_list {
            let gfilters = QueryFilters::build(
                req.user_id,
                None,
                req.start_time,
                req.end_time,
                None,
                req.projects.as_deref(),
                None,
                req.coding_only,
                req.categories_exclude.as_deref(),
            );
            let raw =
                query_duration_grouped(&pool, gfilters, group_by, timeout, limit, None).await?;

            let total_for_group: i64 = raw.values().sum();
            let entries: Vec<GroupEntry> = raw
                .into_iter()
                .map(|(name, secs)| {
                    let percent = if total_for_group > 0 {
                        (secs as f64 / total_for_group as f64) * 100.0
                    } else {
                        0.0
                    };
                    GroupEntry {
                        name,
                        total_seconds: secs,
                        percent: (percent * 100.0).round() / 100.0,
                    }
                })
                .collect();

            group_map.insert(group_by.clone(), entries);
        }
        Some(group_map)
    } else {
        None
    };

    Ok(Json(SummaryResponse {
        total_seconds: total,
        start_time: start,
        end_time: end,
        daily_average_seconds: (daily_avg * 100.0).round() / 100.0,
        groups,
    }))
}
