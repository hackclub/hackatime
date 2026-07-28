use std::time::{SystemTime, UNIX_EPOCH};

use chrono::DateTime;
use clickhouse::{Client, Row};
use regex::Regex;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{
    error::{AppError, Result},
    models::{HeartbeatInput, ProjectDetails, Span, format_epoch},
};

const EPOCH_SANE_MIN: f64 = 1_000_000_000.0;
const EPOCH_SANE_MAX: f64 = 2_000_000_000.0;
const HEARTBEAT_TIMEOUT: f64 = 120.0;

#[derive(Clone)]
pub struct HeartbeatStore {
    client: Client,
}

#[derive(Clone, Debug, Row, Serialize, Deserialize, ToSchema)]
pub struct HeartbeatRow {
    pub id: u64,
    pub ai_input_tokens: Option<i64>,
    pub ai_line_changes: Option<i32>,
    pub ai_model: Option<String>,
    pub ai_output_tokens: Option<i64>,
    pub ai_prompt_length: Option<i32>,
    pub ai_session: Option<String>,
    pub ai_subscription_plan: Option<String>,
    pub branch: Option<String>,
    pub category: Option<String>,
    pub created_at: f64,
    pub cursorpos: Option<i32>,
    pub deleted_at: Option<f64>,
    pub dependencies: Vec<String>,
    pub editor: Option<String>,
    pub entity: Option<String>,
    pub human_line_changes: Option<i32>,
    pub ip_address: Option<String>,
    pub is_write: Option<bool>,
    pub ja4_id: Option<i32>,
    pub language: Option<String>,
    pub line_additions: Option<i32>,
    pub line_deletions: Option<i32>,
    pub lineno: Option<i32>,
    pub lines: Option<i32>,
    pub machine: Option<String>,
    pub operating_system: Option<String>,
    pub project: Option<String>,
    pub project_root_count: Option<i32>,
    pub source_type: i32,
    pub time: f64,
    #[serde(rename = "type")]
    pub kind: Option<String>,
    pub updated_at: f64,
    pub user_agent: Option<String>,
    pub user_id: i64,
    pub ysws_program: i32,
    pub version: u64,
}

#[derive(Clone, Debug, Row, Deserialize)]
struct IdAndTime {
    #[serde(rename = "id")]
    _id: u64,
    time: f64,
}

#[derive(Clone, Debug, Row, Deserialize)]
struct LatestRow {
    id: u64,
    category: Option<String>,
    editor: Option<String>,
    entity: Option<String>,
    language: Option<String>,
    machine: Option<String>,
    operating_system: Option<String>,
    project: Option<String>,
    time: f64,
}

#[derive(Clone, Debug, Row, Deserialize)]
struct ProjectAggregate {
    project: String,
    total_seconds: f64,
    total_heartbeats: u64,
    languages: Vec<String>,
    first_heartbeat: f64,
    last_heartbeat: f64,
}

#[derive(Clone, Debug, Row, Deserialize)]
struct GroupDuration {
    name: String,
    total_seconds: f64,
}

#[derive(Clone, Debug, Row, Deserialize)]
pub struct DailyDuration {
    pub day: String,
    pub total_seconds: f64,
}

#[derive(Clone, Debug, Row, Deserialize)]
pub struct ActiveUser {
    pub user_id: i64,
    pub project: Option<String>,
}

#[derive(Clone, Debug, Serialize, ToSchema)]
pub struct LatestHeartbeat {
    pub id: u64,
    pub category: Option<String>,
    pub editor: Option<String>,
    pub entity: Option<String>,
    pub language: Option<String>,
    pub machine: Option<String>,
    pub operating_system: Option<String>,
    pub project: Option<String>,
    pub time: f64,
}

#[derive(Clone, Debug, Default)]
pub struct HeartbeatFilter {
    pub projects: Vec<String>,
    pub categories: Vec<String>,
    pub no_ai_coding: bool,
}

