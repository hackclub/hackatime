<script lang="ts">
  import { Deferred, router } from "@inertiajs/svelte";
  import type { Component } from "svelte";
  import type {
    ActivityGraphData,
    FilterableDashboardData,
    TodayStats,
    ProgrammingGoalProgress,
  } from "../../types/index";
  import BanNotice from "./signedIn/BanNotice.svelte";
  import GitHubLinkBanner from "./signedIn/GitHubLinkBanner.svelte";
  import SetupNotice from "./signedIn/SetupNotice.svelte";
  import TodaySentenceSkeleton from "./signedIn/TodaySentenceSkeleton.svelte";
  import DashboardSkeleton from "./signedIn/DashboardSkeleton.svelte";
  import ActivityGraphSkeleton from "./signedIn/ActivityGraphSkeleton.svelte";

  type DashboardStats = {
    filterable_dashboard_data: FilterableDashboardData;
    activity_graph: ActivityGraphData;
    today_stats: TodayStats;
    programming_goals_progress: ProgrammingGoalProgress[];
  };

  type DashboardContentProps = {
    dashboardStats: DashboardStats;
    reloading: boolean;
    onFiltersChange: (search: string) => void;
  };

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
    dashboard_stats?: DashboardStats;
  } = $props();

  let DashboardContent = $state<Component<DashboardContentProps> | null>(null);
  let loadingDashboardContent = false;

  $effect(() => {
    if (!dashboard_stats || DashboardContent || loadingDashboardContent) return;

    loadingDashboardContent = true;
    import("./signedIn/DashboardContent.svelte").then((module) => {
      DashboardContent = module.default;
    });
  });

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

{#snippet dashboardSkeleton()}
  <div class="flex flex-col gap-8">
    <TodaySentenceSkeleton />
    <DashboardSkeleton />
    <ActivityGraphSkeleton />
  </div>
{/snippet}

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
      {@render dashboardSkeleton()}
    {/snippet}

    {#snippet children({ reloading })}
      {#if DashboardContent && dashboard_stats}
        <DashboardContent
          dashboardStats={dashboard_stats}
          {reloading}
          onFiltersChange={refreshDashboardData}
        />
      {:else}
        {@render dashboardSkeleton()}
      {/if}
    {/snippet}
  </Deferred>
</div>
