use chrono::{DateTime, Datelike, Duration, LocalResult, Months, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;

pub const fn heartbeat_time(seconds: f64) -> f64 {
    seconds
}

#[allow(clippy::cast_precision_loss)]
pub fn ratio_part(value: i64) -> f64 {
    value as f64
}

pub fn start_of_day_timestamp(date: NaiveDate) -> i64 {
    date.and_hms_opt(0, 0, 0)
        .expect("midnight is always a valid time")
        .and_utc()
        .timestamp()
}

pub fn local_midnight_utc(date: NaiveDate, tz: Tz) -> DateTime<Utc> {
    let local_midnight = date
        .and_hms_opt(0, 0, 0)
        .expect("midnight is always a valid time");

    match tz.from_local_datetime(&local_midnight) {
        LocalResult::Single(value) | LocalResult::Ambiguous(value, _) => value.with_timezone(&Utc),
        LocalResult::None => tz.from_utc_datetime(&local_midnight).with_timezone(&Utc),
    }
}

pub fn current_day_window(now_in_tz: DateTime<Tz>) -> (i64, i64) {
    let start = local_midnight_utc(now_in_tz.date_naive(), now_in_tz.timezone());
    (start.timestamp(), now_in_tz.with_timezone(&Utc).timestamp())
}

pub fn current_week_start_utc(now_in_tz: DateTime<Tz>) -> DateTime<Utc> {
    let week_start = now_in_tz.date_naive()
        - Duration::days(i64::from(now_in_tz.weekday().num_days_from_monday()));
    local_midnight_utc(week_start, now_in_tz.timezone())
}

pub fn rolling_month_start_utc(now_in_tz: DateTime<Tz>) -> DateTime<Utc> {
    now_in_tz
        .checked_sub_months(Months::new(1))
        .unwrap_or_else(|| now_in_tz - Duration::days(30))
        .with_timezone(&Utc)
}

pub fn timezone_date_expr(timezone: Tz) -> String {
    format!("DATE_TRUNC('day', to_timestamp(\"time\") AT TIME ZONE '{timezone}')")
}
