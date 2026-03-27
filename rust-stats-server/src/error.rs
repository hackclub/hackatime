use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

pub enum AppError {
    BadRequest(String),
    Unauthorized,
    Internal(String),
    Database(sqlx::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message) = match self {
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "INVALID_PARAM", msg),
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "UNAUTHORIZED",
                "Invalid or missing auth token".to_string(),
            ),
            AppError::Internal(msg) => {
                (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", msg)
            }
            AppError::Database(e) => {
                tracing::error!("Database error: {:?}", e);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "DATABASE_ERROR",
                    "Internal database error".to_string(),
                )
            }
        };
        (status, Json(json!({"error": message, "code": code}))).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(e: sqlx::Error) -> Self {
        AppError::Database(e)
    }
}
