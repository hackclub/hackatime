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
