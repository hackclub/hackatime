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
