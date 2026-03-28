use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct SpansRequest {
    pub user_id: i64,
    pub start_time: Option<f64>,
    pub end_time: Option<f64>,
    pub project: Option<String>,
    pub projects: Option<Vec<String>>,
    pub timeout_seconds: Option<f64>,
    pub include_metadata: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct SpansResponse {
    pub spans: Vec<Span>,
}

#[derive(Debug, Serialize)]
pub struct Span {
    pub start_time: f64,
    pub end_time: f64,
    pub duration: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub files_edited: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub projects: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub editors: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub languages: Option<Vec<String>>,
}
