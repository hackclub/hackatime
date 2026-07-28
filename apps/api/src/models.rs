use std::collections::HashMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::{IntoParams, ToSchema};

#[derive(Clone, Debug, FromRow)]
pub struct User {
    pub id: i64,
    pub slack_uid: Option<String>,
    #[sqlx(rename = "username")]
    pub _username: Option<String>,
    pub github_username: Option<String>,
    pub timezone: Option<String>,
    pub trust_level: i32,
    pub allow_public_stats_lookup: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize, ToSchema)]
pub struct HeartbeatInput {
    pub ai_input_tokens: Option<i64>,
    pub ai_line_changes: Option<i32>,
    pub ai_model: Option<String>,
    pub ai_output_tokens: Option<i64>,
    pub ai_prompt_length: Option<i32>,
    pub ai_session: Option<String>,
    pub ai_subscription_plan: Option<String>,
    pub branch: Option<String>,
    pub category: Option<String>,
    pub created_at: Option<String>,
    pub cursorpos: Option<i32>,
    #[serde(default)]
    pub dependencies: Vec<String>,
    pub editor: Option<String>,
    pub entity: Option<String>,
    pub human_line_changes: Option<i32>,
    pub is_write: Option<bool>,
    pub language: Option<String>,
    pub line_additions: Option<i32>,
    pub line_deletions: Option<i32>,
    pub lineno: Option<i32>,
    pub lines: Option<i32>,
    pub machine: Option<String>,
    pub operating_system: Option<String>,
    pub plugin: Option<String>,
    pub project: Option<String>,
    pub project_root_count: Option<i32>,
    #[schema(value_type = f64)]
    pub time: serde_json::Value,
    #[serde(rename = "type")]
    pub kind: Option<String>,
    pub user_agent: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct StatsQuery {
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub filter_by_project: Option<String>,
    pub filter_by_category: Option<String>,
    pub features: Option<String>,
    pub total_seconds: Option<bool>,
    #[serde(rename = "boundary_aware")]
    pub _boundary_aware: Option<bool>,
    pub no_ai_coding: Option<bool>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct SpansQuery {
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub project: Option<String>,
    pub filter_by_project: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct ProjectsQuery {
    pub include_archived: Option<bool>,
    pub projects: Option<String>,
    pub since: Option<String>,
    pub until: Option<String>,
    pub until_date: Option<String>,
    pub start: Option<String>,
    pub end: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct SummaryQuery {
    pub user_id: Option<String>,
    pub user: Option<String>,
    pub interval: Option<String>,
    pub range: Option<String>,
    pub from: Option<String>,
    pub to: Option<String>,
    pub start: Option<String>,
    pub end: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct MyHeartbeatsQuery {
    pub start_time: Option<String>,
    pub end_time: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct HoursQuery {
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct MostRecentQuery {
    pub source_type: Option<String>,
    pub editor: Option<String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct BadgeQuery {
    pub label: Option<String>,
    pub color: Option<String>,
    pub aliases: Option<String>,
    #[serde(flatten)]
    pub extra: HashMap<String, String>,
}

#[derive(Clone, Debug, Deserialize, IntoParams)]
pub struct GlobalStatsQuery {
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub username: Option<String>,
    pub user_email: Option<String>,
}

#[derive(Clone, Debug, Serialize, ToSchema)]
pub struct TrustFactor {
    pub trust_level: String,
    pub trust_value: i32,
}

#[derive(Clone, Debug, Serialize, ToSchema)]
pub struct Span {
    pub start_time: f64,
    pub end_time: f64,
    pub duration: f64,
}

#[derive(Clone, Debug, Serialize, ToSchema)]
pub struct ProjectDetails {
    pub name: String,
    pub total_seconds: i64,
    pub languages: Vec<String>,
    pub repo_url: Option<String>,
    pub total_heartbeats: u64,
    pub first_heartbeat: Option<String>,
    pub last_heartbeat: Option<String>,
    pub most_recent_heartbeat: Option<String>,
    pub archived: bool,
}

pub fn format_epoch(value: f64) -> Option<String> {
    DateTime::<Utc>::from_timestamp_micros((value * 1_000_000.0).round() as i64)
        .map(|time| time.format("%Y-%m-%dT%H:%M:%SZ").to_string())
}
