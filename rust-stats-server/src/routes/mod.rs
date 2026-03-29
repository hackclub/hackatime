use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{middleware, Json, Router};
use serde_json::json;

pub mod batch;
pub mod boundary_aware;
pub mod daily_durations;
pub mod duration;
pub mod health;
pub mod leaderboard;
pub mod profile;
pub mod spans;
pub mod streaks;
pub mod summary;
pub mod unique_seconds;

use crate::middleware::auth::auth_middleware;
use crate::state::AppState;

async fn _not_implemented() -> (StatusCode, Json<serde_json::Value>) {
    (
        StatusCode::NOT_IMPLEMENTED,
        Json(json!({"error": "Not yet implemented", "code": "NOT_IMPLEMENTED"})),
    )
}

pub fn create_router(state: AppState) -> Router {
    let api_routes = Router::new()
        .route("/api/v1/duration", post(duration::duration))
        .route("/api/v1/duration/grouped", post(duration::duration_grouped))
        .route(
            "/api/v1/duration/boundary-aware",
            post(boundary_aware::boundary_aware),
        )
        .route("/api/v1/duration/batch", post(batch::batch))
        .route("/api/v1/spans", post(spans::spans))
        .route(
            "/api/v1/daily-durations",
            post(daily_durations::daily_durations),
        )
        .route("/api/v1/streaks", post(streaks::streaks))
        .route("/api/v1/stats/summary", post(summary::summary))
        .route("/api/v1/stats/profile", post(profile::profile))
        .route(
            "/api/v1/leaderboard/compute",
            post(leaderboard::leaderboard_compute),
        )
        .route(
            "/api/v1/unique-seconds",
            post(unique_seconds::unique_seconds),
        )
        .layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ));

    Router::new()
        .route("/health", get(health::health))
        .merge(api_routes)
        .with_state(state)
}
