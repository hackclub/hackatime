use serde::{Deserialize, Serialize};

use crate::models::common::NamedDuration;

#[derive(Debug, Deserialize)]
pub struct ProfileRequest {
    pub user_id: i64,
    pub timezone: chrono_tz::Tz,
    pub timeout_seconds: Option<f64>,
    pub top_languages_limit: Option<i64>,
    pub top_projects_limit: Option<i64>,
    pub top_projects_month_limit: Option<i64>,
    pub top_editors_limit: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct ProfileResponse {
    pub today_seconds: i64,
    pub week_seconds: i64,
    pub all_seconds: i64,
    pub top_languages: Vec<NamedDuration>,
    pub top_projects: Vec<NamedDuration>,
    pub top_projects_month: Vec<NamedDuration>,
    pub top_editors: Vec<NamedDuration>,
}
