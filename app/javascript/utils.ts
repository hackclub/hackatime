export const pluralize = (count: number, singular: string, plural: string) =>
  count === 1 ? singular : plural;

export const toSentence = (items: string[]) => {
  if (items.length === 0) return "";
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(", ")}, and ${items[items.length - 1]}`;
};

export const secondsToDisplay = (seconds?: number) => {
  if (!seconds) return "0m";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return hours > 0 ? (minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`) : `${minutes}m`;
};

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

export const secondsToCompactDisplay = (seconds?: number) => {
  if (!seconds) return "0m";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return hours > 0 ? `${hours}h` : `${minutes}m`;
};

export const durationInWords = (seconds: number): string => {
  if (seconds < 60) return "less than a minute";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `about ${hours} ${hours === 1 ? "hour" : "hours"}`;
  return `${minutes} ${minutes === 1 ? "minute" : "minutes"}`;
};

export const percentOf = (value: number, max: number) => {
  if (!max || max === 0) return 0;
  return Math.max(2, Math.round((value / max) * 100));
};

export const logScale = (value: number, maxVal: number): number => {
  if (value === 0) return 0;
  const minPercent = 5;
  const maxPercent = 100;
  const linearRatio = value / maxVal;
  const logRatio = Math.log(value + 1) / Math.log(maxVal + 1);
  const linearWeight = 0.8;
  const logWeight = 0.2;
  const scaled =
    minPercent +
    (linearWeight * linearRatio + logWeight * logRatio) *
      (maxPercent - minPercent);
  return Math.min(Math.round(scaled), maxPercent);
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

export const streakTheme = (count: number) => {
  if (count >= 30)
    return {
      bg: "from-blue/20 to-purple/20",
      hbg: "hover:from-blue/30 hover:to-purple/30",
      bc: "border-blue",
      ic: "text-blue",
      tc: "text-blue",
      tm: "text-blue",
    };
  if (count >= 7)
    return {
      bg: "from-red/20 to-orange/20",
      hbg: "hover:from-red/30 hover:to-orange/30",
      bc: "border-red",
      ic: "text-red",
      tc: "text-red",
      tm: "text-red",
    };
  return {
    bg: "from-orange/20 to-yellow/20",
    hbg: "hover:from-orange/30 hover:to-yellow/30",
    bc: "border-orange",
    ic: "text-orange",
    tc: "text-orange",
    tm: "text-orange",
  };
};

export const streakLabel = (count: number) => `${count}`;

export const rankDisplay = (index: number) => {
  if (index === 0) return "🥇";
  if (index === 1) return "🥈";
  if (index === 2) return "🥉";
  return `${index + 1}`;
};
