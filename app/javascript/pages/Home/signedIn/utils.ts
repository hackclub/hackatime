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
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
};

export const percentOf = (value: number, max: number) => {
  if (!max || max === 0) return 0;
  return Math.max(2, Math.round((value / max) * 100));
};
