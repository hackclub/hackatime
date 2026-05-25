<script lang="ts">
  import { Deferred, router } from "@inertiajs/svelte";
  import type {
    ActivityGraphData,
    FilterableDashboardData,
    TodayStats,
    ProgrammingGoalProgress,
  } from "../../types/index";
  import BanNotice from "./signedIn/BanNotice.svelte";
  import GitHubLinkBanner from "./signedIn/GitHubLinkBanner.svelte";
  import SetupNotice from "./signedIn/SetupNotice.svelte";
  import TodaySentence from "./signedIn/TodaySentence.svelte";
  import TodaySentenceSkeleton from "./signedIn/TodaySentenceSkeleton.svelte";
  import Dashboard from "./signedIn/Dashboard.svelte";
  import DashboardSkeleton from "./signedIn/DashboardSkeleton.svelte";
  import ActivityGraph from "./signedIn/ActivityGraph.svelte";
  import ActivityGraphSkeleton from "./signedIn/ActivityGraphSkeleton.svelte";

  let {
    flavor_text,
    trust_level_red,
    show_wakatime_setup_notice,
    github_uid_blank,
    dashboard_stats,
  }: {
    flavor_text: string;
    trust_level_red: boolean;
    show_wakatime_setup_notice: boolean;
    github_uid_blank: boolean;
    dashboard_stats?: {
      filterable_dashboard_data: FilterableDashboardData;
      activity_graph: ActivityGraphData;
      today_stats: TodayStats;
      programming_goals_progress: ProgrammingGoalProgress[];
    };
  } = $props();

  function refreshDashboardData(search: string) {
    router.visit(`${window.location.pathname}${search}`, {
      only: ["dashboard_stats"],
      preserveState: true,
      preserveScroll: true,
      replace: true,
      async: true,
    });
  }
</script>

<svelte:head>
  <title>Dashboard - Hackatime</title>
</svelte:head>

<div>
  <div class="mb-6 sm:mb-8">
    <p class="italic text-sm sm:text-base text-muted m-0">
      {@html flavor_text}
    </p>
    <h1
      class="font-bold mt-1 sm:mt-2 mb-3 sm:mb-4 text-2xl sm:text-3xl md:text-4xl"
    >
      Keep Track of <span class="text-primary">Your</span> Coding Time
    </h1>
  </div>

  {#if trust_level_red}<BanNotice />{/if}

  {#if show_wakatime_setup_notice}
    <SetupNotice />
  {:else if github_uid_blank}
    <GitHubLinkBanner />
  {/if}

  <Deferred data="dashboard_stats">
    {#snippet fallback()}
      <div class="flex flex-col gap-8">
        <TodaySentenceSkeleton />
        <DashboardSkeleton />
        <ActivityGraphSkeleton />
      </div>
    {/snippet}

    {#snippet children({ reloading })}
      <div class="flex flex-col gap-8" class:opacity-60={reloading}>
        {#if dashboard_stats?.today_stats}
          {@const t = dashboard_stats.today_stats}
          <TodaySentence
            show_logged_time_sentence={t.show_logged_time_sentence}
            todays_duration_display={t.todays_duration_display}
            todays_languages={t.todays_languages}
            todays_editors={t.todays_editors}
          />
        {/if}

        {#if dashboard_stats?.filterable_dashboard_data}
          <Dashboard
            data={dashboard_stats.filterable_dashboard_data}
            programmingGoalsProgress={dashboard_stats?.programming_goals_progress ||
              []}
            onFiltersChange={refreshDashboardData}
          />
        {/if}

        {#if dashboard_stats?.activity_graph}
          <ActivityGraph data={dashboard_stats.activity_graph} />
        {/if}
      </div>
    {/snippet}
  </Deferred>
</div>
