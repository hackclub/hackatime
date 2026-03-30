use std::collections::HashSet;

use sqlx::PgPool;

use crate::error::AppError;
use crate::models::spans::Span;

use super::filters::QueryFilters;

type MetadataHeartbeatRow = (
    f64,
    Option<f64>,
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
);

pub struct HeartbeatRow {
    pub time: f64,
    pub next_time: Option<f64>,
    pub entity: Option<String>,
    pub project: Option<String>,
    pub editor: Option<String>,
    pub language: Option<String>,
}

#[derive(Default)]
struct MetadataAccumulator {
    files: Vec<String>,
    file_set: HashSet<String>,
    projects: Vec<String>,
    project_set: HashSet<String>,
    editors: Vec<String>,
    editor_set: HashSet<String>,
    languages: Vec<String>,
    language_set: HashSet<String>,
}

impl MetadataAccumulator {
    fn record(&mut self, row: &HeartbeatRow) {
        Self::push_unique(&row.entity, &mut self.files, &mut self.file_set);
        Self::push_unique(&row.project, &mut self.projects, &mut self.project_set);
        Self::push_unique(&row.editor, &mut self.editors, &mut self.editor_set);
        Self::push_unique(&row.language, &mut self.languages, &mut self.language_set);
    }

    fn apply_to(&self, span: &mut Span) {
        span.files_edited = Some(self.files.clone());
        span.projects = Some(self.projects.clone());
        span.editors = Some(self.editors.clone());
        span.languages = Some(self.languages.clone());
    }

    fn clear(&mut self) {
        self.files.clear();
        self.file_set.clear();
        self.projects.clear();
        self.project_set.clear();
        self.editors.clear();
        self.editor_set.clear();
        self.languages.clear();
        self.language_set.clear();
    }

    fn push_unique(value: &Option<String>, values: &mut Vec<String>, seen: &mut HashSet<String>) {
        if let Some(value) = value {
            if seen.insert(value.clone()) {
                values.push(value.clone());
            }
        }
    }
}

struct SpanAccumulator {
    span_start: f64,
    metadata: MetadataAccumulator,
}

impl SpanAccumulator {
    fn new(first_heartbeat_time: f64) -> Self {
        Self {
            span_start: first_heartbeat_time,
            metadata: MetadataAccumulator::default(),
        }
    }

    fn record_metadata(&mut self, row: &HeartbeatRow, include_metadata: bool) {
        if include_metadata {
            self.metadata.record(row);
        }
    }

    fn close_span(&mut self, end_time: f64, include_metadata: bool, spans: &mut Vec<Span>) {
        let duration = (end_time - self.span_start).max(0.0);
        if duration <= 0.0 {
            return;
        }

        let mut span = Span {
            start_time: self.span_start,
            end_time,
            duration,
            files_edited: None,
            projects: None,
            editors: None,
            languages: None,
        };

        if include_metadata {
            self.metadata.apply_to(&mut span);
        }

        spans.push(span);
    }

    fn start_next_span(&mut self, start_time: f64) {
        self.span_start = start_time;
        self.metadata.clear();
    }
}

fn build_spans(rows: &[HeartbeatRow], timeout: f64, include_metadata: bool) -> Vec<Span> {
    if rows.is_empty() {
        return Vec::new();
    }

    let mut spans = Vec::new();
    let mut accumulator = SpanAccumulator::new(rows[0].time);

    for row in rows {
        accumulator.record_metadata(row, include_metadata);

        if let Some(next_time) = row.next_time {
            let gap = next_time - row.time;
            if gap > timeout {
                accumulator.close_span(row.time + timeout, include_metadata, &mut spans);
                accumulator.start_next_span(next_time);
            }
        } else {
            accumulator.close_span(row.time, include_metadata, &mut spans);
        }
    }

    spans
}

pub async fn query_spans(
    pool: &PgPool,
    filters: QueryFilters,
    timeout: f64,
    include_metadata: bool,
) -> Result<Vec<Span>, AppError> {
    let extra_columns = if include_metadata {
        ", entity, project, editor, language"
    } else {
        ""
    };

    let sql = format!(
        "SELECT \"time\", LEAD(\"time\") OVER (ORDER BY \"time\") as next_time{extra_columns} \
         FROM heartbeats WHERE {where_clause} ORDER BY \"time\"",
        where_clause = filters.where_clause
    );

    let rows: Vec<HeartbeatRow> = if include_metadata {
        sqlx::query_as_with::<_, MetadataHeartbeatRow, _>(&sql, filters.args)
            .fetch_all(pool)
            .await?
            .into_iter()
            .map(
                |(time, next_time, entity, project, editor, language)| HeartbeatRow {
                    time,
                    next_time,
                    entity,
                    project,
                    editor,
                    language,
                },
            )
            .collect::<Vec<_>>()
    } else {
        sqlx::query_as_with::<_, (f64, Option<f64>), _>(&sql, filters.args)
            .fetch_all(pool)
            .await?
            .into_iter()
            .map(|(time, next_time)| HeartbeatRow {
                time,
                next_time,
                entity: None,
                project: None,
                editor: None,
                language: None,
            })
            .collect::<Vec<_>>()
    };

    Ok(build_spans(&rows, timeout, include_metadata))
}

#[cfg(test)]
mod tests {
    use super::{build_spans, HeartbeatRow};

    #[test]
    fn extends_span_to_timeout_boundary_before_large_gap() {
        let rows = vec![
            HeartbeatRow {
                time: 10.0,
                next_time: Some(70.0),
                entity: None,
                project: None,
                editor: None,
                language: None,
            },
            HeartbeatRow {
                time: 70.0,
                next_time: Some(700.0),
                entity: None,
                project: None,
                editor: None,
                language: None,
            },
            HeartbeatRow {
                time: 700.0,
                next_time: None,
                entity: None,
                project: None,
                editor: None,
                language: None,
            },
        ];

        let spans = build_spans(&rows, 120.0, false);

        assert_eq!(spans.len(), 1);
        assert_eq!(spans[0].start_time, 10.0);
        assert_eq!(spans[0].end_time, 190.0);
        assert_eq!(spans[0].duration, 180.0);
    }

    #[test]
    fn preserves_insertion_order_while_deduplicating_metadata() {
        let rows = vec![
            HeartbeatRow {
                time: 10.0,
                next_time: Some(20.0),
                entity: Some("src/main.rs".to_string()),
                project: Some("hackatime".to_string()),
                editor: Some("zed".to_string()),
                language: Some("Rust".to_string()),
            },
            HeartbeatRow {
                time: 20.0,
                next_time: None,
                entity: Some("src/main.rs".to_string()),
                project: Some("hackatime".to_string()),
                editor: Some("zed".to_string()),
                language: Some("Rust".to_string()),
            },
        ];

        let spans = build_spans(&rows, 120.0, true);

        assert_eq!(
            spans[0].files_edited.as_ref().unwrap(),
            &vec!["src/main.rs".to_string()]
        );
        assert_eq!(
            spans[0].projects.as_ref().unwrap(),
            &vec!["hackatime".to_string()]
        );
    }
}
