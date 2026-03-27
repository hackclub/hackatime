use sqlx::PgPool;

use crate::error::AppError;
use crate::models::spans::Span;

use super::filters::QueryFilters;

pub struct HeartbeatRow {
    pub time: f64,
    pub next_time: Option<f64>,
    pub entity: Option<String>,
    pub project: Option<String>,
    pub editor: Option<String>,
    pub language: Option<String>,
}

pub async fn query_spans(
    pool: &PgPool,
    filters: QueryFilters,
    timeout: f64,
    include_metadata: bool,
) -> Result<Vec<Span>, AppError> {
    let extra_cols = if include_metadata {
        ", entity, project, editor, language"
    } else {
        ""
    };

    let sql = format!(
        "SELECT time, LEAD(time) OVER (ORDER BY time) as next_time{extra_cols} \
         FROM heartbeats WHERE {where_clause} ORDER BY time",
        extra_cols = extra_cols,
        where_clause = filters.where_clause
    );

    let rows: Vec<HeartbeatRow> = if include_metadata {
        let result: Vec<(f64, Option<f64>, Option<String>, Option<String>, Option<String>, Option<String>)> =
            sqlx::query_as_with(&sql, filters.args)
                .fetch_all(pool)
                .await?;
        result
            .into_iter()
            .map(|(time, next_time, entity, project, editor, language)| HeartbeatRow {
                time,
                next_time,
                entity,
                project,
                editor,
                language,
            })
            .collect()
    } else {
        let result: Vec<(f64, Option<f64>)> =
            sqlx::query_as_with(&sql, filters.args)
                .fetch_all(pool)
                .await?;
        result
            .into_iter()
            .map(|(time, next_time)| HeartbeatRow {
                time,
                next_time,
                entity: None,
                project: None,
                editor: None,
                language: None,
            })
            .collect()
    };

    if rows.is_empty() {
        return Ok(vec![]);
    }

    let mut spans = Vec::new();
    let mut span_start = rows[0].time;
    let mut _span_end = rows[0].time;
    let mut files: Vec<String> = Vec::new();
    let mut projects: Vec<String> = Vec::new();
    let mut editors: Vec<String> = Vec::new();
    let mut languages: Vec<String> = Vec::new();

    for row in &rows {
        if include_metadata {
            if let Some(ref e) = row.entity {
                if !files.contains(e) {
                    files.push(e.clone());
                }
            }
            if let Some(ref p) = row.project {
                if !projects.contains(p) {
                    projects.push(p.clone());
                }
            }
            if let Some(ref ed) = row.editor {
                if !editors.contains(ed) {
                    editors.push(ed.clone());
                }
            }
            if let Some(ref l) = row.language {
                if !languages.contains(l) {
                    languages.push(l.clone());
                }
            }
        }

        match row.next_time {
            Some(next) => {
                let gap = next - row.time;
                if gap > timeout {
                    // Close current span - add min(gap, timeout) to get end time
                    let span_end = row.time + timeout.min(gap);
                    let duration = span_end - span_start;
                    if duration > 0.0 {
                        let mut span = Span {
                            start_time: span_start,
                            end_time: span_end,
                            duration,
                            files_edited: None,
                            projects: None,
                            editors: None,
                            languages: None,
                        };
                        if include_metadata {
                            span.files_edited = Some(files.clone());
                            span.projects = Some(projects.clone());
                            span.editors = Some(editors.clone());
                            span.languages = Some(languages.clone());
                            files.clear();
                            projects.clear();
                            editors.clear();
                            languages.clear();
                        }
                        spans.push(span);
                    }
                    span_start = next;
                    _span_end = next;
                } else {
                    _span_end = next;
                }
            }
            None => {
                // Last heartbeat - close span
                let duration = row.time - span_start;
                if duration > 0.0 {
                    let mut span = Span {
                        start_time: span_start,
                        end_time: row.time,
                        duration,
                        files_edited: None,
                        projects: None,
                        editors: None,
                        languages: None,
                    };
                    if include_metadata {
                        span.files_edited = Some(files.clone());
                        span.projects = Some(projects.clone());
                        span.editors = Some(editors.clone());
                        span.languages = Some(languages.clone());
                    }
                    spans.push(span);
                }
            }
        }
    }

    Ok(spans)
}
