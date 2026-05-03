export type SectionId =
  | "profile"
  | "setup"
  | "appearance"
  | "editors"
  | "slack_github"
  | "notifications"
  | "privacy"
  | "goals"
  | "badges"
  | "imports_exports";

export type SectionPaths = Record<SectionId, string>;

export type SettingsSection = {
  id: SectionId;
  label: string;
  path: string;
};

export type SettingsSubsection = {
  id: string;
  label: string;
};

export type Option = {
  label: string;
  value: string;
};

export type ThemeOption = {
  value: string;
  label: string;
  description: string;
  color_scheme: "dark" | "light";
  theme_color: string;
  preview: {
    darker: string;
    dark: string;
    darkless: string;
    primary: string;
    content: string;
    info: string;
    success: string;
    warning: string;
  };
};

export type ProgrammingGoal = {
  id: string;
  period: "day" | "week" | "month";
  target_seconds: number;
  languages: string[];
  projects: string[];
  update_path: string;
  destroy_path: string;
};

export type GoalForm = {
  open: boolean;
  mode: "create" | "edit";
  goal_id: string | null;
  period: string;
  target_seconds: number;
  languages: string[];
  projects: string[];
  errors: string[];
};

export type UserProps = {
  id: number;
  display_name: string;
  timezone: string;
  country_code?: string | null;
  username?: string | null;
  theme: string;
  uses_slack_status: boolean;
  weekly_summary_email_enabled: boolean;
  hackatime_extension_text_type: string;
  show_goals_in_statusbar: boolean;
  allow_public_stats_lookup: boolean;
  trust_level: string;
  can_request_deletion: boolean;
  github_uid?: string | null;
  github_username?: string | null;
  slack_uid?: string | null;
};

export type PathsProps = {
  settings_path: string;
  wakatime_setup_path: string;
  slack_auth_path: string;
  github_auth_path: string;
  github_unlink_path: string;
  add_email_path: string;
  unlink_email_path: string;
  rotate_api_key_path: string;
  export_all_heartbeats_path: string;
  export_range_heartbeats_path: string;
  create_heartbeat_import_path: string;
  create_deletion_path: string;
};

export type BaseOptionsProps = {
  countries: Option[];
  timezones: Option[];
  extension_text_types: Option[];
  themes: ThemeOption[];
  badge_themes: string[];
};

export type GoalsOptionsProps = {
  goals: {
    periods: Option[];
    preset_target_seconds: number[];
    selectable_languages: Option[];
    selectable_projects: Option[];
  };
};

export type OptionsProps = BaseOptionsProps & GoalsOptionsProps;

export type SlackProps = {
  can_enable_status: boolean;
  notification_channels: {
    id: string;
    label: string;
    url: string;
  }[];
};

export type GithubProps = {
  connected: boolean;
  username?: string | null;
  profile_url?: string | null;
};

export type EmailProps = {
  email: string;
  source: string;
  can_unlink: boolean;
};

export type BadgesProps = {
  general_badge_url: string;
  project_badge_url?: string | null;
  project_badge_base_url?: string | null;
  projects: Array<{ display_name: string; repo_path: string }>;
  markscribe_template: string;
  markscribe_reference_url: string;
  markscribe_preview_image_url: string;
  heatmap_badge_url: string;
  heatmap_config_url: string;
  hackabox_repo_url: string;
  hackabox_preview_image_url: string;
};

export type ConfigFileProps = {
  content?: string | null;
  has_api_key: boolean;
  empty_message: string;
  api_key?: string | null;
  api_url: string;
};

export type DataExportProps = {
  total_heartbeats: string;
  total_coding_time: string;
  heartbeats_last_7_days: string;
  is_restricted: boolean;
};

export type UiProps = {
  show_dev_import: boolean;
  show_imports: boolean;
};

export type HeartbeatImportStatusProps = {
  import_id: string;
  state: string;
  source_kind: string;
  progress_percent: number | null; // null during importing when total is unknown
  processed_count: number;
  total_count: number | null;
  imported_count: number | null;
  skipped_count: number | null;
  errors_count: number;
  message: string;
  error_message?: string | null;
  remote_dump_status?: string | null;
  remote_percent_complete?: number | null;
  cooldown_until?: string | null;
  source_filename?: string | null;
  updated_at: string;
  started_at?: string | null;
  finished_at?: string | null;
};

export type ErrorsProps = {
  full_messages: string[];
  username: string[];
};

export type SettingsCommonProps = {
  active_section: SectionId;
  section_paths: SectionPaths;
  page_title: string;
  heading: string;
  subheading: string;
  errors: ErrorsProps;
};

export type ProfilePageProps = SettingsCommonProps & {
  region_update_path: string;
  username_update_path: string;
  username_max_length: number;
  user: Pick<UserProps, "country_code" | "timezone" | "username">;
  options: Pick<BaseOptionsProps, "countries" | "timezones">;
  profile_url: string | null;
  emails: EmailProps[];
  paths: Pick<PathsProps, "add_email_path" | "unlink_email_path">;
};

export type SetupPageProps = SettingsCommonProps & {
  paths: Pick<PathsProps, "wakatime_setup_path">;
  config_file: ConfigFileProps;
};

export type AppearancePageProps = SettingsCommonProps & {
  theme_update_path: string;
  user: Pick<UserProps, "theme">;
  options: Pick<BaseOptionsProps, "themes">;
};

export type EditorsPageProps = SettingsCommonProps & {
  settings_update_path: string;
  user: Pick<UserProps, "hackatime_extension_text_type" | "show_goals_in_statusbar">;
  options: Pick<BaseOptionsProps, "extension_text_types">;
};

