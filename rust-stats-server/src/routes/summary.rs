use axum::extract::State;
use axum::Json;
use sqlx::PgPool;
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::common::GroupedDurationEntry;
use crate::models::summary::{GroupEntry, SummaryRequest, SummaryResponse};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::{QueryFilterParams, QueryFilters};
use crate::time::ratio_part;

fn build_group_entries(raw: Vec<GroupedDurationEntry>, total_seconds: i64) -> Vec<GroupEntry> {
    raw.into_iter()
        .map(
            |GroupedDurationEntry {
                 name,
                 total_seconds: secs,
             }| {
                let percent = if total_seconds > 0 {
                    (ratio_part(secs) / ratio_part(total_seconds)) * 100.0
                } else {
                    0.0
                };
                GroupEntry {
                    name,
                    total_seconds: secs,
                    percent: (percent * 100.0).round() / 100.0,
                }
            },
        )
        .collect()
}

pub async fn summary(
    State(pool): State<PgPool>,
    Json(req): Json<SummaryRequest>,
) -> Result<Json<SummaryResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let limit = req.limit;

    let filters = QueryFilters::build(&QueryFilterParams {
        user_id: req.user_id,
        start_time: req.start_time,
        end_time: req.end_time,
        projects: req.projects.as_deref(),
        coding_only: req.coding_only,
        categories_exclude: req.categories_exclude.as_deref(),
        ..Default::default()
    });

    let total = query_duration_ungrouped(&pool, filters, timeout).await?;

    let start = req.start_time.unwrap_or_default();
    let end = req
        .end_time
        .unwrap_or_else(|| chrono::Utc::now().timestamp() as f64);
    let seconds = (end - start).max(86_400.0);
    let days = seconds / 86_400.0;
    let daily_avg = ratio_part(total) / days;

    let groups = if let Some(ref group_by_list) = req.group_by {
        let mut group_map = HashMap::new();
        for group_by in group_by_list {
            let gfilters = QueryFilters::build(&QueryFilterParams {
                user_id: req.user_id,
                start_time: req.start_time,
                end_time: req.end_time,
                projects: req.projects.as_deref(),
                coding_only: req.coding_only,
                categories_exclude: req.categories_exclude.as_deref(),
                ..Default::default()
            });
            let raw =
                query_duration_grouped(&pool, gfilters, *group_by, timeout, limit, None).await?;
            let entries = build_group_entries(raw, total);

            group_map.insert(group_by.response_key().to_owned(), entries);
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

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::build_group_entries;
    use crate::models::common::GroupedDurationEntry;

    #[test]
    fn computes_percentages_against_total_seconds() {
        let raw = vec![
            GroupedDurationEntry {
                name: "Ruby".to_string(),
                total_seconds: 60,
            },
            GroupedDurationEntry {
                name: "Rust".to_string(),
                total_seconds: 40,
            },
        ];

        let entries = build_group_entries(raw, 200);
        let percents = entries
            .into_iter()
            .map(|entry| (entry.name, entry.percent))
            .collect::<HashMap<_, _>>();

        assert_eq!(percents.get("Ruby"), Some(&30.0));
        assert_eq!(percents.get("Rust"), Some(&20.0));
    }
}
