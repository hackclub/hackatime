import {
  settingsProfile,
  settingsSetup,
  settingsAppearance,
  settingsEditors,
  settingsSlackGithub,
  settingsNotifications,
  settingsPrivacy,
  settingsGoals,
  settingsBadges,
  settingsImportsExports,
} from "../../../api";

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

// Static map of section paths, derived from js_from_routes path helpers.
// Stable across renders so we can pass it down without re-computing.
export const SECTION_PATHS: SectionPaths = {
  profile: settingsProfile.my.path(),
  setup: settingsSetup.show.path(),
  appearance: settingsAppearance.show.path(),
  editors: settingsEditors.show.path(),
  slack_github: settingsSlackGithub.show.path(),
  notifications: settingsNotifications.show.path(),
  privacy: settingsPrivacy.show.path(),
  goals: settingsGoals.show.path(),
  badges: settingsBadges.show.path(),
  imports_exports: settingsImportsExports.show.path(),
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
  page_title: string;
  heading: string;
  subheading: string;
  errors: ErrorsProps;
};

export type ProfilePageProps = SettingsCommonProps & {
  username_max_length: number;
  user: Pick<UserProps, "country_code" | "timezone" | "username">;
  options: Pick<BaseOptionsProps, "countries" | "timezones">;
  profile_url: string | null;
  emails: EmailProps[];
};

export type SetupPageProps = SettingsCommonProps & {
  config_file: ConfigFileProps;
};

export type AppearancePageProps = SettingsCommonProps & {
  user: Pick<UserProps, "theme">;
  options: Pick<BaseOptionsProps, "themes">;
};

export type EditorsPageProps = SettingsCommonProps & {
  user: Pick<UserProps, "hackatime_extension_text_type" | "show_goals_in_statusbar">;
  options: Pick<BaseOptionsProps, "extension_text_types">;
};

export type SlackGithubPageProps = SettingsCommonProps & {
  user: Pick<UserProps, "uses_slack_status">;
  slack: SlackProps;
  github: GithubProps;
};

export type NotificationsPageProps = SettingsCommonProps & {
  user: Pick<UserProps, "weekly_summary_email_enabled">;
};

export type PrivacyPageProps = SettingsCommonProps & {
  user: Pick<UserProps, "allow_public_stats_lookup" | "can_request_deletion">;
  rotated_api_key?: string | null;
};

export type GoalsPageProps = SettingsCommonProps & {
  programming_goals: ProgrammingGoal[];
  options: GoalsOptionsProps;
  goal_form?: GoalForm | null;
};

export type BadgesPageProps = SettingsCommonProps & {
  badge_themes: string[];
  badges: BadgesProps;
  allow_public_stats_lookup: boolean;
};

export type ImportsExportsPageProps = SettingsCommonProps & {
  data_export?: DataExportProps;
  imports_enabled: boolean;
  remote_import_cooldown_until?: string | null;
  latest_heartbeat_import?: HeartbeatImportStatusProps | null;
  ui: UiProps;
};

export const buildSections = (): SettingsSection[] => [
  { id: "profile", label: "Profile", path: SECTION_PATHS.profile },
  { id: "setup", label: "Setup", path: SECTION_PATHS.setup },
  { id: "appearance", label: "Appearance", path: SECTION_PATHS.appearance },
  { id: "editors", label: "Editors", path: SECTION_PATHS.editors },
  {
    id: "slack_github",
    label: "Slack & GitHub",
    path: SECTION_PATHS.slack_github,
  },
  {
    id: "notifications",
    label: "Notifications",
    path: SECTION_PATHS.notifications,
  },
  {
    id: "privacy",
    label: "Privacy & Security",
    path: SECTION_PATHS.privacy,
  },
  { id: "goals", label: "Goals", path: SECTION_PATHS.goals },
  { id: "badges", label: "Badges", path: SECTION_PATHS.badges },
  {
    id: "imports_exports",
    label: "Imports & Exports",
    path: SECTION_PATHS.imports_exports,
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
