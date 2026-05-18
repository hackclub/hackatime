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
import type { SectionId } from "../types";

export const sectionIcons: Record<SectionId, IconSource> = {
  profile: UserCircle,
  setup: CommandLine,
  appearance: Swatch,
  editors: CodeBracket,
  slack_github: ChatBubbleLeftRight,
  notifications: Bell,
  privacy: LockClosed,
  goals: Trophy,
  badges: Sparkles,
  imports_exports: ArrowsRightLeft,
};
