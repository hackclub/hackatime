use axum::extract::State;
use axum::Json;
use serde_json::{json, Value};
use sqlx::PgPool;

pub async fn health(State(pool): State<PgPool>) -> Json<Value> {
    let db_connected = sqlx::query("SELECT 1").fetch_one(&pool).await.is_ok();

    Json(json!({
        "status": if db_connected { "ok" } else { "degraded" },
        "db_connected": db_connected,
        "version": env!("CARGO_PKG_VERSION")
    }))
}
