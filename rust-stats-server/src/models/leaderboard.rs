use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct LeaderboardRequest {
    pub user_ids: Option<Vec<i64>>,
    pub start_time: f64,
    pub end_time: f64,
    pub coding_only: Option<bool>,
    pub min_seconds: Option<i64>,
    pub include_streaks: Option<bool>,
    pub exclude_trust_level_red: Option<bool>,
    pub require_github_uid: Option<bool>,
    pub timeout_seconds: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct LeaderboardResponse {
    pub entries: Vec<LeaderboardEntry>,
}

#[derive(Debug, Serialize)]
pub struct LeaderboardEntry {
    pub user_id: i64,
    pub total_seconds: i64,
    pub streak_count: i64,
}
