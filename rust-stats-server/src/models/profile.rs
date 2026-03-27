use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
pub struct ProfileRequest {
    pub user_id: i64,
    pub timezone: String,
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
    pub top_languages: HashMap<String, i64>,
    pub top_projects: HashMap<String, i64>,
    pub top_projects_month: Vec<ProjectDuration>,
    pub top_editors: HashMap<String, i64>,
}

#[derive(Debug, Serialize)]
pub struct ProjectDuration {
    pub project: String,
    pub duration: i64,
}
