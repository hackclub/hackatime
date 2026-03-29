mod config;
mod db;
mod error;
mod middleware;
mod models;
mod query;
mod routes;
mod state;

use config::Config;
use state::AppState;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("info".parse().unwrap()))
        .init();

    let config = Config::from_env();

    tracing::info!("Connecting to database...");
    let pool = db::create_pool(&config.database_url).await;
    tracing::info!("Database connected");

    let app = routes::create_router(AppState {
        pool,
        auth_token: config.auth_token.into(),
    });

    let listener = tokio::net::TcpListener::bind(&config.listen_addr)
        .await
        .expect("Failed to bind to address");

    tracing::info!("Stats server listening on {}", config.listen_addr);
    axum::serve(listener, app).await.expect("Server error");
}
