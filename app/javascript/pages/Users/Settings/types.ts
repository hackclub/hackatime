export type SectionId =
  | "profile"
  | "integrations"
  | "notifications"
  | "access"
  | "goals"
  | "badges"
  | "data";

export type SectionPaths = Record<SectionId, string>;

export type SettingsSection = {
  id: SectionId;
  label: string;
  blurb: string;
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
  allow_public_stats_lookup: boolean;
  trust_level: string;
  can_request_deletion: boolean;
  github_uid?: string | null;
  github_username?: string | null;
  slack_uid?: string | null;
  programming_goals: ProgrammingGoal[];
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

export type OptionsProps = {
  countries: Option[];
  timezones: Option[];
  extension_text_types: Option[];
  themes: ThemeOption[];
  badge_themes: string[];
  goals: {
    periods: Option[];
    preset_target_seconds: number[];
    selectable_languages: Option[];
    selectable_projects: Option[];
  };
};

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
  profile_url?: string | null;
  markscribe_template: string;
  markscribe_reference_url: string;
  markscribe_preview_image_url: string;
  heatmap_badge_url: string;
  heatmap_config_url: string;
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
  settings_update_path: string;
  username_max_length: number;
  user: UserProps;
  options: OptionsProps;
  badges: BadgesProps;
};

export type IntegrationsPageProps = SettingsCommonProps & {
  settings_update_path: string;
  user: UserProps;
  slack: SlackProps;
  github: GithubProps;
  emails: EmailProps[];
  paths: PathsProps;
};

export type AccessPageProps = SettingsCommonProps & {
  settings_update_path: string;
  user: UserProps;
  options: OptionsProps;
  paths: PathsProps;
  config_file: ConfigFileProps;
};

export type NotificationsPageProps = SettingsCommonProps & {
  settings_update_path: string;
  user: UserProps;
};

export type GoalsPageProps = SettingsCommonProps & {
  settings_update_path: string;
  create_goal_path: string;
  user: UserProps;
  options: OptionsProps;
  goal_form?: GoalForm | null;
};

export type BadgesPageProps = SettingsCommonProps & {
  options: OptionsProps;
  badges: BadgesProps;
};

export type DataPageProps = SettingsCommonProps & {
  user: UserProps;
  paths: PathsProps;
  data_export: DataExportProps;
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
    blurb: "Username, region, timezone, and privacy.",
    path: sectionPaths.profile,
  },
  {
    id: "integrations",
    label: "Integrations",
    blurb: "Slack status, GitHub link, and email sign-in addresses.",
    path: sectionPaths.integrations,
  },
  {
    id: "notifications",
    label: "Notifications",
    blurb: "Email notifications and weekly summary preferences.",
    path: sectionPaths.notifications,
  },
  {
    id: "access",
    label: "Access",
    blurb: "Time tracking setup, extension options, and API key access.",
    path: sectionPaths.access,
  },
  {
    id: "goals",
    label: "Goals",
    blurb: "Set daily, weekly, or monthly programming targets.",
    path: sectionPaths.goals,
  },
  {
    id: "badges",
    label: "Badges",
    blurb: "Shareable badges and profile snippets.",
    path: sectionPaths.badges,
  },
  {
    id: "data",
    label: "Data",
    blurb: "Exports, imports, and deletion controls.",
    path: sectionPaths.data,
  },
];

const subsectionMap: Record<SectionId, SettingsSubsection[]> = {
  profile: [
    { id: "user_region", label: "Region" },
    { id: "user_username", label: "Username" },
    { id: "user_privacy", label: "Privacy" },
    { id: "user_theme", label: "Theme" },
  ],
  integrations: [
    { id: "user_slack_status", label: "Slack status" },
    { id: "user_slack_notifications", label: "Slack channels" },
    { id: "user_github_account", label: "GitHub" },
    { id: "user_email_addresses", label: "Email addresses" },
  ],
  notifications: [
    { id: "user_email_notifications", label: "Email notifications" },
  ],
  access: [
    { id: "user_tracking_setup", label: "Setup" },
    { id: "user_hackatime_extension", label: "Extension display" },
    { id: "user_api_key", label: "API key" },
    { id: "user_config_file", label: "Config file" },
  ],
  goals: [{ id: "user_programming_goals", label: "Programming goals" }],
  badges: [
    { id: "user_stats_badges", label: "Stats badges" },
    { id: "user_markscribe", label: "Markscribe" },
    { id: "user_heatmap", label: "Heatmap" },
  ],
  data: [
    { id: "user_imports", label: "Imports" },
    { id: "download_user_data", label: "Download data" },
    { id: "delete_account", label: "Account deletion" },
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
  user_region: "profile",
  user_timezone: "profile",
  user_username: "profile",
  user_privacy: "profile",
  user_theme: "profile",
  user_tracking_setup: "access",
  user_hackatime_extension: "access",
  user_api_key: "access",
  user_config_file: "access",
  user_programming_goals: "goals",
  user_slack_status: "integrations",
  user_slack_notifications: "integrations",
  user_github_account: "integrations",
  user_email_addresses: "integrations",
  user_email_notifications: "notifications",
  user_weekly_summary_email: "notifications",
  user_stats_badges: "badges",
  user_markscribe: "badges",
  user_heatmap: "badges",
  user_imports: "data",
  download_user_data: "data",
  delete_account: "data",
};

export const sectionFromHash = (hash: string): SectionId | null => {
  const cleanHash = hash.replace(/^#/, "");
  return hashSectionMap[cleanHash] || null;
};
