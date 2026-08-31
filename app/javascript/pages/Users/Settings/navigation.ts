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
import {
  UserCircle,
  CommandLine,
  Swatch,
  CodeBracket,
  ChatBubbleLeftRight,
  Bell,
  LockClosed,
  Trophy,
  Sparkles,
  ArrowsRightLeft,
  type IconSource,
} from "svelte-hero-icons";

type SettingsSection = {
  id: string;
  label: string;
  path: string;
  icon: IconSource;
};

export const SETTINGS_SECTIONS = [
  {
    id: "profile",
    label: "Profile",
    path: settingsProfile.my.path(),
    icon: UserCircle,
  },
  {
    id: "setup",
    label: "Setup",
    path: settingsSetup.show.path(),
    icon: CommandLine,
  },
  {
    id: "appearance",
    label: "Appearance",
    path: settingsAppearance.show.path(),
    icon: Swatch,
  },
  {
    id: "editors",
    label: "Editors",
    path: settingsEditors.show.path(),
    icon: CodeBracket,
  },
  {
    id: "slack_github",
    label: "Slack & GitHub",
    path: settingsSlackGithub.show.path(),
    icon: ChatBubbleLeftRight,
  },
  {
    id: "notifications",
    label: "Notifications",
    path: settingsNotifications.show.path(),
    icon: Bell,
  },
  {
    id: "privacy",
    label: "Privacy & Security",
    path: settingsPrivacy.show.path(),
    icon: LockClosed,
  },
  {
    id: "goals",
    label: "Goals",
    path: settingsGoals.show.path(),
    icon: Trophy,
  },
  {
    id: "badges",
    label: "Badges",
    path: settingsBadges.show.path(),
    icon: Sparkles,
  },
  {
    id: "imports_exports",
    label: "Imports & Exports",
    path: settingsImportsExports.show.path(),
    icon: ArrowsRightLeft,
  },
] as const satisfies readonly SettingsSection[];