impl HeartbeatStore {
    pub fn new(client: Client) -> Self {
        Self { client }
    }

    pub async fn ping(&self) -> Result<()> {
        self.client.query("SELECT 1").execute().await?;
        Ok(())
    }

    pub async fn insert(
        &self,
        user_id: i64,
        input: HeartbeatInput,
        ip_address: Option<String>,
        request_user_agent: Option<String>,
    ) -> Result<HeartbeatRow> {
        let row = normalize(user_id, input, ip_address, request_user_agent)?;
        let mut insert = self.client.insert::<HeartbeatRow>("heartbeats").await?;
        insert.write(&row).await?;
        insert.end().await?;
        Ok(row)
    }

    pub async fn latest(&self, user_id: i64) -> Result<Option<LatestHeartbeat>> {
        let row = self
            .client
            .query(
                "SELECT id, category, editor, entity, language, machine, operating_system, project, time
                 FROM heartbeats FINAL
                 WHERE user_id = ? AND deleted_at IS NULL AND source_type != 2
                 ORDER BY time DESC, id DESC
                 LIMIT 1",
            )
            .bind(user_id)
            .fetch_optional::<LatestRow>()
            .await?;

        Ok(row.map(|row| LatestHeartbeat {
            id: row.id,
            category: row.category,
            editor: row.editor,
            entity: row.entity,
            language: row.language,
            machine: row.machine,
            operating_system: row.operating_system,
            project: row.project,
            time: row.time,
        }))
    }

    pub async fn most_recent(
        &self,
        user_id: i64,
        source_type: Option<i32>,
        editor: Option<&str>,
    ) -> Result<Option<HeartbeatRow>> {
        Ok(self
            .client
            .query(
                "SELECT *
                 FROM heartbeats FINAL
                 WHERE user_id = ?
                   AND deleted_at IS NULL
                   AND (? IS NULL OR source_type = ?)
                   AND (? IS NOT NULL OR source_type != 2)
                   AND (? IS NULL OR lower(assumeNotNull(editor)) = lower(?))
                 ORDER BY time DESC, id DESC
                 LIMIT 1",
            )
            .bind(user_id)
            .bind(source_type)
            .bind(source_type)
            .bind(source_type)
            .bind(editor)
            .bind(editor)
            .fetch_optional::<HeartbeatRow>()
            .await?)
    }

    pub async fn list(&self, user_id: i64, start: f64, end: f64) -> Result<Vec<HeartbeatRow>> {
        Ok(self
            .client
            .query(
                "SELECT *
                 FROM heartbeats FINAL
                 WHERE user_id = ?
                   AND deleted_at IS NULL
                   AND time >= ?
                   AND time <= ?
                 ORDER BY time, id",
            )
            .bind(user_id)
            .bind(start)
            .bind(end)
            .fetch_all::<HeartbeatRow>()
            .await?)
    }

    pub async fn duration(
        &self,
        user_id: i64,
        start: f64,
        end: f64,
        filter: &HeartbeatFilter,
    ) -> Result<i64> {
        let duration = self
            .client
            .query(
                "SELECT toInt64(coalesce(sum(diff), 0))
                 FROM
                 (
                   SELECT least(
                     time - lagInFrame(time, 1, time) OVER (
                       ORDER BY time, id
                       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                     ),
                     120
                   ) AS diff
                   FROM heartbeats FINAL
                   WHERE user_id = ?
                     AND deleted_at IS NULL
                     AND time >= ?
                     AND time < ?
                     AND (empty(?) OR project IN ?)
                     AND (empty(?) OR category IN ?)
                     AND (? = 0 OR category != 'ai coding')
                 )",
            )
            .bind(user_id)
            .bind(start)
            .bind(end)
            .bind(filter.projects.clone())
            .bind(filter.projects.clone())
            .bind(filter.categories.clone())
            .bind(filter.categories.clone())
            .bind(u8::from(filter.no_ai_coding))
            .fetch_one::<i64>()
            .await?;
        Ok(duration)
    }

