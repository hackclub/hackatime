<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import CountryFlag from "../../../components/CountryFlag.svelte";
  import Twemoji from "../../../components/Twemoji.svelte";
  import type { LeaderboardCountry } from "../../../types";
  import { tabClass } from "../utils";
  import { leaderboards } from "../../../api";

  let {
    period_type,
    scope,
    country,
  }: {
    period_type: string;
    scope: string;
    country: LeaderboardCountry;
  } = $props();

  const path = (q: Record<string, string | number>) =>
    leaderboards.index.path({ query: q });
  const resetEntries = (current: Record<string, unknown>) => ({
    ...current,
    entries: undefined,
  });
</script>

<div class="inline-flex rounded-full bg-darkless p-1 gap-1">
  <Link
    href={path({ period_type, scope: "global" })}
    component="Leaderboards/Index"
    pageProps={(current) => ({ ...resetEntries(current), scope: "global" })}
    class={`${tabClass(scope === "global")} inline-flex items-center justify-center gap-2`}
    preserveScroll
  >
    <Twemoji emoji="🌐" alt="Globe" class="inline-block w-5 h-5" />
    <span class="hidden sm:inline">Global</span>
  </Link>

  {#if country.available}
    <Link
      href={path({ period_type, scope: "country" })}
      component="Leaderboards/Index"
      pageProps={(current) => ({ ...resetEntries(current), scope: "country" })}
      class={`${tabClass(scope === "country")} inline-flex items-center justify-center gap-2`}
      preserveScroll
    >
      <CountryFlag countryCode={country.code} class="inline-block w-5 h-5" />
      <span class="hidden sm:inline max-w-48 truncate">{country.name}</span>
    </Link>
  {:else}
    <span
      class="text-center px-4 py-2 rounded-full text-sm font-medium text-muted/60 bg-darker cursor-not-allowed whitespace-nowrap inline-flex items-center justify-center gap-2"
    >
      <Twemoji
        emoji="🏳️"
        alt="No country"
        class="inline-block w-5 h-5 opacity-60"
      />
      <span class="hidden sm:inline">Country</span>
    </span>
  {/if}
</div>

<div class="inline-flex rounded-full bg-darkless p-1 gap-1">
  {#each [{ key: "daily", short: "24h", long: "Last 24 Hours" }, { key: "last_7_days", short: "7d", long: "Last 7 Days" }] as p}
    <Link
      href={path({ period_type: p.key, scope })}
      component="Leaderboards/Index"
      pageProps={(current) => ({
        ...resetEntries(current),
        period_type: p.key,
      })}
      class={tabClass(period_type === p.key)}
      preserveScroll
    >
      <span class="sm:hidden">{p.short}</span>
      <span class="hidden sm:inline">{p.long}</span>
    </Link>
  {/each}
</div>
