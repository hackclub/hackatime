use axum::{extract::Request, http::StatusCode, middleware::Next, response::Response};

pub async fn auth_middleware(request: Request, next: Next) -> Result<Response, StatusCode> {
    let auth_token = std::env::var("AUTH_TOKEN").unwrap_or_else(|_| "dev-token".to_string());

    let auth_header = request
        .headers()
        .get("authorization")
        .and_then(|v| v.to_str().ok());

    match auth_header {
        Some(header) if header.starts_with("Bearer ") => {
            let token = &header[7..];
            if token == auth_token {
                Ok(next.run(request).await)
            } else {
                Err(StatusCode::UNAUTHORIZED)
            }
        }
        _ => Err(StatusCode::UNAUTHORIZED),
    }
}