    pub async fn spans(
        &self,
        user_id: i64,
        start: f64,
        end: f64,
        projects: Vec<String>,
    ) -> Result<Vec<Span>> {
        let rows = self
            .client
            .query(
                "SELECT id, time
                 FROM heartbeats FINAL
                 WHERE user_id = ?
                   AND deleted_at IS NULL
                   AND time >= ?
                   AND time <= ?
                   AND (empty(?) OR project IN ?)
                 ORDER BY time, id",
            )
            .bind(user_id)
            .bind(start)
            .bind(end)
            .bind(projects.clone())
            .bind(projects)
            .fetch_all::<IdAndTime>()
            .await?;
        Ok(to_spans(&rows))
    }

    pub async fn project_names(&self, user_id: i64, start: f64, end: f64) -> Result<Vec<String>> {
        Ok(self
            .client
            .query(
                "SELECT DISTINCT assumeNotNull(project) AS project
                 FROM heartbeats FINAL
                 WHERE user_id = ?
                   AND deleted_at IS NULL
                   AND time >= ?
                   AND time <= ?
                   AND project IS NOT NULL
                   AND project != ''
                 ORDER BY project",
            )
            .bind(user_id)
            .bind(start)
            .bind(end)
            .fetch_all::<String>()
            .await?)
    }

    pub async fn project_details(
        &self,
        user_id: i64,
        start: f64,
        end: f64,
        projects: Vec<String>,
    ) -> Result<Vec<ProjectDetails>> {
        let rows = self
            .client
            .query(
                "SELECT
                   project,
                   sum(diff) AS total_seconds,
                   count() AS total_heartbeats,
                   arraySort(groupUniqArrayIf(assumeNotNull(language), language IS NOT NULL AND language != '')) AS languages,
                   min(time) AS first_heartbeat,
                   max(time) AS last_heartbeat
                 FROM
                 (
                   SELECT
                     assumeNotNull(project) AS project,
                     language,
                     time,
                     least(
                       time - lagInFrame(time, 1, time) OVER (
                         PARTITION BY project
                         ORDER BY time, id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                       ),
                       120
                     ) AS diff
                   FROM heartbeats FINAL
                   WHERE user_id = ?
                     AND deleted_at IS NULL
                     AND time >= ?
                     AND time <= ?
                     AND project IS NOT NULL
                     AND project != ''
                     AND (empty(?) OR project IN ?)
                 )
                 GROUP BY project
                 ORDER BY total_seconds DESC, project",
            )
            .bind(user_id)
            .bind(start)
            .bind(end)
            .bind(projects.clone())
            .bind(projects)
            .fetch_all::<ProjectAggregate>()
            .await?;

        Ok(rows
            .into_iter()
            .map(|row| {
                let first = format_epoch(row.first_heartbeat);
                let last = format_epoch(row.last_heartbeat);
                ProjectDetails {
                    name: row.project,
                    total_seconds: row.total_seconds.round() as i64,
                    languages: row.languages,
                    repo_url: None,
                    total_heartbeats: row.total_heartbeats,
                    first_heartbeat: first,
                    last_heartbeat: last.clone(),
                    most_recent_heartbeat: last,
                    archived: false,
                }
            })
            .collect())
    }

