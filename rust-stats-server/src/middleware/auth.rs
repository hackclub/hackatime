use std::sync::Arc;

use axum::{
    extract::{Request, State},
    http::StatusCode,
    middleware::Next,
    response::Response,
};
use subtle::ConstantTimeEq;

fn tokens_match(token: &str, auth_token: &str) -> bool {
    token.as_bytes().ct_eq(auth_token.as_bytes()).into()
}

pub async fn auth_middleware(
    State(auth_token): State<Arc<str>>,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let auth_header = request
        .headers()
        .get("authorization")
        .and_then(|v| v.to_str().ok());

    match auth_header {
        Some(header) if header.starts_with("Bearer ") => {
            let token = &header[7..];
            if tokens_match(token, &auth_token) {
                Ok(next.run(request).await)
            } else {
                Err(StatusCode::UNAUTHORIZED)
            }
        }
        _ => Err(StatusCode::UNAUTHORIZED),
    }
}

#[cfg(test)]
mod tests {
    use super::tokens_match;

    #[test]
    fn matches_identical_tokens() {
        assert!(tokens_match("dev-stats-token", "dev-stats-token"));
    }

    #[test]
    fn rejects_different_tokens() {
        assert!(!tokens_match("dev-stats-token", "dev-stats-tokfn"));
    }

    #[test]
    fn rejects_different_lengths() {
        assert!(!tokens_match("dev-stats-token", "dev-stats"));
    }
}
