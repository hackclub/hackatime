use sqlx::postgres::PgArguments;
use sqlx::Arguments;

pub struct QueryFilters {
    pub where_clause: String,
    pub args: PgArguments,
    pub next_param: usize,
}

impl QueryFilters {
    pub fn build(
        user_id: Option<i64>,
        user_ids: Option<&[i64]>,
        start_time: Option<f64>,
        end_time: Option<f64>,
        project: Option<&str>,
        projects: Option<&[String]>,
        category: Option<&str>,
        coding_only: Option<bool>,
        categories_exclude: Option<&[String]>,
    ) -> Self {
        let mut conditions = vec![
            "deleted_at IS NULL".to_string(),
            "time IS NOT NULL".to_string(),
            "time >= 0".to_string(),
            "time <= 253402300799".to_string(),
        ];
        let mut args = PgArguments::default();
        let mut param_idx = 1usize;

        if let Some(uid) = user_id {
            conditions.push(format!("user_id = ${}", param_idx));
            let _ = args.add(uid);
            param_idx += 1;
        }

        if let Some(uids) = user_ids {
            if !uids.is_empty() {
                let placeholders: Vec<String> = uids
                    .iter()
                    .enumerate()
                    .map(|(i, _)| format!("${}", param_idx + i))
                    .collect();
                conditions.push(format!("user_id IN ({})", placeholders.join(", ")));
                for uid in uids {
                    let _ = args.add(*uid);
                }
                param_idx += uids.len();
            }
        }

        if let Some(st) = start_time {
            conditions.push(format!("time >= ${}", param_idx));
            let _ = args.add(st);
            param_idx += 1;
        }

        if let Some(et) = end_time {
            conditions.push(format!("time <= ${}", param_idx));
            let _ = args.add(et);
            param_idx += 1;
        }

        if let Some(p) = project {
            conditions.push(format!("project = ${}", param_idx));
            let _ = args.add(p.to_string());
            param_idx += 1;
        }

        if let Some(ps) = projects {
            if !ps.is_empty() {
                let placeholders: Vec<String> = ps
                    .iter()
                    .enumerate()
                    .map(|(i, _)| format!("${}", param_idx + i))
                    .collect();
                conditions.push(format!("project IN ({})", placeholders.join(", ")));
                for p in ps {
                    let _ = args.add(p.clone());
                }
                param_idx += ps.len();
            }
        }

        if coding_only == Some(true) {
            conditions.push("category = 'coding'".to_string());
        } else if let Some(cat) = category {
            conditions.push(format!("category = ${}", param_idx));
            let _ = args.add(cat.to_string());
            param_idx += 1;
        }

        if let Some(excl) = categories_exclude {
            if !excl.is_empty() {
                let placeholders: Vec<String> = excl
                    .iter()
                    .enumerate()
                    .map(|(i, _)| format!("${}", param_idx + i))
                    .collect();
                conditions.push(format!(
                    "LOWER(category) NOT IN ({})",
                    placeholders.join(", ")
                ));
                for c in excl {
                    let _ = args.add(c.to_lowercase());
                }
                param_idx += excl.len();
            }
        }

        QueryFilters {
            where_clause: conditions.join(" AND "),
            args,
            next_param: param_idx,
        }
    }
}
