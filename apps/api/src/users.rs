use axum::http::HeaderMap;
use sqlx::PgPool;

use crate::{
    error::{AppError, Result},
    models::{TrustFactor, User},
};

pub async fn authenticated_user(pool: &PgPool, headers: &HeaderMap) -> Result<User> {
    let value = headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .ok_or_else(AppError::unauthorized)?;
    let token = value
        .strip_prefix("Bearer ")
        .or_else(|| value.strip_prefix("bearer "))
        .ok_or_else(AppError::unauthorized)?;

    let user = sqlx::query_as::<_, User>(
        "SELECT
           users.id,
           users.slack_uid,
           users.username,
           users.github_username,
           users.timezone,
           users.trust_level,
           users.allow_public_stats_lookup
         FROM users
         INNER JOIN api_keys ON api_keys.user_id = users.id
         WHERE api_keys.token = $1
         LIMIT 1",
    )
    .bind(token)
    .fetch_optional(pool)
    .await?
    .ok_or_else(AppError::unauthorized)?;

    Ok(user)
}

pub async fn find_user(pool: &PgPool, identifier: &str) -> Result<User> {
    let numeric_id = identifier.parse::<i64>().ok();
    sqlx::query_as::<_, User>(
        "SELECT
           id,
           slack_uid,
           username,
           github_username,
           timezone,
           trust_level,
           allow_public_stats_lookup
         FROM users
         WHERE id = $1
            OR slack_uid = $2
            OR hca_id = $2
            OR username = $2
         ORDER BY
           CASE
             WHEN id = $1 THEN 0
             WHEN slack_uid = $2 THEN 1
             WHEN hca_id = $2 THEN 2
             ELSE 3
           END
         LIMIT 1",
    )
    .bind(numeric_id.unwrap_or(-1))
    .bind(identifier)
    .fetch_optional(pool)
    .await?
    .ok_or_else(AppError::user_not_found)
}

pub async fn target_user(pool: &PgPool, headers: &HeaderMap, identifier: &str) -> Result<User> {
    if identifier == "my" {
        authenticated_user(pool, headers).await
    } else {
        find_user(pool, identifier).await
    }
}

pub fn trust_factor(user: &User) -> TrustFactor {
    let (trust_level, trust_value) = match user.trust_level {
        1 => ("red", 1),
        2 => ("green", 2),
        _ => ("blue", 0),
    };
    TrustFactor {
        trust_level: trust_level.to_owned(),
        trust_value,
    }
}

pub async fn ensure_public_or_self(pool: &PgPool, headers: &HeaderMap, user: &User) -> Result<()> {
    if user.allow_public_stats_lookup {
        return Ok(());
    }
    if authenticated_user(pool, headers)
        .await
        .is_ok_and(|caller| caller.id == user.id)
    {
        return Ok(());
    }
    Err(AppError::Forbidden(
        "user has disabled public stats".to_owned(),
    ))
}
