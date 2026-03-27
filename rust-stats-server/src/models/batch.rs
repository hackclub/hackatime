use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
pub struct BatchRequest {
    pub user_id: i64,
    pub start_time: f64,
    pub end_time: f64,
    pub queries: Vec<BatchQuery>,
    pub timeout_seconds: Option<f64>,
}

#[derive(Debug, Deserialize)]
pub struct BatchQuery {
    pub id: String,
    #[serde(rename = "type")]
    pub query_type: String,
    pub group_by: Option<String>,
    pub limit: Option<i64>,
    pub min_seconds: Option<i64>,
    pub coding_only: Option<bool>,
    pub project: Option<String>,
    pub projects: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct BatchResponse {
    pub results: HashMap<String, Value>,
}
