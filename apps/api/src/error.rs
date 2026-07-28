use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use thiserror::Error;
use utoipa::ToSchema;

pub type Result<T, E = AppError> = std::result::Result<T, E>;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("{0}")]
    BadRequest(String),
    #[error("{0}")]
    Config(String),
    #[error("{0}")]
    Forbidden(String),
    #[error("{0}")]
    NotFound(String),
    #[error("{0}")]
    ServiceUnavailable(String),
    #[error("{0}")]
    Unauthorized(String),
    #[error("{0}")]
    Unprocessable(String),
    #[error(transparent)]
    ClickHouse(#[from] clickhouse::error::Error),
    #[error(transparent)]
    Postgres(#[from] sqlx::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}

#[derive(Serialize, ToSchema)]
pub struct ErrorResponse {
    pub error: String,
}

impl AppError {
    pub fn unauthorized() -> Self {
        Self::Unauthorized("Unauthorized".to_owned())
    }

    pub fn user_not_found() -> Self {
        Self::NotFound("User not found".to_owned())
    }

    fn status(&self) -> StatusCode {
        match self {
            Self::BadRequest(_) | Self::Config(_) => StatusCode::BAD_REQUEST,
            Self::Forbidden(_) => StatusCode::FORBIDDEN,
            Self::NotFound(_) => StatusCode::NOT_FOUND,
            Self::ServiceUnavailable(_) => StatusCode::SERVICE_UNAVAILABLE,
            Self::Unauthorized(_) => StatusCode::UNAUTHORIZED,
            Self::Unprocessable(_) => StatusCode::UNPROCESSABLE_ENTITY,
            Self::ClickHouse(_) | Self::Postgres(_) | Self::Json(_) => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status = self.status();
        if status.is_server_error() {
            tracing::error!(error = ?self, "request failed");
        }

        let message = if status == StatusCode::INTERNAL_SERVER_ERROR {
            "Internal server error".to_owned()
        } else {
            self.to_string()
        };

        (status, Json(ErrorResponse { error: message })).into_response()
    }
}
