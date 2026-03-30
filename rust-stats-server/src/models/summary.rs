use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::models::common::GroupBy;

#[derive(Debug, Deserialize)]
pub struct SummaryRequest {
    pub user_id: Option<i64>,
    pub start_time: Option<f64>,
    pub end_time: Option<f64>,
    pub group_by: Option<Vec<GroupBy>>,
    pub coding_only: Option<bool>,
    pub categories_exclude: Option<Vec<String>>,
    pub limit: Option<i64>,
    pub timeout_seconds: Option<f64>,
    pub projects: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct SummaryResponse {
    pub total_seconds: i64,
    pub start_time: f64,
    pub end_time: f64,
    pub daily_average_seconds: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub groups: Option<HashMap<String, Vec<GroupEntry>>>,
}

#[derive(Debug, Serialize)]
pub struct GroupEntry {
    pub name: String,
    pub total_seconds: i64,
    pub percent: f64,
}
