use std::{env, net::SocketAddr};

use crate::error::{AppError, Result};

#[derive(Clone)]
pub struct Config {
    pub bind: SocketAddr,
    pub database_url: String,
    pub clickhouse_url: String,
    pub clickhouse_database: String,
    pub clickhouse_user: String,
    pub clickhouse_password: String,
    pub cors_origin: String,
    pub stats_api_key: Option<String>,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        dotenvy::dotenv().ok();

        Ok(Self {
            bind: value("BIND_ADDRESS", "0.0.0.0:3002")
                .parse()
                .map_err(|error| AppError::Config(format!("invalid BIND_ADDRESS: {error}")))?,
            database_url: value(
                "DATABASE_URL",
                "postgres://postgres:secureorpheus123@localhost:5432/app_development",
            ),
            clickhouse_url: value("CLICKHOUSE_URL", "http://localhost:8123"),
            clickhouse_database: value("CLICKHOUSE_DATABASE", "hackatime"),
            clickhouse_user: value("CLICKHOUSE_USER", "default"),
            clickhouse_password: value("CLICKHOUSE_PASSWORD", ""),
            cors_origin: value("CORS_ORIGIN", "http://localhost:5173"),
            stats_api_key: env::var("STATS_API_KEY")
                .ok()
                .filter(|value| !value.is_empty()),
        })
    }
}

fn value(name: &str, default: &str) -> String {
    env::var(name).unwrap_or_else(|_| default.to_owned())
}
