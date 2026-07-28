use std::collections::BTreeMap;

use axum::{
    Json,
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Redirect, Response},
};
use chrono::{Days, NaiveDate, Utc};
use chrono_tz::Tz;
use serde::Serialize;
use serde_json::{Value, json};
use sqlx::FromRow;
use utoipa::ToSchema;

use crate::{
    date::{
        explicit_day_range, interval_range, local_date_range, local_day_range, parse_datetime,
        parse_range,
    },
    error::{AppError, ErrorResponse, Result},
    heartbeat::{HeartbeatFilter, HeartbeatRow, LatestHeartbeat},
    models::{
        BadgeQuery, GlobalStatsQuery, HeartbeatInput, HoursQuery, MostRecentQuery,
        MyHeartbeatsQuery, ProjectDetails, ProjectsQuery, Span, SpansQuery, StatsQuery,
        SummaryQuery, TrustFactor,
    },
    state::AppState,
    users::{authenticated_user, ensure_public_or_self, find_user, target_user, trust_factor},
};

const TEN_YEARS_SECONDS: f64 = 3652.5 * 86_400.0;

#[derive(Serialize, ToSchema)]
pub struct HealthResponse {
    status: &'static str,
}

#[derive(Serialize, ToSchema)]
pub struct SpansResponse {
    spans: Vec<Span>,
}

#[derive(Serialize, ToSchema)]
pub struct TotalSecondsResponse {
    total_seconds: i64,
}

#[derive(Serialize, ToSchema)]
pub struct ProjectsResponse {
    projects: Vec<String>,
}

#[derive(Serialize, ToSchema)]
pub struct ProjectDetailsResponse {
    projects: Vec<ProjectDetails>,
}

#[derive(Serialize, ToSchema)]
pub struct MeResponse {
    id: i64,
    emails: Vec<String>,
    slack_id: Option<String>,
    github_username: Option<String>,
    trust_factor: TrustFactor,
}

#[derive(Serialize, ToSchema)]
pub struct ApiKeyResponse {
    token: String,
}

#[derive(Serialize, ToSchema)]
pub struct GroupTotal {
    key: String,
    total: i64,
}

#[derive(Serialize, ToSchema)]
pub struct SummaryResponse {
    user_id: Option<String>,
    from: String,
    to: String,
    projects: Vec<GroupTotal>,
    languages: Vec<GroupTotal>,
    editors: BTreeMap<String, Value>,
    operating_systems: BTreeMap<String, Value>,
    machines: BTreeMap<String, Value>,
    categories: BTreeMap<String, Value>,
    branches: BTreeMap<String, Value>,
    entities: BTreeMap<String, Value>,
    labels: BTreeMap<String, Value>,
}

#[derive(Serialize, ToSchema)]
pub struct HeartbeatListResponse {
    start_time: String,
    end_time: String,
    total_seconds: i64,
    heartbeats: Vec<Value>,
}

#[derive(Serialize, ToSchema)]
pub struct HoursResponse {
    start_date: String,
    end_date: String,
    total_seconds: i64,
}

#[derive(Serialize, ToSchema)]
pub struct StreakResponse {
    streak_days: usize,
}

#[derive(FromRow)]
struct Leaderboard {
    id: i64,
    period_type: i32,
    start_date: NaiveDate,
    finished_generating_at: Option<chrono::NaiveDateTime>,
}

#[derive(FromRow)]
struct LeaderboardEntry {
    user_id: i64,
    display_name: Option<String>,
    avatar_url: Option<String>,
    total_seconds: i32,
}

#[derive(FromRow)]
struct ActiveUserProfile {
    id: i64,
    display_name: Option<String>,
    avatar_url: Option<String>,
    country_code: Option<String>,
}

#[utoipa::path(
    get,
    path = "/up",
    responses((status = 200, body = HealthResponse))
)]
pub async fn health() -> Json<HealthResponse> {
    Json(HealthResponse { status: "ok" })
}

