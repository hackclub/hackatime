<script lang="ts">
  import type { PageProps as InertiaPageProps } from "@inertiajs/core";
  import { Deferred, Link } from "@inertiajs/svelte";
  import CountryFlag from "../../components/CountryFlag.svelte";
  import Twemoji from "../../components/Twemoji.svelte";
  import Button from "../../components/Button.svelte";
  import type {
    LeaderboardMeta,
    LeaderboardCountry,
    LeaderboardEntriesPayload,
  } from "../../types";
  import {
    secondsToDetailedDisplay,
    timeAgo,
    rankDisplay,
    streakTheme,
    streakLabel,
    tabClass,
  } from "./utils";

  let {
    period_type,
    scope,
    country,
    leaderboard,
    is_logged_in,
    github_uid_blank,
    github_auth_path,
    settings_path,
    entries,
  }: {
    period_type: string;
    scope: string;
    country: LeaderboardCountry;
    leaderboard: LeaderboardMeta | null;
    is_logged_in: boolean;
    github_uid_blank: boolean;
    github_auth_path: string;
    settings_path: string;
    entries?: LeaderboardEntriesPayload;
  } = $props();

  const dateRangeText = $derived(
    leaderboard?.date_range_text ??
      (period_type === "last_7_days"
        ? (() => {
            const end = new Date();
            const start = new Date(end);
            start.setDate(start.getDate() - 6);
            return `${start.toLocaleDateString("en-US", { month: "long", day: "numeric" })} - ${end.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" })}`;
          })()
        : new Date().toLocaleDateString("en-US", {
            month: "long",
            day: "numeric",
            year: "numeric",
          })),
  );

  const instantLeaderboardPageProps = ({
    nextPeriodType = period_type,
    nextScope = scope,
  }: {
    nextPeriodType?: string;
    nextScope?: string;
  } = {}) => {
    return (
      currentProps: InertiaPageProps,
      sharedProps: Partial<InertiaPageProps>,
    ) => {
      const currentPage = currentProps as {
        country: LeaderboardCountry;
        is_logged_in: boolean;
        github_uid_blank: boolean;
        github_auth_path: string;
        settings_path: string;
      };

      return {
        ...sharedProps,
        ...currentPage,
        period_type: nextPeriodType,
        scope: nextScope,
        leaderboard: null,
        entries: undefined,
      };
    };
  };
</script>

<svelte:head>
  <title>Leaderboards | Hackatime</title>
</svelte:head>

