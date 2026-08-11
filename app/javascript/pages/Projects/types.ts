export type ProjectCard = {
  id: string;
  name: string;
  project_key?: string | null;
  url_safe: boolean;
  duration_label: string;
  repo_url?: string | null;
  repository?: {
    homepage?: string | null;
    description?: string | null;
    formatted_languages?: string | null;
    last_commit_ago?: string | null;
  } | null;
  momentum?: ProjectMomentum | null;
  broken_name: boolean;
  manage_enabled: boolean;
};

export type ProjectMomentum = {
  weeks: { week: string; duration_seconds: number }[];
  current_seconds: number;
  current_label: string;
  comparison_seconds: number;
  trend: "increasing" | "steady" | "decreasing" | "new";
  change_percent: number | null;
  last_active_at: string | null;
  last_active_label: string | null;
};
