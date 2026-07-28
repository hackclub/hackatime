import type { Scenario } from "./types"

const range = "start_date=2026-01-10T00%3A00%3A00Z&end_date=2026-01-11T00%3A00%3A00Z"

export const scenarios: Scenario[] = [
  {
    name: "unauthorized heartbeat ingest",
    method: "POST",
    path: "/api/hackatime/v1/users/current/heartbeats",
    body: [{ entity: "src/main.rs", time: 1768003200 }],
    expectedStatus: 401
  },
  {
    name: "empty heartbeat ingest",
    method: "POST",
    path: "/api/hackatime/v1/users/current/heartbeats",
    body: [],
    authenticated: true,
    expectedStatus: 400
  },
  {
    name: "oversized heartbeat bulk ingest",
    method: "POST",
    path: "/api/hackatime/v1/users/current/heartbeats.bulk",
    body: Array.from({ length: 101 }, (_, index) => ({
      entity: `src/file-${index}.rs`,
      time: 1768003200 + index
    })),
    authenticated: true,
    expectedStatus: 400
  },
  {
    name: "current user",
    method: "GET",
    path: "/api/v1/authenticated/me",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "api keys",
    method: "GET",
    path: "/api/v1/authenticated/api_keys",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "authenticated hours",
    method: "GET",
    path: "/api/v1/authenticated/hours?start_date=2026-01-10&end_date=2026-01-10",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "authenticated streak",
    method: "GET",
    path: "/api/v1/authenticated/streak",
    authenticated: true,
    expectedStatus: 200,
    volatilePaths: ["streak_days"]
  },
  {
    name: "authenticated projects",
    method: "GET",
    path: "/api/v1/authenticated/projects?start=2026-01-10T00%3A00%3A00Z&end=2026-01-11T00%3A00%3A00Z",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "latest heartbeat",
    method: "GET",
    path: "/api/v1/authenticated/heartbeats/latest",
    authenticated: true,
    expectedStatus: 200,
    volatilePaths: [
      "id",
      "category",
      "editor",
      "entity",
      "language",
      "machine",
      "operating_system",
      "project",
      "time"
    ]
  },
  {
    name: "heartbeat list",
    method: "GET",
    path: "/api/v1/my/heartbeats?start_time=2026-01-10T00%3A00%3A00Z&end_time=2026-01-11T00%3A00%3A00Z",
    authenticated: true,
    expectedStatus: 200,
    volatilePaths: ["heartbeats.*.id"]
  },
  {
    name: "most recent heartbeat",
    method: "GET",
    path: "/api/v1/my/heartbeats/most_recent?source_type=direct_entry",
    authenticated: true,
    expectedStatus: 200,
    volatilePaths: ["heartbeat", "editor", "time_ago"]
  },
  {
    name: "heartbeat spans",
    method: "GET",
    path: `/api/v1/users/testuser/heartbeats/spans?${range}`,
    expectedStatus: 200
  },
  {
    name: "heartbeat spans by project",
    method: "GET",
    path: `/api/v1/users/testuser/heartbeats/spans?${range}&project=alpha`,
    expectedStatus: 200
  },
  {
    name: "total seconds",
    method: "GET",
    path: `/api/v1/users/testuser/stats?${range}&total_seconds=true`,
    expectedStatus: 200
  },
  {
    name: "total seconds by project",
    method: "GET",
    path: `/api/v1/users/testuser/stats?${range}&total_seconds=true&filter_by_project=alpha`,
    expectedStatus: 200
  },
  {
    name: "total seconds from start",
    method: "GET",
    path: "/api/v1/users/testuser/stats?start_date=2026-01-10T12%3A12%3A00Z&total_seconds=true&filter_by_project=alpha",
    expectedStatus: 200
  },
  {
    name: "total seconds through end",
    method: "GET",
    path: "/api/v1/users/testuser/stats?end_date=2026-01-10T12%3A23%3A00Z&total_seconds=true&filter_by_project=alpha",
    expectedStatus: 200
  },
  {
    name: "total seconds by category",
    method: "GET",
    path: `/api/v1/users/testuser/stats?${range}&total_seconds=true&filter_by_category=coding`,
    expectedStatus: 200
  },
  {
    name: "total seconds without ai",
    method: "GET",
    path: `/api/v1/users/testuser/stats?${range}&total_seconds=true&no_ai_coding=true`,
    expectedStatus: 200
  },
  {
    name: "summary full range",
    method: "GET",
    path: "/api/summary?user_id=testuser&start=2026-01-10&end=2026-01-10",
    expectedStatus: 200
  },
  {
    name: "last seven days",
    method: "GET",
    path: "/api/hackatime/v1/users/current/stats/last_7_days",
    authenticated: true,
    expectedStatus: 200,
    volatilePaths: ["data"]
  },
  {
    name: "global stats",
    method: "GET",
    path: "/api/v1/stats?start_date=2026-01-10&end_date=2026-01-10&username=testuser",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "banned user counts",
    method: "GET",
    path: "/api/v1/banned_users/counts",
    expectedStatus: 200
  },
  {
    name: "lookup email",
    method: "GET",
    path: "/api/v1/users/lookup_email/test@example.com",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "lookup slack uid",
    method: "GET",
    path: "/api/v1/users/lookup_slack_uid/TEST123456",
    authenticated: true,
    expectedStatus: 200
  },
  {
    name: "project badge",
    method: "GET",
    path: "/api/v1/badge/testuser/alpha",
    expectedStatus: 307
  },
  {
    name: "currently hacking",
    method: "GET",
    path: "/api/v1/currently_hacking",
    expectedStatus: 200,
    volatilePaths: ["count", "users"]
  },
  {
    name: "daily leaderboard",
    method: "GET",
    path: "/api/v1/leaderboard/daily",
    contractOnly: true,
    expectedStatus: [200, 503]
  },
  {
    name: "weekly leaderboard",
    method: "GET",
    path: "/api/v1/leaderboard/weekly",
    contractOnly: true,
    expectedStatus: [200, 503]
  },
  {
    name: "project names",
    method: "GET",
    path: "/api/v1/users/testuser/projects?since=2026-01-10T00%3A00%3A00Z&until=2026-01-11T00%3A00%3A00Z",
    expectedStatus: 200
  },
  {
    name: "project details",
    method: "GET",
    path: `/api/v1/users/testuser/projects/details?projects=alpha,beta&${range}`,
    expectedStatus: 200
  },
  {
    name: "single project",
    method: "GET",
    path: `/api/v1/users/testuser/project/alpha?${range}`,
    expectedStatus: 200
  },
  {
    name: "trust factor",
    method: "GET",
    path: "/api/v1/users/testuser/trust_factor",
    expectedStatus: 200
  },
  {
    name: "unknown user",
    method: "GET",
    path: "/api/v1/users/conformance-missing-user/projects",
    expectedStatus: 404
  },
  {
    name: "invalid date",
    method: "GET",
    path: "/api/v1/users/testuser/stats?start_date=invalid&end_date=2026-01-11",
    expectedStatus: 422
  }
]

export const benchmarkScenarios = scenarios.filter(({ name }) =>
  [
    "heartbeat spans",
    "total seconds",
    "total seconds by project",
    "summary full range",
    "project details"
  ].includes(name)
)
