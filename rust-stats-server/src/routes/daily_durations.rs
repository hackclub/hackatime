use axum::extract::State;
use axum::Json;
use chrono::{DateTime, Duration, NaiveDate};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;

use crate::error::AppError;
use crate::models::common::DailyDurationEntry;
use crate::query::filters::{QueryFilterParams, QueryFilters};
use crate::time::{local_midnight_utc, timezone_date_expr};

const DEFAULT_ACTIVITY_GRAPH_DAYS: i64 = 365;

#[derive(Debug, Deserialize)]
pub struct DailyDurationsRequest {
    pub user_id: i64,
    pub timezone: chrono_tz::Tz,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub timeout_seconds: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct DailyDurationsResponse {
    pub durations: Vec<DailyDurationEntry>,
}

pub async fn daily_durations(
    State(pool): State<PgPool>,
    Json(req): Json<DailyDurationsRequest>,
) -> Result<Json<DailyDurationsResponse>, AppError> {
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let now_in_timezone = chrono::Utc::now().with_timezone(&req.timezone);
    let (start_date, end_date) =
        resolved_date_window(now_in_timezone, req.start_date, req.end_date);
    let (start_time, end_time) = local_day_bounds(start_date, end_date, req.timezone);

    let filters = QueryFilters::build(&QueryFilterParams {
        user_id: Some(req.user_id),
        start_time: Some(start_time),
        end_time: Some(end_time),
        ..Default::default()
    });

    let date_expr = timezone_date_expr(req.timezone);

    let sql = format!(
        "SELECT day_group::date::text as day, COALESCE(SUM(diff), 0)::bigint as duration \
         FROM (SELECT {date_expr} as day_group, CASE \
           WHEN LAG(\"time\") OVER (PARTITION BY {date_expr} ORDER BY \"time\") IS NULL THEN 0 \
           ELSE LEAST(\"time\" - LAG(\"time\") OVER (PARTITION BY {date_expr} ORDER BY \"time\"), {timeout}) \
         END as diff FROM heartbeats WHERE {where_clause}) AS diffs \
         GROUP BY day \
         ORDER BY day",
        date_expr = date_expr,
        timeout = timeout,
        where_clause = filters.where_clause
    );

    let rows: Vec<(NaiveDate, i64)> = sqlx::query_as_with(&sql, filters.args)
        .fetch_all(&pool)
        .await?;

    Ok(Json(DailyDurationsResponse {
        durations: rows
            .into_iter()
            .map(|(date, total_seconds)| DailyDurationEntry {
                date,
                total_seconds,
            })
            .collect(),
    }))
}

fn local_day_bounds(start_date: NaiveDate, end_date: NaiveDate, timezone: chrono_tz::Tz) -> (f64, f64) {
    let start_time = local_midnight_utc(start_date, timezone).timestamp() as f64;
    let next_day = end_date + Duration::days(1);
    let end_time = local_midnight_utc(next_day, timezone).timestamp() as f64 - 1e-6;

    (start_time, end_time)
}

fn resolved_date_window(
    now_in_timezone: DateTime<chrono_tz::Tz>,
    start_date: Option<NaiveDate>,
    end_date: Option<NaiveDate>,
) -> (NaiveDate, NaiveDate) {
    let resolved_end = end_date.unwrap_or_else(|| now_in_timezone.date_naive());
    let resolved_start =
        start_date.unwrap_or_else(|| resolved_end - Duration::days(DEFAULT_ACTIVITY_GRAPH_DAYS));

    (resolved_start, resolved_end)
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone, Utc};

    use super::{local_day_bounds, resolved_date_window};

    #[test]
    fn defaults_to_the_last_365_days_in_the_users_timezone() {
        let london = chrono_tz::Europe::London;
        let now_in_timezone = london.with_ymd_and_hms(2026, 3, 29, 12, 0, 0).unwrap();

        let (start_date, end_date) = resolved_date_window(now_in_timezone, None, None);

        assert_eq!(end_date, now_in_timezone.date_naive());
        assert_eq!(start_date, end_date - Duration::days(365));
    }

    #[test]
    fn preserves_explicit_bounds() {
        let london = chrono_tz::Europe::London;
        let now_in_timezone = london.with_ymd_and_hms(2026, 3, 29, 12, 0, 0).unwrap();

        let start = chrono::NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        let finish = chrono::NaiveDate::from_ymd_opt(2026, 2, 1).unwrap();
        let (resolved_start, resolved_end) =
            resolved_date_window(now_in_timezone, Some(start), Some(finish));

        assert_eq!(resolved_start, start);
        assert_eq!(resolved_end, finish);
    }

    #[test]
    fn uses_local_midnight_bounds_for_non_utc_timezones() {
        let new_york = chrono_tz::America::New_York;
        let date = chrono::NaiveDate::from_ymd_opt(2026, 3, 28).unwrap();

        let (start_time, end_time) = local_day_bounds(date, date, new_york);

        assert_eq!(
            start_time,
            Utc.with_ymd_and_hms(2026, 3, 28, 4, 0, 0)
                .unwrap()
                .timestamp() as f64
        );
        assert!(end_time < Utc.with_ymd_and_hms(2026, 3, 29, 4, 0, 0).unwrap().timestamp() as f64);
        assert!(
            end_time
                > Utc.with_ymd_and_hms(2026, 3, 29, 3, 59, 59)
                    .unwrap()
                    .timestamp() as f64
        );
    }
}
