use axum::extract::State;
use axum::Json;
use sqlx::postgres::PgArguments;
use sqlx::{Arguments, PgPool};

use crate::error::AppError;
use crate::models::duration::{DurationRequest, DurationResponse};

pub async fn boundary_aware(
    State(pool): State<PgPool>,
    Json(req): Json<DurationRequest>,
) -> Result<Json<DurationResponse>, AppError> {
    let user_id = req
        .user_id
        .ok_or_else(|| AppError::BadRequest("user_id is required".into()))?;
    let start_time = req
        .start_time
        .ok_or_else(|| AppError::BadRequest("start_time is required".into()))?;
    let end_time = req
        .end_time
        .ok_or_else(|| AppError::BadRequest("end_time is required".into()))?;
    let timeout = req.timeout_seconds.unwrap_or(120.0);

    // Default excluded categories for boundary-aware
    let default_excludes = vec![
        "browsing".to_string(),
        "ai coding".to_string(),
        "meeting".to_string(),
        "communicating".to_string(),
    ];
    let categories_exclude = req.categories_exclude.unwrap_or(default_excludes);

    // Build base filter conditions (without time range)
    // These conditions are reused in both UNION subqueries, but since Postgres
    // $N parameters refer to positional args, the same $N in both subqueries
    // correctly references the same argument.
    let mut base_conditions = vec![
        "deleted_at IS NULL".to_string(),
        "\"time\" IS NOT NULL".to_string(),
        "\"time\" >= 0".to_string(),
        "\"time\" <= 253402300799".to_string(),
    ];

    let mut args = PgArguments::default();
    let mut param_idx = 1usize;

    // user_id filter
    base_conditions.push(format!("user_id = ${}", param_idx));
    let _ = args.add(user_id);
    param_idx += 1;

    // project filter
    if let Some(ref p) = req.project {
        base_conditions.push(format!("project = ${}", param_idx));
        let _ = args.add(p.clone());
        param_idx += 1;
    }
    if let Some(ref ps) = req.projects {
        if !ps.is_empty() {
            let placeholders: Vec<String> = ps
                .iter()
                .enumerate()
                .map(|(i, _)| format!("${}", param_idx + i))
                .collect();
            base_conditions.push(format!("project IN ({})", placeholders.join(", ")));
            for p in ps {
                let _ = args.add(p.clone());
            }
            param_idx += ps.len();
        }
    }

    // coding_only / category / categories
    if req.coding_only == Some(true) {
        base_conditions.push("category = 'coding'".to_string());
    } else if let Some(ref cats) = req.categories {
        if !cats.is_empty() {
            let placeholders: Vec<String> = cats
                .iter()
                .enumerate()
                .map(|(i, _)| format!("${}", param_idx + i))
                .collect();
            base_conditions.push(format!("category IN ({})", placeholders.join(", ")));
            for c in cats {
                let _ = args.add(c.clone());
            }
            param_idx += cats.len();
        }
    } else if let Some(ref cat) = req.category {
        base_conditions.push(format!("category = ${}", param_idx));
        let _ = args.add(cat.clone());
        param_idx += 1;
    }

    // languages filter
    if let Some(ref langs) = req.languages {
        if !langs.is_empty() {
            let placeholders: Vec<String> = langs
                .iter()
                .enumerate()
                .map(|(i, _)| format!("${}", param_idx + i))
                .collect();
            base_conditions.push(format!("language IN ({})", placeholders.join(", ")));
            for l in langs {
                let _ = args.add(l.clone());
            }
            param_idx += langs.len();
        }
    }

    // editors filter
    if let Some(ref eds) = req.editors {
        if !eds.is_empty() {
            let placeholders: Vec<String> = eds
                .iter()
                .enumerate()
                .map(|(i, _)| format!("${}", param_idx + i))
                .collect();
            base_conditions.push(format!("editor IN ({})", placeholders.join(", ")));
            for e in eds {
                let _ = args.add(e.clone());
            }
            param_idx += eds.len();
        }
    }

    // operating_systems filter
    if let Some(ref oses) = req.operating_systems {
        if !oses.is_empty() {
            let placeholders: Vec<String> = oses
                .iter()
                .enumerate()
                .map(|(i, _)| format!("${}", param_idx + i))
                .collect();
            base_conditions.push(format!("operating_system IN ({})", placeholders.join(", ")));
            for o in oses {
                let _ = args.add(o.clone());
            }
            param_idx += oses.len();
        }
    }

    // categories exclude
    if !categories_exclude.is_empty() {
        let placeholders: Vec<String> = categories_exclude
            .iter()
            .enumerate()
            .map(|(i, _)| format!("${}", param_idx + i))
            .collect();
        base_conditions.push(format!(
            "LOWER(category) NOT IN ({})",
            placeholders.join(", ")
        ));
        for c in &categories_exclude {
            let _ = args.add(c.to_lowercase());
        }
        param_idx += categories_exclude.len();
    }

    let base_where = base_conditions.join(" AND ");

    // Time parameters for the boundary query
    let start_param = format!("${}", param_idx);
    let _ = args.add(start_time);
    param_idx += 1;

    let end_param = format!("${}", param_idx);
    let _ = args.add(end_time);
    param_idx += 1;

    // start_time again for the final WHERE clause
    let start_param2 = format!("${}", param_idx);
    let _ = args.add(start_time);

    let sql = format!(
        "SELECT COALESCE(SUM(diff), 0)::bigint as total \
         FROM ( \
           SELECT \"time\", CASE \
             WHEN LAG(\"time\") OVER (ORDER BY \"time\") IS NULL THEN 0 \
             ELSE LEAST(\"time\" - LAG(\"time\") OVER (ORDER BY \"time\"), {timeout}) \
           END as diff \
           FROM ( \
             (SELECT \"time\" FROM heartbeats WHERE {base_where} AND \"time\" < {start_param} ORDER BY \"time\" DESC LIMIT 1) \
             UNION ALL \
             (SELECT \"time\" FROM heartbeats WHERE {base_where} AND \"time\" >= {start_param} AND \"time\" <= {end_param}) \
           ) AS boundary_heartbeats \
         ) AS diffs \
         WHERE \"time\" >= {start_param2}",
        timeout = timeout,
        base_where = base_where,
        start_param = start_param,
        end_param = end_param,
        start_param2 = start_param2
    );

    let row: (i64,) = sqlx::query_as_with(&sql, args).fetch_one(&pool).await?;

    Ok(Json(DurationResponse {
        total_seconds: row.0,
    }))
}
