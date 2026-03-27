use chrono::{Duration, NaiveDate, Utc};
use sqlx::postgres::PgArguments;
use sqlx::{Arguments, PgPool};
use std::collections::HashMap;

use crate::error::AppError;

pub async fn query_streaks(
    pool: &PgPool,
    user_ids: &[i64],
    start_date: Option<&str>,
    min_daily_seconds: i64,
    timeout: f64,
) -> Result<HashMap<String, i64>, AppError> {
    if user_ids.is_empty() {
        return Ok(HashMap::new());
    }

    // Clamp start_date to max of (provided, 30 days ago)
    let thirty_days_ago = (Utc::now() - Duration::days(30))
        .format("%Y-%m-%d")
        .to_string();
    let effective_start = match start_date {
        Some(sd) => {
            if sd > thirty_days_ago.as_str() {
                sd.to_string()
            } else {
                thirty_days_ago.clone()
            }
        }
        None => thirty_days_ago.clone(),
    };

    // Get user timezones
    let user_placeholders: Vec<String> = user_ids
        .iter()
        .enumerate()
        .map(|(i, _)| format!("${}", i + 1))
        .collect();
    let tz_sql = format!(
        "SELECT id, COALESCE(timezone, 'UTC') as timezone FROM users WHERE id IN ({})",
        user_placeholders.join(", ")
    );
    let mut tz_args = PgArguments::default();
    for uid in user_ids {
        let _ = tz_args.add(*uid);
    }
    let tz_rows: Vec<(i64, String)> = sqlx::query_as_with(&tz_sql, tz_args)
        .fetch_all(pool)
        .await?;

    let mut user_timezones: HashMap<i64, String> = HashMap::new();
    for (uid, tz) in tz_rows {
        let validated = match tz.parse::<chrono_tz::Tz>() {
            Ok(_) => tz,
            Err(_) => "UTC".to_string(),
        };
        user_timezones.insert(uid, validated);
    }

    let mut result = HashMap::new();

    // For each user, compute daily durations and count streak
    for &uid in user_ids {
        let tz_str = user_timezones
            .get(&uid)
            .cloned()
            .unwrap_or_else(|| "UTC".to_string());

        // Convert effective_start to timestamp
        let start_ts = NaiveDate::parse_from_str(&effective_start, "%Y-%m-%d")
            .map(|nd| nd.and_hms_opt(0, 0, 0).unwrap().and_utc().timestamp() as f64)
            .unwrap_or(0.0);

        let date_expr = format!(
            "DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE '{}')",
            tz_str
        );

        let sql = format!(
            "SELECT {date_expr}::date as day, COALESCE(SUM(diff), 0)::bigint as duration \
             FROM (SELECT {date_expr} as day_group, CASE \
               WHEN LAG(time) OVER (PARTITION BY {date_expr} ORDER BY time) IS NULL THEN 0 \
               ELSE LEAST(time - LAG(time) OVER (PARTITION BY {date_expr} ORDER BY time), {timeout}) \
             END as diff FROM heartbeats WHERE deleted_at IS NULL AND time IS NOT NULL \
             AND time >= 0 AND time <= 253402300799 AND user_id = $1 AND category = 'coding' \
             AND time >= $2) AS diffs \
             GROUP BY day ORDER BY day DESC",
            date_expr = date_expr,
            timeout = timeout
        );

        let mut args = PgArguments::default();
        let _ = args.add(uid);
        let _ = args.add(start_ts);

        let rows: Vec<(NaiveDate, i64)> = sqlx::query_as_with(&sql, args)
            .fetch_all(pool)
            .await?;

        // Get user's "today" in their timezone
        let tz: chrono_tz::Tz = tz_str.parse().unwrap_or(chrono_tz::UTC);
        let user_today = Utc::now().with_timezone(&tz).date_naive();

        // Build a map of date -> duration
        let daily_map: HashMap<NaiveDate, i64> = rows.into_iter().collect();

        // Count streak: walk backwards from today
        let mut streak = 0i64;
        let mut check_date = user_today;

        loop {
            let duration = daily_map.get(&check_date).copied().unwrap_or(0);
            if duration >= min_daily_seconds {
                streak += 1;
                check_date -= Duration::days(1);
            } else if check_date == user_today {
                // Today might not have enough yet, skip and check yesterday
                check_date -= Duration::days(1);
                continue;
            } else {
                break;
            }

            // Don't go past start_date
            if let Ok(start_nd) = NaiveDate::parse_from_str(&effective_start, "%Y-%m-%d") {
                if check_date < start_nd {
                    break;
                }
            }
        }

        result.insert(uid.to_string(), streak);
    }

    Ok(result)
}