    pub async fn grouped_durations(
        &self,
        user_id: i64,
        start: f64,
        end: f64,
        field: &str,
    ) -> Result<Vec<(String, i64)>> {
        let field = match field {
            "language" => "language",
            "project" => "project",
            "editor" => "editor",
            "machine" => "machine",
            "operating_system" => "operating_system",
            "category" => "category",
            _ => return Err(AppError::BadRequest("invalid group field".to_owned())),
        };
        let sql = format!(
            "SELECT name, sum(diff) AS total_seconds
             FROM
             (
               SELECT
                 assumeNotNull({field}) AS name,
                 least(
                   time - lagInFrame(time, 1, time) OVER (
                     PARTITION BY {field}
                     ORDER BY time, id
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                   ),
                   120
                 ) AS diff
               FROM heartbeats FINAL
               WHERE user_id = ?
                 AND deleted_at IS NULL
                 AND time >= ?
                 AND time < ?
                 AND {field} IS NOT NULL
                 AND {field} != ''
             )
             GROUP BY name
             ORDER BY total_seconds DESC, name"
        );
        Ok(self
            .client
            .query(&sql)
            .bind(user_id)
            .bind(start)
            .bind(end)
            .fetch_all::<GroupDuration>()
            .await?
            .into_iter()
            .map(|row| (row.name, row.total_seconds.round() as i64))
            .collect())
    }

    pub async fn global_duration(&self, user_id: Option<i64>, start: f64, end: f64) -> Result<i64> {
        Ok(self
            .client
            .query(
                "SELECT toInt64(coalesce(sum(diff), 0))
                 FROM
                 (
                   SELECT least(
                     time - lagInFrame(time, 1, time) OVER (
                       PARTITION BY user_id
                       ORDER BY time, id
                       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                     ),
                     120
                   ) AS diff
                   FROM heartbeats FINAL
                   WHERE deleted_at IS NULL
                     AND time >= ?
                     AND time < ?
                     AND (? IS NULL OR user_id = ?)
                 )",
            )
            .bind(start)
            .bind(end)
            .bind(user_id)
            .bind(user_id)
            .fetch_one::<i64>()
            .await?)
    }

    pub async fn daily_durations(
        &self,
        user_id: i64,
        start: f64,
        end: f64,
        timezone: &str,
    ) -> Result<Vec<DailyDuration>> {
        Ok(self
            .client
            .query(
                "SELECT day, sum(diff) AS total_seconds
                 FROM
                 (
                   SELECT
                     toString(toDate(toTimeZone(toDateTime(time), ?))) AS day,
                     least(
                       time - lagInFrame(time, 1, time) OVER (
                         PARTITION BY day
                         ORDER BY time, id
                         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                       ),
                       120
                     ) AS diff
                   FROM heartbeats FINAL
                   WHERE user_id = ?
                     AND deleted_at IS NULL
                     AND category != 'browsing'
                     AND time >= ?
                     AND time < ?
                 )
                 GROUP BY day
                 ORDER BY day",
            )
            .bind(timezone)
            .bind(user_id)
            .bind(start)
            .bind(end)
            .fetch_all::<DailyDuration>()
            .await?)
    }

    pub async fn active_users(&self, since: f64) -> Result<Vec<ActiveUser>> {
        Ok(self
            .client
            .query(
                "SELECT
                   user_id,
                   argMax(project, tuple(time, id)) AS project
                 FROM heartbeats FINAL
                 WHERE deleted_at IS NULL
                   AND source_type = 0
                   AND category = 'coding'
                   AND time >= ?
                 GROUP BY user_id
                 ORDER BY user_id",
            )
            .bind(since)
            .fetch_all::<ActiveUser>()
            .await?)
    }
}

