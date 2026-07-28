mod api;
mod config;
mod date;
mod error;
mod heartbeat;
mod models;
mod state;
mod users;

use std::time::Duration;

use axum::{
    Router,
    http::{HeaderValue, Method},
    routing::{get, post},
};
use config::Config;
use error::Result;
use state::AppState;
use tower_http::{
    catch_panic::CatchPanicLayer, compression::CompressionLayer, cors::CorsLayer, trace::TraceLayer,
};
use tracing_subscriber::{EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::{
    Modify, OpenApi,
    openapi::security::{ApiKey, ApiKeyValue, SecurityScheme},
};
use utoipa_swagger_ui::SwaggerUi;

use crate::{
    api::{
        api_keys, authenticated_hours, authenticated_projects, authenticated_streak, badge,
        banned_user_counts, currently_hacking, daily_leaderboard, global_stats, health,
        latest_heartbeat, lookup_email, lookup_slack_uid, me, most_recent_heartbeat, my_heartbeats,
        push_heartbeat, push_heartbeats_bulk, stats_last_seven_days, statusbar_today, summary,
        user_project, user_projects, user_projects_details, user_spans, user_stats,
        user_trust_factor, weekly_leaderboard,
    },
    error::ErrorResponse,
    heartbeat::{HeartbeatRow, LatestHeartbeat},
    models::{HeartbeatInput, ProjectDetails, Span, TrustFactor},
};

#[derive(OpenApi)]
#[openapi(
    paths(
        api::health,
        api::push_heartbeat,
        api::push_heartbeats_bulk,
        api::me,
        api::authenticated_hours,
        api::authenticated_streak,
        api::authenticated_projects,
        api::api_keys,
        api::latest_heartbeat,
        api::my_heartbeats,
        api::most_recent_heartbeat,
        api::user_spans,
        api::user_stats,
        api::user_projects,
        api::user_projects_details,
        api::user_project,
        api::user_trust_factor,
        api::summary,
        api::statusbar_today,
        api::stats_last_seven_days,
        api::global_stats,
        api::banned_user_counts,
        api::lookup_email,
        api::lookup_slack_uid,
        api::badge,
        api::currently_hacking,
        api::daily_leaderboard,
        api::weekly_leaderboard
    ),
    components(schemas(
        ErrorResponse,
        HeartbeatInput,
        HeartbeatRow,
        LatestHeartbeat,
        ProjectDetails,
        Span,
        TrustFactor
    )),
    modifiers(&SecurityAddon),
    tags(
        (name = "heartbeats", description = "heartbeat ingestion and analytics"),
        (name = "users", description = "user stats and identity")
    )
)]
struct ApiDoc;

struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        openapi.components.as_mut().unwrap().add_security_scheme(
            "api_key",
            SecurityScheme::ApiKey(ApiKey::Header(ApiKeyValue::new("Authorization"))),
        );
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::registry()
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("hackatime=info,tower_http=info")),
        )
        .with(tracing_subscriber::fmt::layer().json())
        .init();

    let config = Config::from_env()?;
    let state = AppState::connect(&config).await?;
    let origin = config
        .cors_origin
        .parse::<HeaderValue>()
        .map_err(|error| error::AppError::Config(format!("invalid CORS_ORIGIN: {error}")))?;
    let cors = CorsLayer::new()
        .allow_origin(origin)
        .allow_methods([Method::GET, Method::POST, Method::PATCH, Method::DELETE])
        .allow_headers([
            axum::http::header::AUTHORIZATION,
            axum::http::header::CONTENT_TYPE,
        ])
        .max_age(Duration::from_secs(3600));

    let app = Router::new()
        .route("/up", get(health))
        .route(
            "/api/hackatime/v1/users/{id}/heartbeats",
            post(push_heartbeat),
        )
        .route(
            "/api/hackatime/v1/users/{id}/heartbeats.bulk",
            post(push_heartbeats_bulk),
        )
        .route(
            "/api/hackatime/v1/users/{id}/statusbar/today",
            get(statusbar_today),
        )
        .route("/api/v1/authenticated/me", get(me))
        .route("/api/v1/authenticated/hours", get(authenticated_hours))
        .route("/api/v1/authenticated/streak", get(authenticated_streak))
        .route(
            "/api/v1/authenticated/projects",
            get(authenticated_projects),
        )
        .route("/api/v1/authenticated/api_keys", get(api_keys))
        .route(
            "/api/v1/authenticated/heartbeats/latest",
            get(latest_heartbeat),
        )
        .route("/api/v1/my/heartbeats", get(my_heartbeats))
        .route(
            "/api/v1/my/heartbeats/most_recent",
            get(most_recent_heartbeat),
        )
        .route("/api/v1/users/{username}/heartbeats/spans", get(user_spans))
        .route("/api/v1/users/{username}/stats", get(user_stats))
        .route(
            "/api/v1/users/{username}/trust_factor",
            get(user_trust_factor),
        )
        .route("/api/v1/users/{username}/projects", get(user_projects))
        .route(
            "/api/v1/users/{username}/projects/details",
            get(user_projects_details),
        )
        .route(
            "/api/v1/users/{username}/project/{project_name}",
            get(user_project),
        )
        .route("/api/summary", get(summary))
        .route(
            "/api/hackatime/v1/users/current/stats/last_7_days",
            get(stats_last_seven_days),
        )
        .route("/api/v1/stats", get(global_stats))
        .route("/api/v1/banned_users/counts", get(banned_user_counts))
        .route("/api/v1/users/lookup_email/{email}", get(lookup_email))
        .route(
            "/api/v1/users/lookup_slack_uid/{slack_uid}",
            get(lookup_slack_uid),
        )
        .route("/api/v1/badge/{user_id}/{*project}", get(badge))
        .route("/api/v1/currently_hacking", get(currently_hacking))
        .route("/api/v1/leaderboard", get(daily_leaderboard))
        .route("/api/v1/leaderboard/daily", get(daily_leaderboard))
        .route("/api/v1/leaderboard/weekly", get(weekly_leaderboard))
        .merge(SwaggerUi::new("/api-docs").url("/api-docs/openapi.json", ApiDoc::openapi()))
        .layer(CatchPanicLayer::new())
        .layer(CompressionLayer::new())
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(config.bind)
        .await
        .map_err(|error| {
            error::AppError::Config(format!("failed to bind {}: {error}", config.bind))
        })?;
    tracing::info!(address = %config.bind, "server listening");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown())
        .await
        .map_err(|error| error::AppError::Config(format!("server failed: {error}")))?;
    Ok(())
}

async fn shutdown() {
    let control_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("control-c handler installs");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("terminate handler installs")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        () = control_c => {}
        () = terminate => {}
    }
}
