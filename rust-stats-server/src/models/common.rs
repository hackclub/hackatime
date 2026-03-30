use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum GroupBy {
    Project,
    Language,
    Editor,
    OperatingSystem,
    UserId,
    Category,
    Machine,
}

impl GroupBy {
    pub const fn column(self) -> &'static str {
        match self {
            Self::Project => "project",
            Self::Language => "language",
            Self::Editor => "editor",
            Self::OperatingSystem => "operating_system",
            Self::UserId => "user_id",
            Self::Category => "category",
            Self::Machine => "machine",
        }
    }

    pub const fn response_key(self) -> &'static str {
        self.column()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct GroupedDurationEntry {
    pub name: String,
    pub total_seconds: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DailyDurationEntry {
    pub date: NaiveDate,
    pub total_seconds: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct UserStreakEntry {
    pub user_id: i64,
    pub streak_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct UserDurationEntry {
    pub user_id: i64,
    pub total_seconds: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NamedDuration {
    pub name: String,
    pub total_seconds: i64,
}
