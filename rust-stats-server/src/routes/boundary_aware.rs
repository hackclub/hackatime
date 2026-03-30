use axum::extract::State;
use axum::Json;
use sqlx::{Arguments, PgPool};

use crate::error::AppError;
use crate::models::duration::{DurationRequest, DurationResponse};
use crate::query::filters::QueryFilterBuilder;
use crate::time::heartbeat_time;

const DEFAULT_EXCLUDED_CATEGORIES: &[&str] = &["browsing", "ai coding", "meeting", "communicating"];

fn build_boundary_filters(
    req: &DurationRequest,
) -> Result<crate::query::filters::QueryFilters, AppError> {
    let user_id = req
        .user_id
        .ok_or_else(|| AppError::BadRequest("user_id is required".into()))?;
    let mut builder = QueryFilterBuilder::new();

    builder.push_user_id(user_id);

    if let Some(project) = req.project.as_deref() {
        builder.push_project(project);
    }

    if let Some(projects) = req.projects.as_deref() {
        builder.push_projects(projects);
    }

    if req.coding_only == Some(true) {
        builder.push_raw("category = 'coding'");
    } else if let Some(categories) = req.categories.as_deref() {
        builder.push_categories(categories);
    } else if let Some(category) = req.category.as_deref() {
        builder.push_category(category);
    }

    if let Some(languages) = req.languages.as_deref() {
        builder.push_languages(languages);
    }

    if let Some(editors) = req.editors.as_deref() {
        builder.push_editors(editors);
    }

    if let Some(operating_systems) = req.operating_systems.as_deref() {
        builder.push_operating_systems(operating_systems);
    }

    let excluded_categories = req.categories_exclude.clone().unwrap_or_else(|| {
        DEFAULT_EXCLUDED_CATEGORIES
            .iter()
            .map(|category| (*category).to_string())
            .collect()
    });
    builder.push_categories_exclude(&excluded_categories);

    Ok(builder.build())
}

pub async fn boundary_aware(
    State(pool): State<PgPool>,
    Json(req): Json<DurationRequest>,
) -> Result<Json<DurationResponse>, AppError> {
    let start_time = req
        .start_time
        .ok_or_else(|| AppError::BadRequest("start_time is required".into()))?;
    let end_time = req
        .end_time
        .ok_or_else(|| AppError::BadRequest("end_time is required".into()))?;
    let timeout = req.timeout_seconds.unwrap_or(120.0);
    let mut filters = build_boundary_filters(&req)?;
    let base_param_count = filters.where_clause.matches('$').count();
    let start_param = format!("${}", base_param_count + 1);
    let _ = filters.args.add(heartbeat_time(start_time));
    let end_param = format!("${}", base_param_count + 2);
    let _ = filters.args.add(heartbeat_time(end_time));
    let final_start_param = format!("${}", base_param_count + 3);
    let _ = filters.args.add(heartbeat_time(start_time));

    let sql = format!(
        "SELECT COALESCE(SUM(diff), 0)::bigint as total \
         FROM ( \
           SELECT \"time\", CASE \
             WHEN LAG(\"time\") OVER (ORDER BY \"time\") IS NULL THEN 0 \
             ELSE LEAST(\"time\" - LAG(\"time\") OVER (ORDER BY \"time\"), {timeout}) \
           END as diff \
           FROM ( \
             (SELECT \"time\" FROM heartbeats WHERE {where_clause} AND \"time\" < {start_param} ORDER BY \"time\" DESC LIMIT 1) \
             UNION ALL \
             (SELECT \"time\" FROM heartbeats WHERE {where_clause} AND \"time\" >= {start_param} AND \"time\" <= {end_param}) \
           ) AS boundary_heartbeats \
         ) AS diffs \
         WHERE \"time\" >= {final_start_param}",
        where_clause = filters.where_clause
    );

    let row: (i64,) = sqlx::query_as_with(&sql, filters.args)
        .fetch_one(&pool)
        .await?;

    Ok(Json(DurationResponse {
        total_seconds: row.0,
    }))
}