<div class="max-w-6xl mx-auto px-3 py-4 sm:p-6">
  <div class="mb-8 space-y-4">
    <h1 class="text-3xl font-bold text-surface-content">Leaderboards</h1>

    <div class="flex flex-row items-center justify-between gap-3">
      <!-- Scope tabs -->
      <div class="inline-flex rounded-full bg-darkless p-1 gap-1">
        <Link
          href={`/leaderboards?period_type=${period_type}&scope=global`}
          class={`${tabClass(scope === "global")} inline-flex items-center justify-center gap-2`}
          component="Leaderboards/Index"
          pageProps={instantLeaderboardPageProps({ nextScope: "global" })}
          preserveScroll
        >
          <Twemoji emoji="🌐" alt="Globe" class="inline-block w-5 h-5" />
          <span class="hidden sm:inline">Global</span>
        </Link>

        {#if country.available}
          <Link
            href={`/leaderboards?period_type=${period_type}&scope=country`}
            class={`${tabClass(scope === "country")} inline-flex items-center justify-center gap-2`}
            component="Leaderboards/Index"
            pageProps={instantLeaderboardPageProps({ nextScope: "country" })}
            preserveScroll
          >
            <CountryFlag
              countryCode={country.code}
              class="inline-block w-5 h-5"
            />
            <span class="hidden sm:inline max-w-48 truncate"
              >{country.name}</span
            >
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

      <!-- Period tabs -->
      <div class="inline-flex rounded-full bg-darkless p-1 gap-1">
        <Link
          href={`/leaderboards?period_type=daily&scope=${scope}`}
          class={tabClass(period_type === "daily")}
          component="Leaderboards/Index"
          pageProps={instantLeaderboardPageProps({ nextPeriodType: "daily" })}
          preserveScroll
        >
          <span class="sm:hidden">24h</span>
          <span class="hidden sm:inline">Last 24 Hours</span>
        </Link>
        <Link
          href={`/leaderboards?period_type=last_7_days&scope=${scope}`}
          class={tabClass(period_type === "last_7_days")}
          component="Leaderboards/Index"
          pageProps={instantLeaderboardPageProps({
            nextPeriodType: "last_7_days",
          })}
          preserveScroll
        >
          <span class="sm:hidden">7d</span>
          <span class="hidden sm:inline">Last 7 Days</span>
        </Link>
      </div>
    </div>

    {#if is_logged_in && !country.available}
      <p class="text-xs text-muted">
        Set your country in
        <Link
          href={settings_path}
          class="text-accent hover:text-cyan transition-colors">settings</Link
        >
        to unlock regional leaderboards.
      </p>
    {/if}

    {#if github_uid_blank}
      <div
        class="bg-darker border border-primary rounded-lg p-4 flex flex-col sm:flex-row sm:items-center gap-3"
      >
        <span class="text-surface-content"
          >Connect your GitHub to qualify for the leaderboard.</span
        >
        <Button href={github_auth_path} native size="md">Connect GitHub</Button>
      </div>
    {/if}

    <div class="text-muted text-sm flex flex-wrap items-center gap-x-2 gap-y-1">
      {dateRangeText}
      {#if leaderboard?.finished_generating && leaderboard?.updated_at}
        <span class="italic">• Updated {timeAgo(leaderboard.updated_at)}.</span>
      {/if}
    </div>
  </div>

  <div class="bg-elevated rounded-xl border border-primary overflow-hidden">
    {#if leaderboard}
      <Deferred data="entries">
        {#snippet fallback()}
          <div class="divide-y divide-gray-800">
            {#each Array(20) as _}
              <div class="flex items-center p-2 animate-pulse">
                <div class="w-12 h-6 bg-darkless rounded shrink-0"></div>
                <div class="w-8 h-8 bg-darkless rounded-full mx-4"></div>
                <div class="flex-1">
                  <div class="h-4 w-32 bg-darkless rounded"></div>
                </div>
                <div class="h-4 w-16 bg-darkless rounded shrink-0"></div>
              </div>
            {/each}
          </div>
        {/snippet}

        {#snippet children()}
          {#if entries && entries.total > 0}
            <div class="divide-y divide-gray-800">
              {#each entries.entries as entry, i}
                {@const theme = streakTheme(entry.streak_count)}
                <div
                  class="flex items-center p-2 sm:p-3 hover:bg-dark transition-colors duration-200 gap-2 sm:gap-0 {entry.is_current_user
                    ? 'bg-dark border-l-4 border-l-primary'
                    : ''} {entry.user.red ? 'opacity-40 hover:opacity-60' : ''}"
                >
                  <!-- Rank -->
                  <div
                    class="w-8 sm:w-12 shrink-0 text-center font-medium text-muted"
                  >
                    {#if i <= 2}
                      <span class="text-xl sm:text-2xl">{rankDisplay(i)}</span>
                    {:else}
                      <span class="text-base sm:text-lg">{i + 1}</span>
                    {/if}
                  </div>

                  <!-- User info -->
                  <div class="flex-1 mx-1 sm:mx-4 min-w-0">
                    <div class="flex items-center gap-2">
                      <div class="user-info flex items-center gap-2 min-w-0">
                        {#if entry.user.avatar_url}
                          <img
                            src={entry.user.avatar_url}
                            alt="{entry.user.display_name}'s avatar"
                            class="w-8 h-8 rounded-full aspect-square border border-surface-200 shrink-0"
                            loading="lazy"
                          />
                        {/if}
                        <span class="inline-flex items-center gap-1 min-w-0">
                          {#if entry.user.profile_path}
                            <Link
                              href={entry.user.profile_path}
                              class="text-blue hover:underline truncate"
                            >
                              {entry.user.display_name}
                            </Link>
                          {:else}
                            <span class="truncate"
                              >{entry.user.display_name}</span
                            >
                          {/if}
                        </span>
                        {#if entry.user.country_code}
                          <CountryFlag
                            countryCode={entry.user.country_code}
                            class="inline-block w-5 h-5 align-middle shrink-0"
                          />
                        {/if}
                      </div>

                      {#if entry.streak_count > 0}
                        <div
                          class="inline-flex items-center gap-1 px-2 py-1 bg-linear-to-r {theme.bg} border {theme.bc} rounded-lg transition-all duration-200 {theme.hbg} group shrink-0"
                          title={entry.streak_count > 30
                            ? "30+ daily streak"
                            : `${entry.streak_count} day streak`}
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            width="16"
                            height="16"
                            viewBox="0 0 24 24"
                            class="{theme.ic} transition-colors duration-200 group-hover:animate-pulse"
                          >
                            <path
                              fill="currentColor"
                              d="M10 2c0-.88 1.056-1.331 1.692-.722c1.958 1.876 3.096 5.995 1.75 9.12l-.08.174l.012.003c.625.133 1.203-.43 2.303-2.173l.14-.224a1 1 0 0 1 1.582-.153C18.733 9.46 20 12.402 20 14.295C20 18.56 16.409 22 12 22s-8-3.44-8-7.706c0-2.252 1.022-4.716 2.632-6.301l.605-.589c.241-.236.434-.43.618-.624C9.285 5.268 10 3.856 10 2"
                            />
                          </svg>
                          <span
                            class="text-md font-semibold {theme.tc} transition-colors duration-200"
                          >
                            {streakLabel(entry.streak_count)}
                          </span>
                        </div>
                      {/if}
                    </div>
                    {#if entry.active_project}
                      <div
                        class="text-xs italic text-muted truncate mt-0.5 ml-10"
                      >
                        working on
                        <a
                          href={entry.active_project.repo_url}
                          target="_blank"
                          class="text-accent hover:text-cyan transition-colors"
                        >
                          {entry.active_project.name}
                        </a>
                      </div>
                    {/if}
                  </div>

                  <!-- Duration -->
                  <div
                    class="shrink-0 font-mono text-xs sm:text-sm text-surface-content font-medium whitespace-nowrap"
                  >
                    {secondsToDetailedDisplay(entry.total_seconds)}
                  </div>
                </div>
              {/each}
            </div>

            {#if leaderboard?.finished_generating && leaderboard?.generation_duration_seconds != null}
              <div
                class="px-4 py-2 text-xs italic text-muted border-t border-primary"
              >
                Generated in {leaderboard.generation_duration_seconds} seconds
              </div>
            {/if}
          {:else}
            <div class="py-16 text-center px-3">
              <h3 class="text-xl font-medium text-surface-content mb-2">
                No data available
              </h3>
              <p class="text-muted">
                Check back later for {period_type === "last_7_days"
                  ? "last 7 days"
                  : "last 24 hours"} results!
              </p>
            </div>
          {/if}
        {/snippet}
      </Deferred>
    {:else}
      <div class="py-16 text-center px-3">
        <h3 class="text-xl font-medium text-surface-content mb-2">
          Leaderboard is being generated...
        </h3>
        <p class="text-muted">
          Check back in a moment for {scope === "country" && country.name
            ? `${country.name} `
            : ""}{period_type === "last_7_days"
            ? "last 7 days"
            : "last 24 hours"} results!
        </p>
      </div>
    {/if}
  </div>
</div>
