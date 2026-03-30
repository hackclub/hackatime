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
