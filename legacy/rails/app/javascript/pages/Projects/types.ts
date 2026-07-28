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
  broken_name: boolean;
  manage_enabled: boolean;
};
