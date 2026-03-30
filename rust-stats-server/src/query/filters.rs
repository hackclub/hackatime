use sqlx::postgres::PgArguments;
use sqlx::Arguments;

use crate::time::heartbeat_time;

const BASE_CONDITIONS: &[&str] = &[
    "deleted_at IS NULL",
    "\"time\" IS NOT NULL",
    "\"time\" >= 0",
    "\"time\" <= 253402300799",
];

pub struct QueryFilters {
    pub where_clause: String,
    pub args: PgArguments,
}

#[derive(Default)]
pub struct QueryFilterParams<'a> {
    pub user_id: Option<i64>,
    pub user_ids: Option<&'a [i64]>,
    pub start_time: Option<f64>,
    pub end_time: Option<f64>,
    pub project: Option<&'a str>,
    pub projects: Option<&'a [String]>,
    pub category: Option<&'a str>,
    pub coding_only: Option<bool>,
    pub categories_exclude: Option<&'a [String]>,
    pub languages: Option<&'a [String]>,
    pub editors: Option<&'a [String]>,
    pub operating_systems: Option<&'a [String]>,
    pub categories: Option<&'a [String]>,
}

#[derive(Default)]
pub struct QueryFilterBuilder {
    conditions: Vec<String>,
    args: PgArguments,
    next_param: usize,
}

impl QueryFilterBuilder {
    pub fn new() -> Self {
        Self {
            conditions: BASE_CONDITIONS
                .iter()
                .map(|condition| (*condition).to_string())
                .collect(),
            args: PgArguments::default(),
            next_param: 1,
        }
    }

    pub fn push_raw(&mut self, condition: impl Into<String>) {
        self.conditions.push(condition.into());
    }

    pub fn push_user_id(&mut self, user_id: i64) {
        self.push_numeric("user_id", user_id);
    }

    pub fn push_user_ids(&mut self, user_ids: &[i64]) {
        self.push_in_clause("user_id", user_ids, |value| *value);
    }

    pub fn push_start_time(&mut self, start_time: f64) {
        self.push_condition_with_value(
            format!("\"time\" >= ${}", self.next_param),
            heartbeat_time(start_time),
        );
    }

    pub fn push_end_time(&mut self, end_time: f64) {
        self.push_condition_with_value(
            format!("\"time\" <= ${}", self.next_param),
            heartbeat_time(end_time),
        );
    }

    pub fn push_project(&mut self, project: &str) {
        self.push_text("project", project);
    }

    pub fn push_projects(&mut self, projects: &[String]) {
        self.push_in_clause("project", projects, Clone::clone);
    }

    pub fn push_category(&mut self, category: &str) {
        self.push_text("category", category);
    }

    pub fn push_categories(&mut self, categories: &[String]) {
        self.push_in_clause("category", categories, Clone::clone);
    }

    pub fn push_languages(&mut self, languages: &[String]) {
        self.push_in_clause("language", languages, Clone::clone);
    }

    pub fn push_editors(&mut self, editors: &[String]) {
        self.push_in_clause("editor", editors, Clone::clone);
    }

    pub fn push_operating_systems(&mut self, operating_systems: &[String]) {
        self.push_in_clause("operating_system", operating_systems, Clone::clone);
    }

    pub fn push_categories_exclude(&mut self, categories: &[String]) {
        if categories.is_empty() {
            return;
        }

        let placeholders = self.placeholders(categories.len());
        self.push_raw(format!(
            "LOWER(category) NOT IN ({})",
            placeholders.join(", ")
        ));

        for category in categories {
            let _ = self.args.add(category.to_lowercase());
        }
    }

    pub fn build(self) -> QueryFilters {
        QueryFilters {
            where_clause: self.conditions.join(" AND "),
            args: self.args,
        }
    }

    fn push_numeric(&mut self, column: &str, value: i64) {
        self.push_condition_with_value(format!("{column} = ${}", self.next_param), value);
    }

    fn push_text(&mut self, column: &str, value: &str) {
        self.push_condition_with_value(
            format!("{column} = ${}", self.next_param),
            value.to_owned(),
        );
    }

    fn push_condition_with_value<T>(&mut self, condition: String, value: T)
    where
        T: Send + 'static,
        PgArguments: Arguments<'static, Database = sqlx::Postgres>,
        T: sqlx::Encode<'static, sqlx::Postgres> + sqlx::Type<sqlx::Postgres>,
    {
        self.push_raw(condition);
        let _ = self.args.add(value);
        self.next_param += 1;
    }

    fn push_in_clause<T, F>(&mut self, column: &str, values: &[T], map_value: F)
    where
        T: Clone,
        F: Fn(&T) -> T,
        PgArguments: Arguments<'static, Database = sqlx::Postgres>,
        T: Send + 'static + sqlx::Encode<'static, sqlx::Postgres> + sqlx::Type<sqlx::Postgres>,
    {
        if values.is_empty() {
            return;
        }

        let placeholders = self.placeholders(values.len());
        self.push_raw(format!("{column} IN ({})", placeholders.join(", ")));

        for value in values {
            let _ = self.args.add(map_value(value));
        }
    }

    fn placeholders(&mut self, count: usize) -> Vec<String> {
        let placeholders = (0..count)
            .map(|offset| format!("${}", self.next_param + offset))
            .collect();
        self.next_param += count;
        placeholders
    }
}

impl QueryFilters {
    pub fn build(params: &QueryFilterParams<'_>) -> Self {
        let mut builder = QueryFilterBuilder::new();

        if let Some(user_id) = params.user_id {
            builder.push_user_id(user_id);
        }

        if let Some(user_ids) = params.user_ids {
            builder.push_user_ids(user_ids);
        }

        if let Some(start_time) = params.start_time {
            builder.push_start_time(start_time);
        }

        if let Some(end_time) = params.end_time {
            builder.push_end_time(end_time);
        }

        if let Some(project) = params.project {
            builder.push_project(project);
        }

        if let Some(projects) = params.projects {
            builder.push_projects(projects);
        }

        if params.coding_only == Some(true) {
            builder.push_raw("category = 'coding'");
        } else if let Some(category) = params.category {
            builder.push_category(category);
        }

        if let Some(categories_exclude) = params.categories_exclude {
            builder.push_categories_exclude(categories_exclude);
        }

        if let Some(categories) = params.categories {
            builder.push_categories(categories);
        }

        if let Some(languages) = params.languages {
            builder.push_languages(languages);
        }

        if let Some(editors) = params.editors {
            builder.push_editors(editors);
        }

        if let Some(operating_systems) = params.operating_systems {
            builder.push_operating_systems(operating_systems);
        }

        builder.build()
    }
}

#[cfg(test)]
mod tests {
    use super::{QueryFilterParams, QueryFilters};

    #[test]
    fn preserves_parameter_order_across_scalar_and_list_filters() {
        let filters = QueryFilters::build(&QueryFilterParams {
            user_id: Some(42),
            start_time: Some(100.0),
            end_time: Some(200.0),
            projects: Some(&["hackatime".to_string(), "waka".to_string()]),
            languages: Some(&["Rust".to_string(), "Ruby".to_string()]),
            ..Default::default()
        });

        assert_eq!(
            filters.where_clause,
            "deleted_at IS NULL AND \"time\" IS NOT NULL AND \"time\" >= 0 AND \"time\" <= 253402300799 \
AND user_id = $1 AND \"time\" >= $2 AND \"time\" <= $3 AND project IN ($4, $5) AND language IN ($6, $7)"
        );
    }
}