fn normalize(
    user_id: i64,
    input: HeartbeatInput,
    ip_address: Option<String>,
    request_user_agent: Option<String>,
) -> Result<HeartbeatRow> {
    let time = normalize_time(&input.time)?;
    let now = now();
    if time > now + 3600.0 {
        return Err(AppError::Unprocessable(
            "time must not be more than 1 hour in the future".to_owned(),
        ));
    }

    let user_agent = clean(input.user_agent.or(input.plugin).or(request_user_agent));
    let (parsed_editor, parsed_os) = parse_user_agent(user_agent.as_deref());
    let kind = clean(input.kind);
    let category = clean(input.category).or_else(|| {
        if matches!(kind.as_deref(), Some("domain" | "url")) {
            Some("browsing".to_owned())
        } else {
            Some("coding".to_owned())
        }
    });
    let project = clean(input.project).map(|value| {
        value
            .chars()
            .filter(|character| !character.is_control())
            .collect::<String>()
            .trim()
            .to_owned()
    });
    let language = clean(input.language).or_else(|| infer_language(input.entity.as_deref()));
    let is_test_entry = input.entity.as_deref() == Some("test.txt");

    let identity = serde_json::json!({
        "ai_input_tokens": input.ai_input_tokens,
        "ai_line_changes": input.ai_line_changes,
        "ai_model": input.ai_model,
        "ai_output_tokens": input.ai_output_tokens,
        "ai_prompt_length": input.ai_prompt_length,
        "ai_session": input.ai_session,
        "ai_subscription_plan": input.ai_subscription_plan,
        "branch": input.branch,
        "category": category,
        "cursorpos": input.cursorpos,
        "dependencies": input.dependencies,
        "editor": parsed_editor.as_ref().or(input.editor.as_ref()),
        "entity": input.entity,
        "human_line_changes": input.human_line_changes,
        "is_write": input.is_write,
        "language": language,
        "line_additions": input.line_additions,
        "line_deletions": input.line_deletions,
        "lineno": input.lineno,
        "lines": input.lines,
        "machine": input.machine,
        "operating_system": parsed_os.as_ref().or(input.operating_system.as_ref()),
        "project": project,
        "project_root_count": input.project_root_count,
        "time": time,
        "type": kind,
        "user_agent": user_agent,
        "user_id": user_id
    });
    let hash = blake3::hash(&serde_json::to_vec(&identity)?);
    let hash_bytes = hash.as_bytes();
    let id =
        u64::from_le_bytes(hash_bytes[..8].try_into().expect("eight hash bytes")) & i64::MAX as u64;

    Ok(HeartbeatRow {
        id,
        ai_input_tokens: input.ai_input_tokens,
        ai_line_changes: input.ai_line_changes,
        ai_model: clean(input.ai_model),
        ai_output_tokens: input.ai_output_tokens,
        ai_prompt_length: input.ai_prompt_length,
        ai_session: clean(input.ai_session),
        ai_subscription_plan: clean(input.ai_subscription_plan),
        branch: clean(input.branch),
        category,
        created_at: now,
        cursorpos: input.cursorpos,
        deleted_at: None,
        dependencies: input
            .dependencies
            .into_iter()
            .filter_map(|value| clean(Some(value)))
            .collect(),
        editor: parsed_editor.or_else(|| clean(input.editor)),
        entity: clean(input.entity),
        human_line_changes: input.human_line_changes,
        ip_address,
        is_write: input.is_write,
        ja4_id: None,
        language,
        line_additions: input.line_additions,
        line_deletions: input.line_deletions,
        lineno: input.lineno,
        lines: input.lines,
        machine: clean(input.machine),
        operating_system: parsed_os.or_else(|| clean(input.operating_system)),
        project,
        project_root_count: input.project_root_count,
        source_type: if is_test_entry { 2 } else { 0 },
        time,
        kind,
        updated_at: now,
        user_agent,
        user_id,
        ysws_program: 0,
        version: (now * 1_000_000.0) as u64,
    })
}

fn clean(value: Option<String>) -> Option<String> {
    value.and_then(|value| {
        let value = value.replace('\0', "");
        if value.trim().is_empty() {
            None
        } else {
            Some(value)
        }
    })
}

fn normalize_time(value: &serde_json::Value) -> Result<f64> {
    let raw = match value {
        serde_json::Value::Number(value) => value.as_f64(),
        serde_json::Value::String(value) => value.parse::<f64>().ok().or_else(|| {
            DateTime::parse_from_rfc3339(value)
                .ok()
                .map(|time| time.timestamp_micros() as f64 / 1_000_000.0)
        }),
        _ => None,
    }
    .filter(|value| value.is_finite())
    .ok_or_else(|| {
        AppError::Unprocessable("time must be a Unix epoch timestamp or parseable date".to_owned())
    })?;

    for scale in [1.0, 1e3, 1e6, 1e9] {
        let scaled = raw / scale;
        if (EPOCH_SANE_MIN..EPOCH_SANE_MAX).contains(&scaled) {
            return Ok(scaled);
        }
    }

    Err(AppError::Unprocessable(format!(
        "time must be Unix epoch seconds between {} and {}",
        EPOCH_SANE_MIN as i64,
        EPOCH_SANE_MAX as i64 - 1
    )))
}

