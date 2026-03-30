use axum::extract::State;
use axum::Json;
use chrono::Utc;
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::common::{GroupedDurationEntry, NamedDuration};
use crate::models::profile::{ProfileRequest, ProfileResponse};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::{QueryFilterParams, QueryFilters};
use crate::time::{current_day_window, current_week_start_utc, rolling_month_start_utc};

fn coding_filters(user_id: i64, start_time: Option<f64>, end_time: Option<f64>) -> QueryFilters {
    QueryFilters::build(&QueryFilterParams {
        user_id: Some(user_id),
        start_time,
        end_time,
        coding_only: Some(true),
        ..Default::default()
    })
}

fn into_named_durations(entries: Vec<GroupedDurationEntry>) -> Vec<NamedDuration> {
    entries
        .into_iter()
        .map(|entry| NamedDuration {
            name: entry.name,
            total_seconds: entry.total_seconds,
        })
        .collect()
}

fn into_present_named_durations(
    entries: Vec<GroupedDurationEntry>,
    limit: Option<i64>,
) -> Vec<NamedDuration> {
    let mut named = into_named_durations(entries)
        .into_iter()
        .filter(|entry| !entry.name.trim().is_empty())
        .collect::<Vec<_>>();

    if let Some(limit) = limit.and_then(|value| usize::try_from(value).ok()) {
        named.truncate(limit);
    }

    named
}

pub async fn profile(
    State(pool): State<PgPool>,
    Json(req): Json<ProfileRequest>,
) -> Result<Json<ProfileResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let language_limit = req.top_languages_limit.unwrap_or(5);
    let project_limit = req.top_projects_limit.unwrap_or(5);
    let monthly_project_limit = req.top_projects_month_limit.unwrap_or(6);
    let _editor_limit = req.top_editors_limit;
    let now_in_timezone = Utc::now().with_timezone(&req.timezone);
    let (today_start, today_end) = current_day_window(now_in_timezone);
    let week_start = current_week_start_utc(now_in_timezone).timestamp() as f64;
    let month_start = rolling_month_start_utc(now_in_timezone).timestamp() as f64;

    let today_seconds = query_duration_ungrouped(
        &pool,
        coding_filters(req.user_id, Some(today_start as f64), Some(today_end as f64)),
        timeout,
    )
    .await?;
    let week_seconds = query_duration_ungrouped(
        &pool,
        coding_filters(req.user_id, Some(week_start), Some(today_end as f64)),
        timeout,
    )
    .await?;
    let all_seconds =
        query_duration_ungrouped(&pool, coding_filters(req.user_id, None, None), timeout).await?;

    let top_languages = into_present_named_durations(
        query_duration_grouped(
            &pool,
            coding_filters(req.user_id, None, None),
            crate::models::common::GroupBy::Language,
            timeout,
            None,
            None,
        )
        .await?,
        Some(language_limit),
    );
    let top_projects = into_present_named_durations(
        query_duration_grouped(
            &pool,
            coding_filters(req.user_id, None, None),
            crate::models::common::GroupBy::Project,
            timeout,
            None,
            None,
        )
        .await?,
        Some(project_limit),
    );
    let top_projects_month = into_present_named_durations(
        query_duration_grouped(
            &pool,
            coding_filters(req.user_id, Some(month_start), Some(today_end as f64)),
            crate::models::common::GroupBy::Project,
            timeout,
            None,
            None,
        )
        .await?,
        Some(monthly_project_limit),
    );
    let top_editors = into_present_named_durations(
        query_duration_grouped(
            &pool,
            coding_filters(req.user_id, None, None),
            crate::models::common::GroupBy::Editor,
            timeout,
            None,
            None,
        )
        .await?,
        None,
    );

    Ok(Json(ProfileResponse {
        today_seconds,
        week_seconds,
        all_seconds,
        top_languages,
        top_projects,
        top_projects_month,
        top_editors,
    }))
}

#[cfg(test)]
mod tests {
    use chrono::{Datelike, TimeZone, Timelike, Utc};

    use crate::models::common::GroupedDurationEntry;
    use crate::time::rolling_month_start_utc;

    use super::into_present_named_durations;

    #[test]
    fn preserves_a_rolling_month_window() {
        let london = chrono_tz::Europe::London;
        let now_in_timezone = london.with_ymd_and_hms(2026, 3, 2, 15, 45, 30).unwrap();

        let month_ago = rolling_month_start_utc(now_in_timezone);

        assert_eq!(month_ago.with_timezone(&london).month(), 2);
        assert_eq!(month_ago.with_timezone(&london).day(), 2);
        assert_eq!(month_ago.with_timezone(&london).hour(), 15);
        assert_eq!(month_ago.with_timezone(&london).minute(), 45);
        assert_eq!(month_ago.with_timezone(&london).second(), 30);
        assert!(month_ago < Utc.with_ymd_and_hms(2026, 3, 1, 0, 0, 0).unwrap());
    }

    #[test]
    fn drops_blank_groups_before_applying_limits() {
        let entries = vec![
            GroupedDurationEntry {
                name: String::new(),
                total_seconds: 500,
            },
            GroupedDurationEntry {
                name: "Rust".to_string(),
                total_seconds: 400,
            },
            GroupedDurationEntry {
                name: "Ruby".to_string(),
                total_seconds: 300,
            },
        ];

        let filtered = into_present_named_durations(entries, Some(1));

        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].name, "Rust");
    }
}
