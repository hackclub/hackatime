use std::time::Duration;

use clickhouse::Client;
use moka::future::Cache;
use sqlx::{PgPool, postgres::PgPoolOptions};

use crate::{config::Config, error::Result, heartbeat::HeartbeatStore};

pub type SummaryGroups = (Vec<(String, i64)>, Vec<(String, i64)>);

#[derive(Clone)]
pub struct AppState {
    pub postgres: PgPool,
    pub heartbeats: HeartbeatStore,
    pub summary_cache: Cache<(i64, u64, u64), SummaryGroups>,
    pub stats_api_key: Option<String>,
}

impl AppState {
    pub async fn connect(config: &Config) -> Result<Self> {
        let postgres = PgPoolOptions::new()
            .max_connections(20)
            .connect(&config.database_url)
            .await?;
        let clickhouse = Client::default()
            .with_url(&config.clickhouse_url)
            .with_database(&config.clickhouse_database)
            .with_user(&config.clickhouse_user)
            .with_password(&config.clickhouse_password);

        let state = Self {
            postgres,
            heartbeats: HeartbeatStore::new(clickhouse),
            summary_cache: Cache::builder()
                .max_capacity(10_000)
                .time_to_live(Duration::from_secs(60))
                .build(),
            stats_api_key: config.stats_api_key.clone(),
        };
        state.heartbeats.ping().await?;
        Ok(state)
    }
}