fn parse_user_agent(user_agent: Option<&str>) -> (Option<String>, Option<String>) {
    let Some(user_agent) = user_agent else {
        return (None, None);
    };
    let Ok(pattern) = Regex::new(r"(?i)^wakatime/\S+\s+\(([^)]+)\)(?:\s+\S+)?(?:\s+([^/\s]+))?")
    else {
        return (None, None);
    };
    let Some(captures) = pattern.captures(user_agent) else {
        return (None, None);
    };
    let operating_system = captures
        .get(1)
        .and_then(|value| value.as_str().split(['-', '_']).next())
        .map(normalize_os);
    let editor = captures.get(2).map(|value| value.as_str().to_owned());
    (editor, operating_system)
}

fn normalize_os(value: &str) -> String {
    match value.to_ascii_lowercase().as_str() {
        "darwin" | "mac" | "macos" => "mac".to_owned(),
        "win" | "windows" => "windows".to_owned(),
        "linux" => "linux".to_owned(),
        _ => value.to_owned(),
    }
}

fn infer_language(entity: Option<&str>) -> Option<String> {
    let extension = entity?.rsplit_once('.')?.1.to_ascii_lowercase();
    let language = match extension.as_str() {
        "c" | "h" => "C",
        "cpp" | "cc" | "cxx" | "hpp" => "C++",
        "css" => "CSS",
        "go" => "Go",
        "html" | "htm" => "HTML",
        "js" | "jsx" => "JavaScript",
        "json" => "JSON",
        "md" => "Markdown",
        "py" => "Python",
        "rb" => "Ruby",
        "rs" => "Rust",
        "svelte" => "Svelte",
        "ts" | "tsx" => "TypeScript",
        _ => return None,
    };
    Some(language.to_owned())
}

fn now() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system clock is after unix epoch")
        .as_secs_f64()
}

fn to_spans(rows: &[IdAndTime]) -> Vec<Span> {
    let mut spans = Vec::new();
    let Some(first) = rows.first() else {
        return spans;
    };
    let mut start = first.time;

    for (index, current) in rows.iter().enumerate() {
        let next = rows.get(index + 1).map(|row| row.time);
        if next.is_none_or(|next| next - current.time > HEARTBEAT_TIMEOUT) {
            let base = (current.time - start).round();
            let extension = next
                .map(|next| (next - current.time).min(HEARTBEAT_TIMEOUT))
                .unwrap_or(0.0);
            let duration = base + extension;
            if duration > 0.0 {
                spans.push(Span {
                    start_time: start,
                    end_time: current.time + extension,
                    duration,
                });
            }
            if let Some(next) = next {
                start = next;
            }
        }
    }

    spans
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{IdAndTime, normalize_time, to_spans};

    #[test]
    fn repairs_millisecond_timestamps() {
        assert_eq!(
            normalize_time(&json!(1_768_003_200_000_i64)).unwrap(),
            1_768_003_200.0
        );
    }

    #[test]
    fn spans_split_after_timeout_and_extend_to_next_start() {
        let rows = [0.0, 60.0, 300.0, 360.0]
            .into_iter()
            .enumerate()
            .map(|(id, time)| IdAndTime {
                _id: id as u64,
                time,
            })
            .collect::<Vec<_>>();
        let spans = to_spans(&rows);
        assert_eq!(spans.len(), 2);
        assert_eq!(spans[0].duration, 180.0);
        assert_eq!(spans[1].duration, 60.0);
    }
}
