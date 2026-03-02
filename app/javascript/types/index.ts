export type FlashData = {
  notice?: string;
  alert?: string;
};

export type SharedProps = {};

export type LeaderboardEntryUser = {
  id: number;
  display_name: string;
  avatar_url: string;
  profile_path: string;
};

export type LeaderboardActiveProject = {
  name: string;
  repo_url: string | null;
};

export type LeaderboardEntry = {
  rank: number;
  is_current_user: boolean;
  user: LeaderboardEntryUser;
  total_seconds: number;
  total_display: string;
  streak_count: number;
  active_project: LeaderboardActiveProject | null;
  needs_github_link: boolean;
  settings_path: string;
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
  language_count: number;
  branch_count: number;
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
