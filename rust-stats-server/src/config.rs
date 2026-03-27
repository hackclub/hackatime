pub struct Config {
    pub database_url: String,
    pub auth_token: String,
    pub listen_addr: String,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: std::env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            auth_token: std::env::var("AUTH_TOKEN").unwrap_or_else(|_| "dev-token".to_string()),
            listen_addr: std::env::var("LISTEN_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:4000".to_string()),
        }
    }
}
