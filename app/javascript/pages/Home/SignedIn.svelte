<script lang="ts">
  import { Deferred, router } from "@inertiajs/svelte";
  import type { ActivityGraphData } from "../../types/index";
  import BanNotice from "./signedIn/BanNotice.svelte";
  import GitHubLinkBanner from "./signedIn/GitHubLinkBanner.svelte";
  import SetupNotice from "./signedIn/SetupNotice.svelte";
  import TodaySentence from "./signedIn/TodaySentence.svelte";
  import TodaySentenceSkeleton from "./signedIn/TodaySentenceSkeleton.svelte";
  import Dashboard from "./signedIn/Dashboard.svelte";
  import DashboardSkeleton from "./signedIn/DashboardSkeleton.svelte";
  import ActivityGraph from "./signedIn/ActivityGraph.svelte";
  import ActivityGraphSkeleton from "./signedIn/ActivityGraphSkeleton.svelte";

  type SocialProofUser = { display_name: string; avatar_url: string };

  type FilterableDashboardData = {
    total_time: number;
    total_heartbeats: number;
    top_project: string | null;
    top_language: string | null;
    top_editor: string | null;
    top_operating_system: string | null;
    project_durations: Record<string, number>;
    language_stats: Record<string, number>;
    editor_stats: Record<string, number>;
    operating_system_stats: Record<string, number>;
    category_stats: Record<string, number>;
    weekly_project_stats: Record<string, Record<string, number>>;
    project: string[];
    language: string[];
    editor: string[];
    operating_system: string[];
    category: string[];
    selected_interval: string;
    selected_from: string;
    selected_to: string;
    selected_project: string[];
    selected_language: string[];
    selected_editor: string[];
    selected_operating_system: string[];
    selected_category: string[];
  };

  type TodayStats = {
    show_logged_time_sentence: boolean;
    todays_duration_display: string;
    todays_languages: string[];
    todays_editors: string[];
  };

  type ProgrammingGoalProgress = {
    id: string;
    period: "day" | "week" | "month";
    target_seconds: number;
    tracked_seconds: number;
    completion_percent: number;
    complete: boolean;
    languages: string[];
    projects: string[];
  };

  let {
    flavor_text,
    trust_level_red,
    show_wakatime_setup_notice,
    ssp_message,
    ssp_users_recent,
    ssp_users_size,
    github_uid_blank,
    github_auth_path,
    wakatime_setup_path,
    dashboard_stats,
  }: {
    flavor_text: string;
    trust_level_red: boolean;
    show_wakatime_setup_notice: boolean;
    ssp_message?: string | null;
    ssp_users_recent: SocialProofUser[];
    ssp_users_size: number;
    github_uid_blank: boolean;
    github_auth_path: string;
    wakatime_setup_path: string;
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

<div>
  <!-- Header Section -->
  <div class="mb-8">
    <div class="flex items-center space-x-2">
      <p class="italic text-muted m-0">
        {@html flavor_text}
      </p>
    </div>

    <h1 class="font-bold mt-2 mb-4 text-3xl md:text-4xl">
      Keep Track of <span class="text-primary">Your</span> Coding Time
    </h1>
  </div>

  {#if trust_level_red}
    <BanNotice />
  {/if}

  {#if show_wakatime_setup_notice}
    <SetupNotice
      {wakatime_setup_path}
      {ssp_message}
      {ssp_users_recent}
      {ssp_users_size}
    />
  {/if}

  {#if github_uid_blank}
    <GitHubLinkBanner {github_auth_path} />
  {/if}

  <Deferred data="dashboard_stats">
    {#snippet fallback()}
      <div class="flex flex-col gap-8">
        <div>
          <TodaySentenceSkeleton />
        </div>
        <DashboardSkeleton />
        <ActivityGraphSkeleton />
      </div>
    {/snippet}

    {#snippet children({ reloading })}
      <div class="flex flex-col gap-8" class:opacity-60={reloading}>
        <!-- Today Stats -->
        <div>
          {#if dashboard_stats?.today_stats}
            <TodaySentence
              show_logged_time_sentence={dashboard_stats.today_stats
                .show_logged_time_sentence}
              todays_duration_display={dashboard_stats.today_stats
                .todays_duration_display}
              todays_languages={dashboard_stats.today_stats.todays_languages}
              todays_editors={dashboard_stats.today_stats.todays_editors}
            />
          {/if}
        </div>

        <!-- Main Dashboard -->
        {#if dashboard_stats?.filterable_dashboard_data}
          <Dashboard
            data={dashboard_stats.filterable_dashboard_data}
            programmingGoalsProgress={dashboard_stats.programming_goals_progress ||
              []}
            onFiltersChange={refreshDashboardData}
          />
        {/if}

        <!-- Activity Graph -->
        {#if dashboard_stats?.activity_graph}
          <ActivityGraph data={dashboard_stats.activity_graph} />
        {/if}
      </div>
    {/snippet}
  </Deferred>
</div>
