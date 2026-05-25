<script lang="ts">
  import type {
    ActivityGraphData,
    FilterableDashboardData,
    TodayStats,
    ProgrammingGoalProgress,
  } from "../../../types/index";
  import TodaySentence from "./TodaySentence.svelte";
  import Dashboard from "./Dashboard.svelte";
  import ActivityGraph from "./ActivityGraph.svelte";

  let {
    dashboardStats,
    reloading,
    onFiltersChange,
  }: {
    dashboardStats: {
      filterable_dashboard_data: FilterableDashboardData;
      activity_graph: ActivityGraphData;
      today_stats: TodayStats;
      programming_goals_progress: ProgrammingGoalProgress[];
    };
    reloading: boolean;
    onFiltersChange: (search: string) => void;
  } = $props();
</script>

<div class="flex flex-col gap-8" class:opacity-60={reloading}>
  {#if dashboardStats.today_stats}
    {@const t = dashboardStats.today_stats}
    <TodaySentence
      show_logged_time_sentence={t.show_logged_time_sentence}
      todays_duration_display={t.todays_duration_display}
      todays_languages={t.todays_languages}
      todays_editors={t.todays_editors}
    />
  {/if}

  {#if dashboardStats.filterable_dashboard_data}
    <Dashboard
      data={dashboardStats.filterable_dashboard_data}
      programmingGoalsProgress={dashboardStats.programming_goals_progress || []}
      {onFiltersChange}
    />
  {/if}

  {#if dashboardStats.activity_graph}
    <ActivityGraph data={dashboardStats.activity_graph} />
  {/if}
</div>
