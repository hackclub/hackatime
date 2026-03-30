use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::models::common::{GroupBy, GroupedDurationEntry};

#[derive(Debug, Deserialize)]
pub struct BatchRequest {
    pub user_id: i64,
    pub start_time: f64,
    pub end_time: f64,
    pub queries: Vec<BatchQuery>,
    pub timeout_seconds: Option<f64>,
}

#[derive(Debug, Deserialize)]
pub struct BatchQueryFilters {
    pub coding_only: Option<bool>,
    pub project: Option<String>,
    pub projects: Option<Vec<String>>,
    pub languages: Option<Vec<String>>,
    pub editors: Option<Vec<String>>,
    pub operating_systems: Option<Vec<String>>,
    pub categories: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum BatchQuery {
    Ungrouped {
        id: String,
        #[serde(flatten)]
        filters: BatchQueryFilters,
    },
    Grouped {
        id: String,
        group_by: GroupBy,
        limit: Option<i64>,
        min_seconds: Option<i64>,
        #[serde(flatten)]
        filters: BatchQueryFilters,
    },
}

impl BatchQuery {
    pub fn id(&self) -> &str {
        match self {
            Self::Ungrouped { id, .. } | Self::Grouped { id, .. } => id,
        }
    }

    pub fn filters(&self) -> &BatchQueryFilters {
        match self {
            Self::Ungrouped { filters, .. } | Self::Grouped { filters, .. } => filters,
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(untagged)]
pub enum BatchResult {
    Ungrouped { total_seconds: i64 },
    Grouped { groups: Vec<GroupedDurationEntry> },
}

#[derive(Debug, Serialize)]
pub struct BatchResponse {
    pub results: HashMap<String, BatchResult>,
}
