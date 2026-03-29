use std::sync::Arc;

use axum::extract::FromRef;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub auth_token: Arc<str>,
}

impl FromRef<AppState> for PgPool {
    fn from_ref(state: &AppState) -> Self {
        state.pool.clone()
    }
}

impl FromRef<AppState> for Arc<str> {
    fn from_ref(state: &AppState) -> Self {
        Arc::clone(&state.auth_token)
    }
}
