use axum::extract::State;
use axum::Json;
use chrono::{Datelike, Utc};
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::profile::{ProfileRequest, ProfileResponse, ProjectDuration};
use crate::query::duration::{query_duration_grouped, query_duration_ungrouped};
use crate::query::filters::{QueryFilterParams, QueryFilters};

pub async fn profile(
    State(pool): State<PgPool>,
    Json(req): Json<ProfileRequest>,
) -> Result<Json<ProfileResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let lang_limit = req.top_languages_limit.unwrap_or(5);
    let proj_limit = req.top_projects_limit.unwrap_or(5);
    let proj_month_limit = req.top_projects_month_limit.unwrap_or(6);
    let editor_limit = req.top_editors_limit.unwrap_or(3);

    // Validate timezone
    let tz: chrono_tz::Tz = req.timezone.parse().unwrap_or(chrono_tz::UTC);
    let now_in_tz = Utc::now().with_timezone(&tz);

    // Today boundaries (in user's timezone, converted to UTC timestamps)
    let today_start = now_in_tz.date_naive().and_hms_opt(0, 0, 0).unwrap();
    let today_start_utc = today_start
        .and_local_timezone(tz)
        .unwrap()
        .with_timezone(&Utc);
    let today_start_ts = today_start_utc.timestamp() as f64;
    let today_end_ts = Utc::now().timestamp() as f64;

    // Week boundaries (Monday start)
    let days_since_monday = now_in_tz.weekday().num_days_from_monday();
    let week_start = now_in_tz.date_naive() - chrono::Duration::days(days_since_monday as i64);
    let week_start_utc = week_start
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_local_timezone(tz)
        .unwrap()
        .with_timezone(&Utc);
    let week_start_ts = week_start_utc.timestamp() as f64;

    // Month boundaries (for top_projects_month)
    let month_start = now_in_tz
        .date_naive()
        .with_day(1)
        .unwrap_or(now_in_tz.date_naive());
    let month_start_utc = month_start
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_local_timezone(tz)
        .unwrap()
        .with_timezone(&Utc);
    let month_start_ts = month_start_utc.timestamp() as f64;

    // Today's seconds
    let today_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        start_time: Some(today_start_ts),
        end_time: Some(today_end_ts),
        coding_only: Some(true),
        ..Default::default()
    });
    let today_seconds = query_duration_ungrouped(&pool, today_filters, timeout).await?;

    // Week's seconds
    let week_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        start_time: Some(week_start_ts),
        end_time: Some(today_end_ts),
        coding_only: Some(true),
        ..Default::default()
    });
    let week_seconds = query_duration_ungrouped(&pool, week_filters, timeout).await?;

    // All-time seconds
    let all_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        coding_only: Some(true),
        ..Default::default()
    });
    let all_seconds = query_duration_ungrouped(&pool, all_filters, timeout).await?;

    // Top languages
    let lang_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        coding_only: Some(true),
        ..Default::default()
    });
    let top_languages = query_duration_grouped(
        &pool,
        lang_filters,
        "language",
        timeout,
        Some(lang_limit),
        None,
    )
    .await?;

    // Top projects (all time)
    let proj_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        coding_only: Some(true),
        ..Default::default()
    });
    let top_projects = query_duration_grouped(
        &pool,
        proj_filters,
        "project",
        timeout,
        Some(proj_limit),
        None,
    )
    .await?;

    // Top projects (this month)
    let proj_month_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        start_time: Some(month_start_ts),
        end_time: Some(today_end_ts),
        coding_only: Some(true),
        ..Default::default()
    });
    let proj_month_raw = query_duration_grouped(
        &pool,
        proj_month_filters,
        "project",
        timeout,
        Some(proj_month_limit),
        None,
    )
    .await?;
    let top_projects_month: Vec<ProjectDuration> = proj_month_raw
        .into_iter()
        .map(|(project, duration)| ProjectDuration { project, duration })
        .collect();

    // Top editors
    let editor_filters = QueryFilters::build(QueryFilterParams {
        user_id: Some(req.user_id),
        coding_only: Some(true),
        ..Default::default()
    });
    let top_editors = query_duration_grouped(
        &pool,
        editor_filters,
        "editor",
        timeout,
        Some(editor_limit),
        None,
    )
    .await?;

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