#[utoipa::path(
    get,
    path = "/api/v1/authenticated/hours",
    params(HoursQuery),
    responses(
        (status = 200, body = HoursResponse),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn authenticated_hours(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<HoursQuery>,
) -> Result<Json<HoursResponse>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let timezone = user_timezone(&user);
    let today = Utc::now().with_timezone(&timezone).date_naive();
    let start_date = parse_date(
        query.start_date.as_deref(),
        today - Days::new(7),
        "start_date",
    )?;
    let end_date = parse_date(query.end_date.as_deref(), today, "end_date")?;
    if start_date > end_date {
        return Err(AppError::Unprocessable(
            "start_date must not be after end_date".to_owned(),
        ));
    }
    let (start, end) = local_date_range(user.timezone.as_deref(), start_date, end_date);
    let total_seconds = state
        .heartbeats
        .duration(user.id, start, end, &HeartbeatFilter::default())
        .await?;
    Ok(Json(HoursResponse {
        start_date: start_date.to_string(),
        end_date: end_date.to_string(),
        total_seconds,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/authenticated/streak",
    responses(
        (status = 200, body = StreakResponse),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn authenticated_streak(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<StreakResponse>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let timezone = user_timezone(&user);
    let today = Utc::now().with_timezone(&timezone).date_naive();
    let (start, end) = local_date_range(user.timezone.as_deref(), today - Days::new(31), today);
    let days = state
        .heartbeats
        .daily_durations(user.id, start, end, timezone.name())
        .await?;
    let eligible = days
        .into_iter()
        .filter(|day| day.total_seconds >= 900.0)
        .filter_map(|day| NaiveDate::parse_from_str(&day.day, "%Y-%m-%d").ok())
        .collect::<Vec<_>>();
    let mut expected = if eligible.last() == Some(&today) {
        today
    } else {
        today - Days::new(1)
    };
    let mut streak_days = 0;
    for day in eligible.into_iter().rev() {
        if day == expected {
            streak_days += 1;
            expected = expected - Days::new(1);
        } else if day < expected {
            break;
        }
    }
    Ok(Json(StreakResponse { streak_days }))
}

#[utoipa::path(
    get,
    path = "/api/v1/authenticated/projects",
    params(ProjectsQuery),
    responses(
        (status = 200),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn authenticated_projects(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ProjectsQuery>,
) -> Result<Json<Value>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let (start, end) = project_stats_range_with_defaults(&query, 0.0, end_of_today())?;
    let projects = query.projects.as_deref().map(csv).unwrap_or_default();
    let projects = state
        .heartbeats
        .project_details(user.id, start, end, projects)
        .await?;
    let archived = sqlx::query_scalar::<_, String>(
        "SELECT project_name
         FROM project_repo_mappings
         WHERE user_id = $1
           AND archived_at IS NOT NULL",
    )
    .bind(user.id)
    .fetch_all(&state.postgres)
    .await?;
    let include_archived = query.include_archived.unwrap_or(false);
    let projects = projects
        .into_iter()
        .filter(|project| include_archived || !archived.contains(&project.name))
        .map(|project| {
            let is_archived = archived.contains(&project.name);
            json!({
                "name": project.name,
                "total_seconds": project.total_seconds,
                "most_recent_heartbeat": project.most_recent_heartbeat,
                "languages": project.languages,
                "archived": is_archived
            })
        })
        .collect::<Vec<_>>();
    Ok(Json(json!({ "projects": projects })))
}

#[utoipa::path(
    post,
    path = "/api/hackatime/v1/users/{id}/heartbeats",
    request_body = Vec<HeartbeatInput>,
    params(("id" = String, Path)),
    responses(
        (status = 202, body = HeartbeatRow),
        (status = 400, body = ErrorResponse),
        (status = 401, body = ErrorResponse),
        (status = 422, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn push_heartbeat(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<impl IntoResponse> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let mut heartbeats = heartbeat_inputs(body)?;
    let input = heartbeats
        .drain(..)
        .next()
        .ok_or_else(|| AppError::BadRequest("No data provided...".to_owned()))?;
    let row = insert_heartbeat(&state, &headers, user.id, input).await;
    match row {
        Ok(row) => Ok((StatusCode::ACCEPTED, Json(public_heartbeat(row)))),
        Err(error @ AppError::Unprocessable(_)) => {
            let body = json!({
                "error": error.to_string(),
                "type": "HeartbeatIngest::InvalidHeartbeatTime"
            });
            Ok((StatusCode::UNPROCESSABLE_ENTITY, Json(body)))
        }
        Err(error) => Err(error),
    }
}

#[utoipa::path(
    post,
    path = "/api/hackatime/v1/users/{id}/heartbeats.bulk",
    request_body = Vec<HeartbeatInput>,
    params(("id" = String, Path)),
    responses(
        (status = 201),
        (status = 400, body = ErrorResponse),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn push_heartbeats_bulk(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(_id): Path<String>,
    Json(body): Json<Value>,
) -> Result<impl IntoResponse> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let heartbeats = heartbeat_inputs(body)?;
    if heartbeats.is_empty() {
        return Err(AppError::BadRequest("No data provided...".to_owned()));
    }
    if heartbeats.len() > 100 {
        return Err(AppError::BadRequest(
            "Too many heartbeats in a single request (max 100)".to_owned(),
        ));
    }

    let mut responses = Vec::with_capacity(heartbeats.len());
    for heartbeat in heartbeats {
        match insert_heartbeat(&state, &headers, user.id, heartbeat).await {
            Ok(row) => responses.push(json!([public_heartbeat(row), 201])),
            Err(error) => responses.push(json!([
                {
                    "error": error.to_string(),
                    "type": "HeartbeatIngest::InvalidHeartbeatTime"
                },
                422
            ])),
        }
    }
    Ok((StatusCode::CREATED, Json(json!({ "responses": responses }))))
}

#[utoipa::path(
    get,
    path = "/api/v1/authenticated/me",
    responses(
        (status = 200, body = MeResponse),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn me(State(state): State<AppState>, headers: HeaderMap) -> Result<Json<MeResponse>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let emails = sqlx::query_scalar::<_, Option<String>>(
        "SELECT email FROM email_addresses WHERE user_id = $1 ORDER BY id",
    )
    .bind(user.id)
    .fetch_all(&state.postgres)
    .await?
    .into_iter()
    .flatten()
    .collect();
    Ok(Json(MeResponse {
        id: user.id,
        emails,
        slack_id: user.slack_uid.clone(),
        github_username: user.github_username.clone(),
        trust_factor: trust_factor(&user),
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/authenticated/api_keys",
    responses(
        (status = 200, body = ApiKeyResponse),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn api_keys(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ApiKeyResponse>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let token = sqlx::query_scalar::<_, String>(
        "SELECT token FROM api_keys WHERE user_id = $1 ORDER BY id LIMIT 1",
    )
    .bind(user.id)
    .fetch_one(&state.postgres)
    .await?;
    Ok(Json(ApiKeyResponse { token }))
}

#[utoipa::path(
    get,
    path = "/api/v1/authenticated/heartbeats/latest",
    responses(
        (status = 200, body = LatestHeartbeat),
        (status = 401, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn latest_heartbeat(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<LatestHeartbeat>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    state
        .heartbeats
        .latest(user.id)
        .await?
        .map(Json)
        .ok_or_else(|| AppError::NotFound("No heartbeats found".to_owned()))
}

#[utoipa::path(
    get,
    path = "/api/v1/my/heartbeats",
    params(MyHeartbeatsQuery),
    responses(
        (status = 200, body = HeartbeatListResponse),
        (status = 401, body = ErrorResponse),
        (status = 422, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn my_heartbeats(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<MyHeartbeatsQuery>,
) -> Result<Json<HeartbeatListResponse>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let (day_start, day_end) = local_day_range(Some("UTC"));
    let start = query
        .start_time
        .as_deref()
        .map(|value| parse_datetime(value, "start_time"))
        .transpose()?
        .unwrap_or(day_start);
    let end = query
        .end_time
        .as_deref()
        .map(|value| parse_datetime(value, "end_time"))
        .transpose()?
        .unwrap_or(day_end);
    let rows = state.heartbeats.list(user.id, start, end).await?;
    let total_seconds = state
        .heartbeats
        .duration(user.id, start, end, &HeartbeatFilter::default())
        .await?;
    Ok(Json(HeartbeatListResponse {
        start_time: format_timestamp_millis(start),
        end_time: format_timestamp_millis(end),
        total_seconds,
        heartbeats: rows.into_iter().map(public_heartbeat).collect(),
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/my/heartbeats/most_recent",
    params(MostRecentQuery),
    responses(
        (status = 200),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn most_recent_heartbeat(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<MostRecentQuery>,
) -> Result<Json<Value>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let source_type = query
        .source_type
        .as_deref()
        .map(parse_source_type)
        .transpose()?;
    let heartbeat = state
        .heartbeats
        .most_recent(user.id, source_type, query.editor.as_deref())
        .await?;
    let editor = heartbeat.as_ref().and_then(|row| row.editor.clone());
    let time_ago = heartbeat
        .as_ref()
        .map(|row| human_time_ago(Utc::now().timestamp() as f64 - row.time));
    Ok(Json(json!({
        "has_heartbeat": heartbeat.is_some(),
        "heartbeat": heartbeat.map(public_heartbeat),
        "editor": editor,
        "time_ago": time_ago
    })))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/{username}/heartbeats/spans",
    params(
        ("username" = String, Path),
        SpansQuery
    ),
    responses(
        (status = 200, body = SpansResponse),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse),
        (status = 422, body = ErrorResponse)
    )
)]
pub async fn user_spans(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(username): Path<String>,
    Query(query): Query<SpansQuery>,
) -> Result<Json<SpansResponse>> {
    let user = target_user(&state.postgres, &headers, &username).await?;
    ensure_public_or_self(&state.postgres, &headers, &user).await?;
    let now = Utc::now().timestamp() as f64;
    let (start, end) = parse_range(
        query.start_date.as_deref(),
        query.end_date.as_deref(),
        now - TEN_YEARS_SECONDS,
        end_of_today(),
    )?;
    let projects = query
        .project
        .map(|project| vec![project])
        .or_else(|| query.filter_by_project.map(|value| csv(&value)))
        .unwrap_or_default();
    Ok(Json(SpansResponse {
        spans: state
            .heartbeats
            .spans(user.id, start, end, projects)
            .await?,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/{username}/stats",
    params(("username" = String, Path), StatsQuery),
    responses(
        (status = 200, body = TotalSecondsResponse),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse),
        (status = 422, body = ErrorResponse)
    )
)]
pub async fn user_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(username): Path<String>,
    Query(query): Query<StatsQuery>,
) -> Result<Json<Value>> {
    let user = target_user(&state.postgres, &headers, &username).await?;
    ensure_public_or_self(&state.postgres, &headers, &user).await?;
    let now = Utc::now().timestamp() as f64;
    let (start, end) = parse_range(
        query.start_date.as_deref(),
        query.end_date.as_deref(),
        now - TEN_YEARS_SECONDS,
        end_of_today(),
    )?;
    let filter = HeartbeatFilter {
        projects: query
            .filter_by_project
            .as_deref()
            .map(csv)
            .unwrap_or_default(),
        categories: query
            .filter_by_category
            .as_deref()
            .map(csv)
            .unwrap_or_default(),
        no_ai_coding: query.no_ai_coding.unwrap_or(false),
    };
    let total_seconds = state
        .heartbeats
        .duration(user.id, start, end, &filter)
        .await?;

    if query.total_seconds.unwrap_or(false) {
        return Ok(Json(json!({ "total_seconds": total_seconds })));
    }

    let features = query
        .features
        .as_deref()
        .map(csv)
        .unwrap_or_else(|| vec!["languages".to_owned()]);
    let mut data = serde_json::Map::new();
    data.insert("total_seconds".to_owned(), json!(total_seconds));
    data.insert(
        "start".to_owned(),
        json!(format_timestamp(start, "%Y-%m-%dT%H:%M:%SZ")),
    );
    data.insert(
        "end".to_owned(),
        json!(format_timestamp(end, "%Y-%m-%dT%H:%M:%SZ")),
    );
    for field in ["languages", "projects"] {
        if features.iter().any(|feature| feature == field) {
            let singular = &field[..field.len() - 1];
            let groups = state
                .heartbeats
                .grouped_durations(user.id, start, end, singular)
                .await?;
            data.insert(
                field.to_owned(),
                json!(
                    groups
                        .into_iter()
                        .map(|(name, total_seconds)| json!({
                            "name": name,
                            "total_seconds": total_seconds
                        }))
                        .collect::<Vec<_>>()
                ),
            );
        }
    }
    data.insert("streak".to_owned(), json!(0));
    Ok(Json(json!({
        "data": data,
        "trust_factor": trust_factor(&user)
    })))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/{username}/projects",
    params(("username" = String, Path), ProjectsQuery),
    responses(
        (status = 200, body = ProjectsResponse),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    )
)]
pub async fn user_projects(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(username): Path<String>,
    Query(query): Query<ProjectsQuery>,
) -> Result<Json<ProjectsResponse>> {
    let user = target_user(&state.postgres, &headers, &username).await?;
    ensure_public_or_self(&state.postgres, &headers, &user).await?;
    let now = Utc::now().timestamp() as f64;
    let start = first_time(
        [
            query.since.as_deref(),
            query.start.as_deref(),
            query.start_date.as_deref(),
        ],
        now - 30.0 * 86_400.0,
        "start_date",
    )?;
    let end = first_time(
        [
            query.until.as_deref(),
            query.until_date.as_deref(),
            query.end.as_deref(),
            query.end_date.as_deref(),
        ],
        now,
        "end_date",
    )?;
    Ok(Json(ProjectsResponse {
        projects: state.heartbeats.project_names(user.id, start, end).await?,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/{username}/projects/details",
    params(("username" = String, Path), ProjectsQuery),
    responses(
        (status = 200, body = ProjectDetailsResponse),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    )
)]
pub async fn user_projects_details(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(username): Path<String>,
    Query(query): Query<ProjectsQuery>,
) -> Result<Json<ProjectDetailsResponse>> {
    let user = target_user(&state.postgres, &headers, &username).await?;
    ensure_public_or_self(&state.postgres, &headers, &user).await?;
    let (start, end) = project_stats_range(&query)?;
    let projects = query.projects.as_deref().map(csv).unwrap_or_default();
    Ok(Json(ProjectDetailsResponse {
        projects: state
            .heartbeats
            .project_details(user.id, start, end, projects)
            .await?,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/{username}/project/{project_name}",
    params(
        ("username" = String, Path),
        ("project_name" = String, Path),
        ProjectsQuery
    ),
    responses(
        (status = 200, body = ProjectDetails),
        (status = 400, body = ErrorResponse),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    )
)]
pub async fn user_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((username, project_name)): Path<(String, String)>,
    Query(query): Query<ProjectsQuery>,
) -> Result<Json<ProjectDetails>> {
    if project_name.trim().is_empty() {
        return Err(AppError::BadRequest("whats the name?".to_owned()));
    }
    let user = target_user(&state.postgres, &headers, &username).await?;
    ensure_public_or_self(&state.postgres, &headers, &user).await?;
    let (start, end) = project_stats_range(&query)?;
    state
        .heartbeats
        .project_details(user.id, start, end, vec![project_name])
        .await?
        .into_iter()
        .next()
        .map(Json)
        .ok_or_else(|| AppError::NotFound("found nuthin".to_owned()))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/{username}/trust_factor",
    params(("username" = String, Path)),
    responses(
        (status = 200, body = TrustFactor),
        (status = 404, body = ErrorResponse)
    )
)]
pub async fn user_trust_factor(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> Result<Json<TrustFactor>> {
    let user = find_user(&state.postgres, &username).await?;
    Ok(Json(trust_factor(&user)))
}

#[utoipa::path(
    get,
    path = "/api/summary",
    params(SummaryQuery),
    responses(
        (status = 200, body = SummaryResponse),
        (status = 400, body = ErrorResponse),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    )
)]
pub async fn summary(
    State(state): State<AppState>,
    Query(query): Query<SummaryQuery>,
) -> Result<Json<SummaryResponse>> {
    let identifier = query
        .user_id
        .as_deref()
        .or(query.user.as_deref())
        .ok_or_else(|| AppError::BadRequest("Missing required parameter: user_id".to_owned()))?;
    let user = find_user(&state.postgres, identifier).await?;
    if !user.allow_public_stats_lookup {
        return Err(AppError::Forbidden(
            "User has disabled public stats".to_owned(),
        ));
    }
    let explicit_start = query.from.as_deref().or(query.start.as_deref());
    let explicit_end = query.to.as_deref().or(query.end.as_deref());
    let (start, end) = match (explicit_start, explicit_end) {
        (Some(start), Some(end)) => explicit_day_range(start, end)?,
        _ => interval_range(query.interval.as_deref().or(query.range.as_deref())),
    };
    let cache_key = (user.id, start.to_bits(), end.to_bits());
    let (projects, languages) = if let Some(groups) = state.summary_cache.get(&cache_key).await {
        groups
    } else {
        let groups = tokio::try_join!(
            state
                .heartbeats
                .grouped_durations(user.id, start, end, "project"),
            state
                .heartbeats
                .grouped_durations(user.id, start, end, "language")
        )?;
        state.summary_cache.insert(cache_key, groups.clone()).await;
        groups
    };
    Ok(Json(SummaryResponse {
        user_id: query.user,
        from: format_timestamp(start, "%Y-%m-%dT%H:%M:%SZ"),
        to: format_timestamp(end, "%Y-%m-%dT%H:%M:%SZ"),
        projects: projects
            .into_iter()
            .map(|(key, total)| GroupTotal { key, total })
            .collect(),
        languages: languages
            .into_iter()
            .map(|(key, total)| GroupTotal { key, total })
            .collect(),
        editors: BTreeMap::new(),
        operating_systems: BTreeMap::new(),
        machines: BTreeMap::new(),
        categories: BTreeMap::new(),
        branches: BTreeMap::new(),
        entities: BTreeMap::new(),
        labels: BTreeMap::new(),
    }))
}

#[utoipa::path(
    get,
    path = "/api/hackatime/v1/users/{id}/statusbar/today",
    params(("id" = String, Path)),
    responses(
        (status = 200),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn statusbar_today(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(_id): Path<String>,
) -> Result<Json<Value>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let (start, end) = local_day_range(user.timezone.as_deref());
    let total_seconds = state
        .heartbeats
        .duration(user.id, start, end, &HeartbeatFilter::default())
        .await?;
    Ok(Json(json!({
        "data": {
            "grand_total": {
                "text": simple_time(total_seconds),
                "total_seconds": total_seconds
            }
        }
    })))
}

#[utoipa::path(
    get,
    path = "/api/hackatime/v1/users/current/stats/last_7_days",
    responses(
        (status = 200),
        (status = 401, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn stats_last_seven_days(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>> {
    let user = authenticated_user(&state.postgres, &headers).await?;
    let timezone = user_timezone(&user);
    let today = Utc::now().with_timezone(&timezone).date_naive();
    let start_date = today - Days::new(7);
    let (start, end) = local_date_range(user.timezone.as_deref(), start_date, today);
    let filter = HeartbeatFilter::default();
    let (total_seconds, editors, languages, machines, projects, operating_systems, days) = tokio::try_join!(
        state.heartbeats.duration(user.id, start, end, &filter),
        state
            .heartbeats
            .grouped_durations(user.id, start, end, "editor"),
        state
            .heartbeats
            .grouped_durations(user.id, start, end, "language"),
        state
            .heartbeats
            .grouped_durations(user.id, start, end, "machine"),
        state
            .heartbeats
            .grouped_durations(user.id, start, end, "project"),
        state
            .heartbeats
            .grouped_durations(user.id, start, end, "operating_system"),
        state
            .heartbeats
            .daily_durations(user.id, start, end, timezone.name())
    )?;
    let days_covered = days.len() as i64;
    let daily_average = if days_covered == 0 {
        0.0
    } else {
        (total_seconds as f64 / days_covered as f64 * 10.0).round() / 10.0
    };
    let categories = if total_seconds == 0 {
        Vec::new()
    } else {
        vec![category_stat(
            "coding".to_owned(),
            total_seconds,
            total_seconds,
        )]
    };
    Ok(Json(json!({
        "data": {
            "username": user.slack_uid,
            "user_id": user.slack_uid,
            "start": format_timestamp(start, "%Y-%m-%dT%H:%M:%SZ"),
            "end": format_timestamp(end - 0.000_001, "%Y-%m-%dT%H:%M:%SZ"),
            "status": "ok",
            "total_seconds": total_seconds,
            "daily_average": daily_average,
            "days_including_holidays": days_covered,
            "range": "last_7_days",
            "human_readable_range": "Last 7 Days",
            "human_readable_total": hours_minutes(total_seconds),
            "human_readable_daily_average": hours_minutes(daily_average as i64),
            "is_coding_activity_visible": true,
            "is_other_usage_visible": true,
            "editors": category_stats(editors),
            "languages": category_stats(languages),
            "machines": category_stats(machines),
            "projects": category_stats(projects),
            "operating_systems": category_stats(operating_systems),
            "categories": categories
        }
    })))
}

#[utoipa::path(
    get,
    path = "/api/v1/stats",
    params(GlobalStatsQuery),
    responses(
        (status = 200, content_type = "text/plain"),
        (status = 401, body = ErrorResponse),
        (status = 404, body = ErrorResponse),
        (status = 422, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn global_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<GlobalStatsQuery>,
) -> Result<String> {
    ensure_stats_key(&state, &headers)?;
    let today = Utc::now().date_naive();
    let start_date = parse_date(
        query.start_date.as_deref(),
        today - Days::new(3652),
        "start_date",
    )?;
    let end_date = parse_date(query.end_date.as_deref(), today, "end_date")?;
    let (start, end) = local_date_range(Some("UTC"), start_date, end_date);
    let user_id = match (query.username.as_deref(), query.user_email.as_deref()) {
        (Some(identifier), _) => Some(find_user(&state.postgres, identifier).await?.id),
        (_, Some(email)) => Some(
            sqlx::query_scalar::<_, i64>(
                "SELECT user_id FROM email_addresses WHERE email = $1 LIMIT 1",
            )
            .bind(email)
            .fetch_optional(&state.postgres)
            .await?
            .ok_or_else(AppError::user_not_found)?,
        ),
        _ => None,
    };
    Ok(state
        .heartbeats
        .global_duration(user_id, start, end)
        .await?
        .to_string())
}

#[utoipa::path(
    get,
    path = "/api/v1/banned_users/counts",
    responses((status = 200))
)]
pub async fn banned_user_counts(State(state): State<AppState>) -> Result<Json<Value>> {
    let counts = sqlx::query_as::<_, (i64, i64, i64)>(
        "SELECT
           COUNT(DISTINCT user_id) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day'),
           COUNT(DISTINCT user_id) FILTER (WHERE created_at >= NOW() - INTERVAL '1 week'),
           COUNT(DISTINCT user_id) FILTER (WHERE created_at >= NOW() - INTERVAL '1 month')
         FROM trust_level_audit_logs
         WHERE new_trust_level = 'red'",
    )
    .fetch_one(&state.postgres)
    .await?;
    Ok(Json(
        json!({ "day": counts.0, "week": counts.1, "month": counts.2 }),
    ))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/lookup_email/{email}",
    params(("email" = String, Path)),
    responses(
        (status = 200),
        (status = 401, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn lookup_email(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(email): Path<String>,
) -> Result<Json<Value>> {
    ensure_stats_key(&state, &headers)?;
    let user_id = sqlx::query_scalar::<_, i64>(
        "SELECT user_id FROM email_addresses WHERE email = $1 LIMIT 1",
    )
    .bind(&email)
    .fetch_optional(&state.postgres)
    .await?
    .ok_or_else(AppError::user_not_found)?;
    Ok(Json(json!({ "user_id": user_id, "email": email })))
}

#[utoipa::path(
    get,
    path = "/api/v1/users/lookup_slack_uid/{slack_uid}",
    params(("slack_uid" = String, Path)),
    responses(
        (status = 200),
        (status = 401, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    ),
    security(("api_key" = []))
)]
pub async fn lookup_slack_uid(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(slack_uid): Path<String>,
) -> Result<Json<Value>> {
    ensure_stats_key(&state, &headers)?;
    let user_id = sqlx::query_scalar::<_, i64>("SELECT id FROM users WHERE slack_uid = $1 LIMIT 1")
        .bind(&slack_uid)
        .fetch_optional(&state.postgres)
        .await?
        .ok_or_else(AppError::user_not_found)?;
    Ok(Json(json!({ "user_id": user_id, "slack_uid": slack_uid })))
}

#[utoipa::path(
    get,
    path = "/api/v1/badge/{user_id}/{project}",
    params(
        ("user_id" = String, Path),
        ("project" = String, Path),
        BadgeQuery
    ),
    responses(
        (status = 307),
        (status = 400),
        (status = 403, body = ErrorResponse),
        (status = 404, body = ErrorResponse)
    )
)]
pub async fn badge(
    State(state): State<AppState>,
    Path((identifier, project)): Path<(String, String)>,
    Query(query): Query<BadgeQuery>,
) -> Result<Response> {
    let user = find_user(&state.postgres, &identifier).await?;
    if !user.allow_public_stats_lookup {
        return Err(AppError::Forbidden(
            "User has disabled public stats".to_owned(),
        ));
    }
    let now = Utc::now().timestamp() as f64;
    let project = resolve_project(&state, user.id, &project, now).await?;
    let primary = state
        .heartbeats
        .duration(
            user.id,
            0.0,
            now,
            &HeartbeatFilter {
                projects: vec![project.clone()],
                ..HeartbeatFilter::default()
            },
        )
        .await?;
    if primary <= 0 {
        return Ok(StatusCode::BAD_REQUEST.into_response());
    }
    let aliases = query
        .aliases
        .as_deref()
        .map(csv)
        .unwrap_or_default()
        .into_iter()
        .filter(|alias| alias != &project)
        .collect::<Vec<_>>();
    let alias_seconds = if aliases.is_empty() {
        0
    } else {
        state
            .heartbeats
            .duration(
                user.id,
                0.0,
                now,
                &HeartbeatFilter {
                    projects: aliases,
                    ..HeartbeatFilter::default()
                },
            )
            .await?
    };
    let label = query.label.unwrap_or_else(|| "hackatime".to_owned());
    let color = query.color.unwrap_or_else(|| "blue".to_owned());
    let mut url = format!(
        "https://img.shields.io/badge/{}-{}-{}",
        url_component(&label),
        url_component(&badge_duration(primary + alias_seconds)),
        url_component(&color)
    );
    for (key, value) in query.extra {
        url.push('&');
        url.push_str(&url_component(&key));
        url.push('=');
        url.push_str(&url_component(&value));
    }
    Ok(Redirect::temporary(&url).into_response())
}

#[utoipa::path(
    get,
    path = "/api/v1/currently_hacking",
    responses((status = 200))
)]
pub async fn currently_hacking(State(state): State<AppState>) -> Result<Json<Value>> {
    let active = state
        .heartbeats
        .active_users(Utc::now().timestamp() as f64 - 300.0)
        .await?;
    if active.is_empty() {
        return Ok(Json(json!({ "count": 0, "users": [] })));
    }
    let ids = active.iter().map(|user| user.user_id).collect::<Vec<_>>();
    let profiles = sqlx::query_as::<_, ActiveUserProfile>(
        "SELECT
           users.id,
           COALESCE(
             users.display_name_override,
             users.slack_username,
             users.github_username,
             users.username,
             split_part(
               (SELECT email FROM email_addresses WHERE user_id = users.id ORDER BY id LIMIT 1),
               '@',
               1
             )
           ) AS display_name,
           COALESCE(users.slack_avatar_url, users.github_avatar_url) AS avatar_url,
           users.country_code
         FROM users
         WHERE users.id = ANY($1)
           AND users.allow_public_stats_lookup = TRUE
         ORDER BY users.id",
    )
    .bind(&ids)
    .fetch_all(&state.postgres)
    .await?;
    let active_by_id = active
        .into_iter()
        .map(|user| (user.user_id, user.project))
        .collect::<BTreeMap<_, _>>();
    let mut users = Vec::with_capacity(profiles.len());
    for profile in profiles {
        let project = active_by_id.get(&profile.id).cloned().flatten();
        let working_on = if let Some(project_name) = project {
            let repo_url = sqlx::query_scalar::<_, Option<String>>(
                "SELECT repo_url
                 FROM project_repo_mappings
                 WHERE user_id = $1
                   AND project_name = $2
                   AND archived_at IS NULL
                 ORDER BY id
                 LIMIT 1",
            )
            .bind(profile.id)
            .bind(&project_name)
            .fetch_optional(&state.postgres)
            .await?
            .flatten();
            Some(json!({ "project_name": project_name, "repo_url": repo_url }))
        } else {
            None
        };
        users.push(json!({
            "display_name": profile.display_name,
            "avatar_url": profile.avatar_url,
            "country_code": profile.country_code,
            "working_on": working_on
        }));
    }
    Ok(Json(json!({ "count": users.len(), "users": users })))
}

#[utoipa::path(
    get,
    path = "/api/v1/leaderboard/daily",
    responses(
        (status = 200),
        (status = 503, body = ErrorResponse)
    )
)]
pub async fn daily_leaderboard(State(state): State<AppState>) -> Result<Json<Value>> {
    leaderboard(&state, 0).await
}

#[utoipa::path(
    get,
    path = "/api/v1/leaderboard/weekly",
    responses(
        (status = 200),
        (status = 503, body = ErrorResponse)
    )
)]
pub async fn weekly_leaderboard(State(state): State<AppState>) -> Result<Json<Value>> {
    leaderboard(&state, 2).await
}

async fn insert_heartbeat(
    state: &AppState,
    headers: &HeaderMap,
    user_id: i64,
    input: HeartbeatInput,
) -> Result<HeartbeatRow> {
    state
        .heartbeats
        .insert(
            user_id,
            input,
            headers
                .get("cf-connecting-ip")
                .and_then(|value| value.to_str().ok())
                .map(ToOwned::to_owned),
            headers
                .get("user-agent")
                .and_then(|value| value.to_str().ok())
                .map(ToOwned::to_owned),
        )
        .await
}

fn heartbeat_inputs(body: Value) -> Result<Vec<HeartbeatInput>> {
    let value = body
        .get("hackatime")
        .and_then(|value| value.get("heartbeats").or(Some(value)))
        .cloned()
        .unwrap_or(body);
    match value {
        Value::Array(_) => Ok(serde_json::from_value(value)?),
        Value::Object(_) => Ok(vec![serde_json::from_value(value)?]),
        Value::Null => Ok(Vec::new()),
        _ => Err(AppError::BadRequest("No data provided...".to_owned())),
    }
}

fn public_heartbeat(row: HeartbeatRow) -> Value {
    let source_type = match row.source_type {
        1 => "wakapi_import",
        2 => "test_entry",
        _ => "direct_entry",
    };
    let mut value = serde_json::to_value(row).expect("heartbeat serializes");
    if let Some(object) = value.as_object_mut() {
        object.insert("source_type".to_owned(), json!(source_type));
        object.remove("version");
        object.remove("ysws_program");
    }
    value
}

fn project_stats_range(query: &ProjectsQuery) -> Result<(f64, f64)> {
    let now = Utc::now().timestamp() as f64;
    project_stats_range_with_defaults(query, now - 365.0 * 86_400.0, now)
}

fn project_stats_range_with_defaults(
    query: &ProjectsQuery,
    default_start: f64,
    default_end: f64,
) -> Result<(f64, f64)> {
    parse_range(
        query.start.as_deref().or(query.start_date.as_deref()),
        query.end.as_deref().or(query.end_date.as_deref()),
        default_start,
        default_end,
    )
}

fn first_time<const N: usize>(values: [Option<&str>; N], default: f64, name: &str) -> Result<f64> {
    values
        .into_iter()
        .flatten()
        .next()
        .map(|value| parse_datetime(value, name))
        .transpose()
        .map(|value| value.unwrap_or(default))
}

fn csv(value: &str) -> Vec<String> {
    value
        .split(',')
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .collect()
}

fn end_of_today() -> f64 {
    let tomorrow = Utc::now().date_naive() + Days::new(1);
    tomorrow
        .and_hms_opt(0, 0, 0)
        .expect("midnight exists")
        .and_utc()
        .timestamp() as f64
        - 0.000_001
}

fn format_timestamp(timestamp: f64, format: &str) -> String {
    chrono::DateTime::<Utc>::from_timestamp_micros((timestamp * 1_000_000.0) as i64)
        .expect("valid timestamp")
        .format(format)
        .to_string()
}

fn format_timestamp_millis(timestamp: f64) -> String {
    chrono::DateTime::<Utc>::from_timestamp_micros((timestamp * 1_000_000.0) as i64)
        .expect("valid timestamp")
        .format("%Y-%m-%dT%H:%M:%S%.3fZ")
        .to_string()
}

fn simple_time(seconds: i64) -> String {
    let hours = seconds / 3600;
    if hours > 1 {
        format!("{hours} hrs")
    } else if hours == 1 {
        "1 hr".to_owned()
    } else {
        format!("{} min", seconds % 3600 / 60)
    }
}

fn parse_date(value: Option<&str>, default: NaiveDate, name: &str) -> Result<NaiveDate> {
    value
        .map(|value| {
            NaiveDate::parse_from_str(value, "%Y-%m-%d")
                .map_err(|_| AppError::Unprocessable(format!("Invalid {name}")))
        })
        .transpose()
        .map(|value| value.unwrap_or(default))
}

fn parse_source_type(value: &str) -> Result<i32> {
    match value {
        "direct_entry" => Ok(0),
        "wakapi_import" => Ok(1),
        "test_entry" => Ok(2),
        _ => Err(AppError::Unprocessable("Invalid source_type".to_owned())),
    }
}

fn user_timezone(user: &crate::models::User) -> Tz {
    user.timezone
        .as_deref()
        .and_then(|timezone| timezone.parse::<Tz>().ok())
        .unwrap_or(chrono_tz::UTC)
}

fn human_time_ago(seconds: f64) -> String {
    let seconds = seconds.max(0.0) as i64;
    let (amount, unit) = if seconds < 60 {
        (seconds, "second")
    } else if seconds < 3600 {
        (seconds / 60, "minute")
    } else if seconds < 86_400 {
        (seconds / 3600, "hour")
    } else if seconds < 2_592_000 {
        (seconds / 86_400, "day")
    } else if seconds < 31_536_000 {
        (seconds / 2_592_000, "month")
    } else {
        (seconds / 31_536_000, "year")
    };
    let suffix = if amount == 1 { "" } else { "s" };
    format!("{amount} {unit}{suffix} ago")
}

fn category_stats(groups: Vec<(String, i64)>) -> Vec<Value> {
    let total = groups.iter().map(|(_, seconds)| seconds).sum();
    groups
        .into_iter()
        .filter(|(_, seconds)| *seconds > 0)
        .map(|(name, seconds)| category_stat(name, seconds, total))
        .collect()
}

fn category_stat(name: String, seconds: i64, total: i64) -> Value {
    let hours = seconds / 3600;
    let minutes = seconds % 3600 / 60;
    let remainder = seconds % 60;
    let percent = if total == 0 {
        0.0
    } else {
        (seconds as f64 / total as f64 * 10_000.0).round() / 100.0
    };
    json!({
        "name": name,
        "total_seconds": seconds,
        "percent": percent,
        "digital": format!("{hours}:{minutes:02}:{remainder:02}"),
        "text": hours_minutes(seconds),
        "hours": hours,
        "minutes": minutes,
        "seconds": remainder
    })
}

fn hours_minutes(seconds: i64) -> String {
    format!("{} hrs {} mins", seconds / 3600, seconds % 3600 / 60)
}

fn ensure_stats_key(state: &AppState, headers: &HeaderMap) -> Result<()> {
    let Some(expected) = state.stats_api_key.as_deref() else {
        return Ok(());
    };
    let supplied = headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "));
    if supplied == Some(expected) {
        Ok(())
    } else {
        Err(AppError::unauthorized())
    }
}

async fn resolve_project(
    state: &AppState,
    user_id: i64,
    project: &str,
    end: f64,
) -> Result<String> {
    if !state
        .heartbeats
        .project_details(user_id, 0.0, end, vec![project.to_owned()])
        .await?
        .is_empty()
    {
        return Ok(project.to_owned());
    }
    if let Some((owner, name)) = project.split_once('/') {
        let mapped = sqlx::query_scalar::<_, String>(
            "SELECT mappings.project_name
             FROM project_repo_mappings mappings
             INNER JOIN repositories ON repositories.id = mappings.repository_id
             WHERE mappings.user_id = $1
               AND repositories.owner = $2
               AND repositories.name = $3
             ORDER BY mappings.id
             LIMIT 1",
        )
        .bind(user_id)
        .bind(owner)
        .bind(name)
        .fetch_optional(&state.postgres)
        .await?;
        if let Some(mapped) = mapped {
            return Ok(mapped);
        }
    }
    Err(AppError::NotFound("Project not found".to_owned()))
}

fn badge_duration(seconds: i64) -> String {
    let hours = seconds / 3600;
    let minutes = seconds % 3600 / 60;
    if hours > 0 {
        format!("{hours}h {minutes}m")
    } else {
        format!("{minutes}m")
    }
}

fn url_component(value: &str) -> String {
    percent_encoding::utf8_percent_encode(value, percent_encoding::NON_ALPHANUMERIC).to_string()
}

async fn leaderboard(state: &AppState, period_type: i32) -> Result<Json<Value>> {
    let today = Utc::now().date_naive();
    let board = sqlx::query_as::<_, Leaderboard>(
        "SELECT id, period_type, start_date, finished_generating_at
         FROM leaderboards
         WHERE period_type = $1
           AND start_date = $2
           AND deleted_at IS NULL
           AND finished_generating_at IS NOT NULL
         ORDER BY id DESC
         LIMIT 1",
    )
    .bind(period_type)
    .bind(today)
    .fetch_optional(&state.postgres)
    .await?
    .ok_or_else(|| AppError::ServiceUnavailable("Leaderboard is being generated".to_owned()))?;
    let entries = sqlx::query_as::<_, LeaderboardEntry>(
        "SELECT
           users.id AS user_id,
           COALESCE(
             users.display_name_override,
             users.slack_username,
             users.github_username,
             users.username
           ) AS display_name,
           COALESCE(users.slack_avatar_url, users.github_avatar_url) AS avatar_url,
           entries.total_seconds
         FROM leaderboard_entries entries
         INNER JOIN users ON users.id = entries.user_id
         WHERE entries.leaderboard_id = $1
           AND users.leaderboard_shadowbanned = FALSE
         ORDER BY entries.total_seconds DESC, entries.id",
    )
    .bind(board.id)
    .fetch_all(&state.postgres)
    .await?
    .into_iter()
    .enumerate()
    .map(|(index, entry)| {
        json!({
            "rank": index + 1,
            "user": {
                "id": entry.user_id,
                "username": entry.display_name,
                "avatar_url": entry.avatar_url
            },
            "total_seconds": entry.total_seconds
        })
    })
    .collect::<Vec<_>>();
    let period = if board.period_type == 0 {
        "daily"
    } else {
        "last_7_days"
    };
    let date_range = if board.period_type == 0 {
        "Last 24 hours".to_owned()
    } else {
        let start = board.start_date - Days::new(6);
        format!(
            "{} - {}",
            start.format("%b %d"),
            board.start_date.format("%b %d, %Y")
        )
    };
    Ok(Json(json!({
        "period": period,
        "start_date": board.start_date,
        "date_range": date_range,
        "generated_at": board.finished_generating_at.map(|time| time.and_utc().to_rfc3339()),
        "entries": entries
    })))
}
