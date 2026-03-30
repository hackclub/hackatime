use chrono::{Duration, NaiveDate, Utc};
use chrono_tz::Tz;
use sqlx::postgres::PgArguments;
use sqlx::{Arguments, PgPool};
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::common::UserStreakEntry;
use crate::time::{heartbeat_time, start_of_day_timestamp, timezone_date_expr};

fn validated_timezone(timezone: &str) -> Tz {
    timezone.parse().unwrap_or(chrono_tz::UTC)
}

pub async fn query_streaks(
    pool: &PgPool,
    user_ids: &[i64],
    start_date: Option<NaiveDate>,
    min_daily_seconds: i64,
    timeout: f64,
) -> Result<Vec<UserStreakEntry>, AppError> {
    if user_ids.is_empty() {
        return Ok(Vec::new());
    }

    let user_placeholders: Vec<String> = user_ids
        .iter()
        .enumerate()
        .map(|(index, _)| format!("${}", index + 1))
        .collect();
    let timezone_sql = format!(
        "SELECT id, COALESCE(timezone, 'UTC') as timezone FROM users WHERE id IN ({})",
        user_placeholders.join(", ")
    );

    let mut timezone_args = PgArguments::default();
    for user_id in user_ids {
        let _ = timezone_args.add(*user_id);
    }

    let timezone_rows: Vec<(i64, String)> = sqlx::query_as_with(&timezone_sql, timezone_args)
        .fetch_all(pool)
        .await?;
    let user_timezones: HashMap<i64, Tz> = timezone_rows
        .into_iter()
        .map(|(user_id, timezone)| (user_id, validated_timezone(&timezone)))
        .collect();

    let start_timestamp =
        start_date.map_or(0.0, |date| heartbeat_time(start_of_day_timestamp(date) as f64));
    let mut streaks = Vec::with_capacity(user_ids.len());

    for &user_id in user_ids {
        let timezone = user_timezones
            .get(&user_id)
            .copied()
            .unwrap_or(chrono_tz::UTC);
        let date_expr = timezone_date_expr(timezone);
        let sql = format!(
            "SELECT day_group::date as day, COALESCE(SUM(diff), 0)::bigint as duration \
             FROM (SELECT {date_expr} as day_group, CASE \
               WHEN LAG(\"time\") OVER (PARTITION BY {date_expr} ORDER BY \"time\") IS NULL THEN 0 \
               ELSE LEAST(\"time\" - LAG(\"time\") OVER (PARTITION BY {date_expr} ORDER BY \"time\"), {timeout}) \
             END as diff FROM heartbeats WHERE deleted_at IS NULL AND \"time\" IS NOT NULL \
             AND \"time\" >= 0 AND \"time\" <= 253402300799 AND user_id = $1 AND category = 'coding' \
             AND \"time\" >= $2) AS diffs \
             GROUP BY day ORDER BY day DESC"
        );

        let mut args = PgArguments::default();
        let _ = args.add(user_id);
        let _ = args.add(start_timestamp);

        let rows: Vec<(NaiveDate, i64)> = sqlx::query_as_with(&sql, args).fetch_all(pool).await?;
        let user_today = Utc::now().with_timezone(&timezone).date_naive();
        let daily_totals: HashMap<NaiveDate, i64> = rows.into_iter().collect();
        let streak_count =
            count_streak_days(&daily_totals, user_today, start_date, min_daily_seconds);

        streaks.push(UserStreakEntry {
            user_id,
            streak_count,
        });
    }

    Ok(streaks)
}

fn count_streak_days(
    daily_totals: &HashMap<NaiveDate, i64>,
    user_today: NaiveDate,
    start_date: Option<NaiveDate>,
    min_daily_seconds: i64,
) -> i64 {
    let mut streak_count = 0_i64;
    let mut check_date = user_today;

    loop {
        if let Some(start_date) = start_date {
            if check_date < start_date {
                break;
            }
        }

        let duration = daily_totals.get(&check_date).copied().unwrap_or_default();
        if duration >= min_daily_seconds {
            streak_count += 1;
            check_date -= Duration::days(1);
            continue;
        }

        if check_date == user_today {
            check_date -= Duration::days(1);
            continue;
        }

        break;
    }

    streak_count
}

#[cfg(test)]
mod tests {
    use chrono::NaiveDate;
    use std::collections::HashMap;

    use super::count_streak_days;

    #[test]
    fn stops_when_it_hits_a_gap_after_yesterday() {
        let daily_totals = HashMap::from([
            (NaiveDate::from_ymd_opt(2025, 1, 4).unwrap(), 900),
            (NaiveDate::from_ymd_opt(2025, 1, 3).unwrap(), 900),
            (NaiveDate::from_ymd_opt(2025, 1, 1).unwrap(), 900),
        ]);

        assert_eq!(
            count_streak_days(
                &daily_totals,
                NaiveDate::from_ymd_opt(2025, 1, 4).unwrap(),
                None,
                900,
            ),
            2
        );
    }

    #[test]
    fn skips_today_if_it_has_not_hit_the_threshold_yet() {
        let daily_totals = HashMap::from([
            (NaiveDate::from_ymd_opt(2025, 1, 4).unwrap(), 100),
            (NaiveDate::from_ymd_opt(2025, 1, 3).unwrap(), 900),
            (NaiveDate::from_ymd_opt(2025, 1, 2).unwrap(), 900),
        ]);

        assert_eq!(
            count_streak_days(
                &daily_totals,
                NaiveDate::from_ymd_opt(2025, 1, 4).unwrap(),
                None,
                900,
            ),
            2
        );
    }
}
