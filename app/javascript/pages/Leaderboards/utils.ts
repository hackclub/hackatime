export const secondsToDetailedDisplay = (seconds: number) => {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  const parts: string[] = [];
  if (h > 0) parts.push(`${h}h`);
  if (m > 0) parts.push(`${m}m`);
  if (s > 0) parts.push(`${s}s`);
  return parts.join(" ") || "0s";
};

export const timeAgo = (isoString: string) => {
  const diff = Date.now() - new Date(isoString).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins} minute${mins === 1 ? "" : "s"} ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} hour${hours === 1 ? "" : "s"} ago`;
  const days = Math.floor(hours / 24);
  return `${days} day${days === 1 ? "" : "s"} ago`;
};

export const rankDisplay = (index: number) => {
  if (index === 0) return "🥇";
  if (index === 1) return "🥈";
  if (index === 2) return "🥉";
  return `${index + 1}`;
};

export const streakTheme = (count: number) => {
  if (count >= 30)
    return {
      bg: "from-blue/20 to-purple/20",
      hbg: "hover:from-blue/30 hover:to-purple/30",
      bc: "border-blue",
      ic: "text-blue",
      tc: "text-blue",
    };
  if (count >= 7)
    return {
      bg: "from-red/20 to-orange/20",
      hbg: "hover:from-red/30 hover:to-orange/30",
      bc: "border-red",
      ic: "text-red",
      tc: "text-red",
    };
  return {
    bg: "from-orange/20 to-yellow/20",
    hbg: "hover:from-orange/30 hover:to-yellow/30",
    bc: "border-orange",
    ic: "text-orange",
    tc: "text-orange",
  };
};

export const streakLabel = (count: number) =>
  count > 30 ? "30+" : `${count}`;

export const tabClass = (active: boolean) =>
  `text-center px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 whitespace-nowrap ${active ? "bg-primary text-on-primary" : "text-muted hover:text-surface-content"}`;
