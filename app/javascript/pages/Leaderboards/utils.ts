export {
  secondsToDetailedDisplay,
  timeAgo,
  rankDisplay,
  streakTheme,
  streakLabel,
} from "../../utils";

export const tabClass = (active: boolean) =>
  `text-center px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 whitespace-nowrap ${active ? "bg-primary text-on-primary" : "text-muted hover:text-surface-content"}`;
