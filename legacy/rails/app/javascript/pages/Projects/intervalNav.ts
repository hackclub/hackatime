import { router } from "@inertiajs/svelte";

export const intervalParams = (
  interval?: string | null,
  from?: string | null,
  to?: string | null,
) => {
  const q = new URLSearchParams();
  if (interval) q.set("interval", interval);
  if (from) q.set("from", from);
  if (to) q.set("to", to);
  return q;
};

export const buildIntervalChange = (
  nextInterval: string,
  nextFrom: string,
  nextTo: string,
) => {
  const isCustom = Boolean(nextFrom || nextTo);
  return intervalParams(
    isCustom ? "custom" : nextInterval,
    isCustom ? nextFrom : "",
    isCustom ? nextTo : "",
  );
};

export const visitWithInterval = (
  basePath: string,
  query: URLSearchParams,
  only: string[],
) => {
  const qs = query.toString();
  router.visit(`${basePath}${qs ? `?${qs}` : ""}`, {
    only,
    preserveState: true,
    preserveScroll: true,
    replace: true,
    async: true,
  });
};
