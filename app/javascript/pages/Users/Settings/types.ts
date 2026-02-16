export type SectionId =
  | "profile"
  | "integrations"
  | "access"
  | "badges"
  | "data"
  | "admin";

export type SectionPaths = Record<SectionId, string>;

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

export type UserProps = {
  id: number;
  display_name: string;
  timezone: string;
  country_code?: string | null;
  username?: string | null;
  theme: string;
  uses_slack_status: boolean;
  hackatime_extension_text_type: string;
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
  migrate_heartbeats_path: string;
  export_all_heartbeats_path: string;
  export_range_heartbeats_path: string;
  create_heartbeat_import_path: string;
  create_deletion_path: string;
  user_wakatime_mirrors_path: string;
};

export type OptionsProps = {
  countries: Option[];
  timezones: Option[];
  extension_text_types: Option[];
  themes: ThemeOption[];
  badge_themes: string[];
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
  projects: string[];
  profile_url?: string | null;
  markscribe_template: string;
  markscribe_reference_url: string;
  markscribe_preview_image_url: string;
};

export type ConfigFileProps = {
  content?: string | null;
  has_api_key: boolean;
  empty_message: string;
  api_key?: string | null;
  api_url: string;
};

export type MigrationProps = {
  jobs: { id: string; status: string }[];
};

export type DataExportProps = {
  total_heartbeats: string;
  total_coding_time: string;
  heartbeats_last_7_days: string;
  is_restricted: boolean;
};

export type AdminToolsProps = {
  visible: boolean;
  mirrors: {
    id: number;
    endpoint_url: string;
    last_synced_ago: string;
    destroy_path: string;
  }[];
};

export type UiProps = {
  show_dev_import: boolean;
};

export type HeartbeatImportStatusProps = {
  import_id: string;
  state: string;
  progress_percent: number;
  processed_count: number;
  total_count: number | null;
  imported_count: number | null;
  skipped_count: number | null;
  errors_count: number;
  message: string;
  updated_at: string;
  started_at?: string;
  finished_at?: string;
};

export type HeartbeatImportProps = {
  import_id?: string | null;
  status?: HeartbeatImportStatusProps | null;
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
  admin_tools: AdminToolsProps;
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

export type BadgesPageProps = SettingsCommonProps & {
  options: OptionsProps;
  badges: BadgesProps;
};

export type DataPageProps = SettingsCommonProps & {
  user: UserProps;
  paths: PathsProps;
  migration: MigrationProps;
  data_export: DataExportProps;
  ui: UiProps;
  heartbeat_import: HeartbeatImportProps;
};

export type AdminPageProps = SettingsCommonProps & {
  admin_tools: AdminToolsProps;
  paths: PathsProps;
};

export const buildSections = (sectionPaths: SectionPaths, adminVisible: boolean) => {
  const sections = [
    {
      id: "profile" as SectionId,
      label: "Profile",
      blurb: "Username, region, timezone, and privacy.",
      path: sectionPaths.profile,
    },
    {
      id: "integrations" as SectionId,
      label: "Integrations",
      blurb: "Slack status, GitHub link, and email sign-in addresses.",
      path: sectionPaths.integrations,
    },
    {
      id: "access" as SectionId,
      label: "Access",
      blurb: "Time tracking setup, extension options, and API key access.",
      path: sectionPaths.access,
    },
    {
      id: "badges" as SectionId,
      label: "Badges",
      blurb: "Shareable badges and profile snippets.",
      path: sectionPaths.badges,
    },
    {
      id: "data" as SectionId,
      label: "Data",
      blurb: "Exports, migration jobs, and account deletion controls.",
      path: sectionPaths.data,
    },
  ];

  if (adminVisible) {
    sections.push({
      id: "admin",
      label: "Admin",
      blurb: "WakaTime mirror endpoints.",
      path: sectionPaths.admin,
    });
  }

  return sections;
};

const hashSectionMap: Record<string, SectionId> = {
  user_region: "profile",
  user_timezone: "profile",
  user_username: "profile",
  user_privacy: "profile",
  user_theme: "profile",
  user_hackatime_extension: "access",
  user_api_key: "access",
  user_config_file: "access",
  user_slack_status: "integrations",
  user_slack_notifications: "integrations",
  user_github_account: "integrations",
  user_email_addresses: "integrations",
  user_stats_badges: "badges",
  user_markscribe: "badges",
  user_migration_assistant: "data",
  download_user_data: "data",
  delete_account: "data",
  wakatime_mirror: "admin",
};

export const sectionFromHash = (hash: string): SectionId | null => {
  const cleanHash = hash.replace(/^#/, "");
  return hashSectionMap[cleanHash] || null;
};