export type SlackGithubPageProps = SettingsCommonProps & {
  settings_update_path: string;
  user: Pick<UserProps, "uses_slack_status">;
  slack: SlackProps;
  github: GithubProps;
  paths: Pick<
    PathsProps,
    "slack_auth_path" | "github_auth_path" | "github_unlink_path"
  >;
};

export type NotificationsPageProps = SettingsCommonProps & {
  settings_update_path: string;
  user: Pick<UserProps, "weekly_summary_email_enabled">;
};

export type PrivacyPageProps = SettingsCommonProps & {
  privacy_update_path: string;
  user: Pick<UserProps, "allow_public_stats_lookup" | "can_request_deletion">;
  paths: Pick<PathsProps, "rotate_api_key_path" | "create_deletion_path">;
  rotated_api_key?: string | null;
};

export type GoalsPageProps = SettingsCommonProps & {
  settings_update_path: string;
  create_goal_path: string;
  programming_goals: ProgrammingGoal[];
  options: GoalsOptionsProps;
  goal_form?: GoalForm | null;
};

export type BadgesPageProps = SettingsCommonProps & {
  badge_themes: string[];
  badges: BadgesProps;
  allow_public_stats_lookup: boolean;
  settings_update_path: string;
};

export type ImportsExportsPageProps = SettingsCommonProps & {
  paths: Pick<
    PathsProps,
    | "export_all_heartbeats_path"
    | "export_range_heartbeats_path"
    | "create_heartbeat_import_path"
  >;
  data_export?: DataExportProps;
  imports_enabled: boolean;
  remote_import_cooldown_until?: string | null;
  latest_heartbeat_import?: HeartbeatImportStatusProps | null;
  ui: UiProps;
};

export const buildSections = (
  sectionPaths: SectionPaths,
): SettingsSection[] => [
  {
    id: "profile",
    label: "Profile",
    path: sectionPaths.profile,
  },
  {
    id: "setup",
    label: "Setup",
    path: sectionPaths.setup,
  },
  {
    id: "appearance",
    label: "Appearance",
    path: sectionPaths.appearance,
  },
  {
    id: "editors",
    label: "Editors",
    path: sectionPaths.editors,
  },
  {
    id: "slack_github",
    label: "Slack & GitHub",
    path: sectionPaths.slack_github,
  },
  {
    id: "notifications",
    label: "Notifications",
    path: sectionPaths.notifications,
  },
  {
    id: "privacy",
    label: "Privacy & Security",
    path: sectionPaths.privacy,
  },
  {
    id: "goals",
    label: "Goals",
    path: sectionPaths.goals,
  },
  {
    id: "badges",
    label: "Badges",
    path: sectionPaths.badges,
  },
  {
    id: "imports_exports",
    label: "Imports & Exports",
    path: sectionPaths.imports_exports,
  },
];

const subsectionMap: Record<SectionId, SettingsSubsection[]> = {
  profile: [
    { id: "user_region", label: "Region" },
    { id: "user_username", label: "Username" },
    { id: "user_email_addresses", label: "Email addresses" },
  ],
  setup: [
    { id: "user_tracking_setup", label: "Setup guide" },
    { id: "user_config_file", label: "Config file" },
  ],
  appearance: [{ id: "user_theme", label: "Theme" }],
  editors: [{ id: "user_hackatime_extension", label: "Extension display" }],
  slack_github: [
    { id: "user_slack_status", label: "Slack status" },
    { id: "user_slack_notifications", label: "Slack channels" },
    { id: "user_github_account", label: "GitHub" },
  ],
  notifications: [
    { id: "user_email_notifications", label: "Email notifications" },
  ],
  privacy: [
    { id: "user_privacy", label: "Public stats" },
    { id: "user_api_key", label: "API key" },
    { id: "delete_account", label: "Account deletion" },
  ],
  goals: [{ id: "user_programming_goals", label: "Programming goals" }],
  badges: [
    { id: "user_stats_badges", label: "Stats badges" },
    { id: "user_markscribe", label: "Markscribe" },
    { id: "user_heatmap", label: "Heatmap" },
    { id: "user_hackabox", label: "Hackabox" },
  ],
  imports_exports: [
    { id: "user_imports", label: "Imports" },
    { id: "download_user_data", label: "Download data" },
  ],
};

export const buildSubsections = (
  activeSection: SectionId,
  exclude?: Set<string>,
): SettingsSubsection[] => {
  const items = subsectionMap[activeSection] || [];
  return exclude?.size ? items.filter((item) => !exclude.has(item.id)) : items;
};

const hashSectionMap: Record<string, SectionId> = {
  // Profile
  user_region: "profile",
  user_timezone: "profile",
  user_username: "profile",
  user_email_addresses: "profile",
  // Setup
  user_tracking_setup: "setup",
  user_config_file: "setup",
  // Appearance
  user_theme: "appearance",
  // Editors
  user_hackatime_extension: "editors",
  // Slack & GitHub
  user_slack_status: "slack_github",
  user_slack_notifications: "slack_github",
  user_github_account: "slack_github",
  // Notifications
  user_email_notifications: "notifications",
  user_weekly_summary_email: "notifications",
  // Privacy & Security
  user_privacy: "privacy",
  user_api_key: "privacy",
  delete_account: "privacy",
  // Goals
  user_programming_goals: "goals",
  // Badges
  user_stats_badges: "badges",
  user_markscribe: "badges",
  user_heatmap: "badges",
  user_hackabox: "badges",
  // Imports & Exports
  user_imports: "imports_exports",
  download_user_data: "imports_exports",
};

export const sectionFromHash = (hash: string): SectionId | null => {
  const cleanHash = hash.replace(/^#/, "");
  return hashSectionMap[cleanHash] || null;
};
