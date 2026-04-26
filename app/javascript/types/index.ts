export type FlashData = {
  notice?: string;
  alert?: string;
};

export type SharedProps = {};

export type LeaderboardEntryUser = {
  display_name: string;
  avatar_url: string | null;
  profile_path: string | null;
  verified: boolean;
  country_code: string | null;
  red: boolean;
};

export type LeaderboardEntry = {
  user_id: number;
  total_seconds: number;
  streak_count: number;
  is_current_user: boolean;
  user: LeaderboardEntryUser;
  active_project: { name: string; repo_url: string | null } | null;
};

export type LeaderboardMeta = {
  date_range_text: string;
  updated_at: string;
  finished_generating: boolean;
  generation_duration_seconds: number | null;
};

export type LeaderboardCountry = {
  code: string | null;
  name: string | null;
  available: boolean;
};

export type LeaderboardEntriesPayload = {
  entries: LeaderboardEntry[];
  total: number;
};

export type ActivityGraphData = {
  start_date: string;
  end_date: string;
  duration_by_date: Record<string, number>;
  busiest_day_seconds: number;
  timezone_label: string;
  timezone_settings_path: string;
};

export type ProjectStats = {
  total_time: number;
  total_time_label: string;
  file_count: number;
  language_stats: Record<string, number>;
  language_colors: Record<string, string>;
  editor_stats: Record<string, number>;
  os_stats: Record<string, number>;
  category_stats: Record<string, number>;
  file_stats: [string, number][];
  branch_stats: [string, number][];
  activity_graph: ActivityGraphData;
};

export type SocialProofUser = { display_name: string; avatar_url: string };

export type FilterableDashboardData = {
  total_time: number;
  total_heartbeats: number;
  top_project: string | null;
  top_language: string | null;
  top_editor: string | null;
  top_operating_system: string | null;
  project_durations: Record<string, number>;
  language_stats: Record<string, number>;
  editor_stats: Record<string, number>;
  operating_system_stats: Record<string, number>;
  category_stats: Record<string, number>;
  weekly_project_stats: Record<string, Record<string, number>>;
  project: string[];
  language: string[];
  editor: string[];
  operating_system: string[];
  category: string[];
  selected_interval: string;
  selected_from: string;
  selected_to: string;
  selected_project: string[];
  selected_language: string[];
  selected_editor: string[];
  selected_operating_system: string[];
  selected_category: string[];
};

export type TodayStats = {
  show_logged_time_sentence: boolean;
  todays_duration_display: string;
  todays_languages: string[];
  todays_editors: string[];
};

export type ProjectShowProps = {
  page_title: string;
  project_name: string;
  back_path: string;
  since_date?: string | null;
  repo_url?: string | null;
  is_shared: boolean;
  share_url?: string | null;
  toggle_share_path: string;
  interval?: string | null;
  from?: string | null;
  to?: string | null;
  project_stats?: ProjectStats;
};

export type PublicProjectShowProps = {
  page_title: string;
  project_name: string;
  username: string;
  profile_path: string;
  since_date?: string | null;
  repo_url?: string | null;
  total_time_label: string;
  file_count: number;
  language_stats: Record<string, number>;
  language_colors: Record<string, string>;
  file_stats: [string, number][];
  branch_stats: [string, number][];
};

export type ProgrammingGoalProgress = {
  id: string;
  period: "day" | "week" | "month";
  target_seconds: number;
  tracked_seconds: number;
  completion_percent: number;
  complete: boolean;
  languages: string[];
  projects: string[];
  period_end: string;
};
