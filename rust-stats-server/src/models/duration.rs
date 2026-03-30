use serde::{Deserialize, Serialize};

use crate::models::common::{GroupBy, GroupedDurationEntry};

#[derive(Debug, Deserialize)]
pub struct DurationRequest {
    pub user_id: Option<i64>,
    pub user_ids: Option<Vec<i64>>,
    pub start_time: Option<f64>,
    pub end_time: Option<f64>,
    pub project: Option<String>,
    pub projects: Option<Vec<String>>,
    pub category: Option<String>,
    pub coding_only: Option<bool>,
    pub categories_exclude: Option<Vec<String>>,
    pub timeout_seconds: Option<f64>,
    pub languages: Option<Vec<String>>,
    pub editors: Option<Vec<String>>,
    pub operating_systems: Option<Vec<String>>,
    pub categories: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct DurationResponse {
    pub total_seconds: i64,
}

#[derive(Debug, Deserialize)]
pub struct GroupedDurationRequest {
    pub user_id: Option<i64>,
    pub user_ids: Option<Vec<i64>>,
    pub start_time: Option<f64>,
    pub end_time: Option<f64>,
    pub group_by: GroupBy,
    pub project: Option<String>,
    pub projects: Option<Vec<String>>,
    pub coding_only: Option<bool>,
    pub categories_exclude: Option<Vec<String>>,
    pub timeout_seconds: Option<f64>,
    pub limit: Option<i64>,
    pub min_seconds: Option<i64>,
    pub languages: Option<Vec<String>>,
    pub editors: Option<Vec<String>>,
    pub operating_systems: Option<Vec<String>>,
    pub categories: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct GroupedDurationResponse {
    pub groups: Vec<GroupedDurationEntry>,
}
