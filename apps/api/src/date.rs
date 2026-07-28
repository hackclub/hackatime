use chrono::{DateTime, Datelike, Days, Duration, LocalResult, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;

use crate::error::{AppError, Result};

pub fn parse_datetime(value: &str, name: &str) -> Result<f64> {
    if let Ok(timestamp) = value.parse::<f64>() {
        return Ok(timestamp);
    }
    if let Ok(time) = DateTime::parse_from_rfc3339(value) {
        return Ok(time.timestamp_micros() as f64 / 1_000_000.0);
    }
    if let Ok(date) = NaiveDate::parse_from_str(value, "%Y-%m-%d") {
        return Ok(date
            .and_hms_opt(0, 0, 0)
            .expect("midnight exists")
            .and_utc()
            .timestamp() as f64);
    }
    Err(AppError::Unprocessable(format!("Invalid {name}")))
}

pub fn parse_range(
    start: Option<&str>,
    end: Option<&str>,
    default_start: f64,
    default_end: f64,
) -> Result<(f64, f64)> {
    Ok((
        start
            .map(|value| parse_datetime(value, "start_date"))
            .transpose()?
            .unwrap_or(default_start),
        end.map(|value| parse_datetime(value, "end_date"))
            .transpose()?
            .unwrap_or(default_end),
    ))
}

pub fn explicit_day_range(start: &str, end: &str) -> Result<(f64, f64)> {
    let start = NaiveDate::parse_from_str(start, "%Y-%m-%d")
        .map_err(|_| AppError::BadRequest("Invalid date range".to_owned()))?;
    let end = NaiveDate::parse_from_str(end, "%Y-%m-%d")
        .map_err(|_| AppError::BadRequest("Invalid date range".to_owned()))?;
    let start = start
        .and_hms_opt(0, 0, 0)
        .expect("midnight exists")
        .and_utc()
        .timestamp() as f64;
    let end = end
        .and_hms_micro_opt(23, 59, 59, 999_999)
        .expect("end of day exists")
        .and_utc()
        .timestamp_micros() as f64
        / 1_000_000.0;
    Ok((start, end))
}

pub fn interval_range(interval: Option<&str>) -> (f64, f64) {
    let now = Utc::now();
    let today = now.date_naive();
    let start = match interval {
        Some("today") => today,
        Some("yesterday") => today - Days::new(1),
        Some("last_7_days") => today - Days::new(7),
        Some("last_30_days") => today - Days::new(30),
        Some("last_6_months") => today - Days::new(183),
        Some("last_12_months" | "last_year") => today - Days::new(365),
        Some("week" | "7_days") => today - Days::new(today.weekday().num_days_from_monday() as u64),
        Some("month" | "30_days") => today.with_day(1).expect("first day exists"),
        Some("year" | "12_months") => today.with_ordinal(1).expect("first day exists"),
        Some("any" | "all_time") | None => {
            return (
                0.0,
                today
                    .and_hms_micro_opt(23, 59, 59, 999_999)
                    .expect("end of day exists")
                    .and_utc()
                    .timestamp_micros() as f64
                    / 1_000_000.0,
            );
        }
        _ => today,
    };
    let start = start
        .and_hms_opt(0, 0, 0)
        .expect("midnight exists")
        .and_utc()
        .timestamp() as f64;
    let end = today
        .and_hms_micro_opt(23, 59, 59, 999_999)
        .expect("end of day exists")
        .and_utc()
        .timestamp_micros() as f64
        / 1_000_000.0;
    (start, end)
}

pub fn local_day_range(timezone: Option<&str>) -> (f64, f64) {
    let timezone = timezone
        .and_then(|value| value.parse::<Tz>().ok())
        .unwrap_or(chrono_tz::UTC);
    let now = Utc::now().with_timezone(&timezone);
    local_day_range_on(timezone, now.date_naive())
}

pub fn local_date_range(timezone: Option<&str>, start: NaiveDate, end: NaiveDate) -> (f64, f64) {
    let timezone = timezone
        .and_then(|value| value.parse::<Tz>().ok())
        .unwrap_or(chrono_tz::UTC);
    (
        local_datetime(timezone, start, 0, 0, 0),
        local_datetime(timezone, end + Days::new(1), 0, 0, 0),
    )
}

fn local_day_range_on(timezone: Tz, date: NaiveDate) -> (f64, f64) {
    let start = local_datetime(timezone, date, 0, 0, 0);
    let next = local_datetime(timezone, date + Days::new(1), 0, 0, 0);
    (start, next - 0.000_001)
}

fn local_datetime(timezone: Tz, date: NaiveDate, hour: u32, minute: u32, second: u32) -> f64 {
    let naive = date
        .and_hms_opt(hour, minute, second)
        .expect("valid local time");
    let time = match timezone.from_local_datetime(&naive) {
        LocalResult::Single(time) | LocalResult::Ambiguous(time, _) => time,
        LocalResult::None => timezone
            .from_utc_datetime(&(naive + Duration::hours(1)))
            .with_timezone(&timezone),
    };
    time.with_timezone(&Utc).timestamp_micros() as f64 / 1_000_000.0
}

#[cfg(test)]
mod tests {
    use chrono::NaiveDate;

    use super::{local_day_range, local_day_range_on};

    #[test]
    fn timezone_range_is_one_local_day() {
        let (start, end) = local_day_range(Some("Asia/Kathmandu"));
        assert!((end - start - 86_399.999_999).abs() < 0.01);
    }

    #[test]
    fn invalid_timezone_falls_back_to_utc() {
        let utc = local_day_range(Some("UTC"));
        assert_eq!(local_day_range(Some("Mars/Olympus")), utc);
    }

    #[test]
    fn spring_dst_day_has_twenty_three_hours() {
        let date = NaiveDate::from_ymd_opt(2026, 3, 8).unwrap();
        let (start, end) = local_day_range_on(chrono_tz::America::New_York, date);
        assert!((end - start - 82_799.999_999).abs() < 0.01);
    }

    #[test]
    fn autumn_dst_day_has_twenty_five_hours() {
        let date = NaiveDate::from_ymd_opt(2026, 11, 1).unwrap();
        let (start, end) = local_day_range_on(chrono_tz::America::New_York, date);
        assert!((end - start - 89_999.999_999).abs() < 0.01);
    }
}
