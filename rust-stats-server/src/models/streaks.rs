use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
pub struct StreaksRequest {
    pub user_ids: Vec<i64>,
    pub start_date: Option<String>,
    pub min_daily_seconds: Option<i64>,
    pub timeout_seconds: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct StreaksResponse {
    pub streaks: HashMap<String, i64>,
}
