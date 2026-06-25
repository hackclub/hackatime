<script lang="ts">
  import { secondsToDisplay } from "./utils";
  import StatCard from "./StatCard.svelte";
  import HorizontalBarList from "./HorizontalBarList.svelte";
  import PieChart from "./PieChart.svelte";
  import ProjectTimelineChart from "./ProjectTimelineChart.svelte";
  import IntervalSelect from "./IntervalSelect.svelte";
  import MultiSelect from "./MultiSelect.svelte";
  import GoalsProgressCard from "./GoalsProgressCard.svelte";
  import type { ProgrammingGoalProgress } from "../../../types/index";

  let {
    data,
    programmingGoalsProgress = [],
    onFiltersChange,
    showFilters = true,
    showGoals = true,
  }: {
    data: Record<string, any>;
    programmingGoalsProgress?: ProgrammingGoalProgress[];
    onFiltersChange?: (search: string) => void;
    showFilters?: boolean;
    showGoals?: boolean;
  } = $props();

  const dict = (k: string) => (data[k] || {}) as Record<string, number>;
  const langStats = $derived(dict("language_stats"));
  const editorStats = $derived(dict("editor_stats"));
  const osStats = $derived(dict("operating_system_stats"));
  const projectEntries = $derived(
    Object.entries(data.project_durations || {}) as [string, number][],
  );
  const weeklyStats = $derived(
    (data.weekly_project_stats || {}) as Record<string, Record<string, number>>,
  );

  const capitalize = (s: string) =>
    s ? s.charAt(0).toUpperCase() + s.slice(1) : "";

  function applyFilters(overrides: Record<string, string>) {
    const current = new URL(window.location.href);
    for (const [k, v] of Object.entries(overrides)) {
      if (v) current.searchParams.set(k, v);
      else current.searchParams.delete(k);
    }
    onFiltersChange?.(current.search);
  }

  const onIntervalChange = (interval: string, from: string, to: string) =>
    from || to
      ? applyFilters({ interval: "custom", from, to })
      : applyFilters({ interval, from: "", to: "" });

  const onFilterChange = (param: string, selected: string[]) =>
    applyFilters({ [param]: selected.join(",") });

  const FILTERS = [
    { label: "Project", param: "project" },
    { label: "Language", param: "language" },
    { label: "OS", param: "operating_system" },
    { label: "Editor", param: "editor" },
    { label: "Category", param: "category" },
  ] as const;

  const STAT_KEYS = [
    ["Top Project", "top_project", "singular_project", "None"],
    ["Top Language", "top_language", "singular_language", "Unknown"],
    ["Top OS", "top_operating_system", "singular_operating_system", "Unknown"],
    ["Top Editor", "top_editor", "singular_editor", "Unknown"],
    ["Top Category", "top_category", "singular_category", "Unknown"],
  ] as const;
</script>

<div class="flex w-full min-w-0 flex-col gap-6">
  {#if showFilters}
    <div
      class="mb-2 grid min-w-0 grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6"
    >
      <IntervalSelect
        selected={data.selected_interval || ""}
        from={data.selected_from || ""}
        to={data.selected_to || ""}
        onchange={onIntervalChange}
      />
      {#each FILTERS as { label, param }}
        <MultiSelect
          {label}
          values={data[param] || []}
          selected={data[`selected_${param}`] || []}
          onchange={(s) => onFilterChange(param, s)}
        />
      {/each}
    </div>
  {/if}

  {#if showGoals}
    <GoalsProgressCard goals={programmingGoalsProgress} />
  {/if}

  <div class="grid min-w-0 grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
    <StatCard
      label="Total Time"
      value={secondsToDisplay(data.total_time)}
      highlight
    />
    {#each STAT_KEYS as [label, valueKey, singularKey, fallback]}
      <StatCard
        {label}
        value={(valueKey === "top_category" && data[valueKey] === "ai coding"
          ? "AI Coding"
          : valueKey === "top_category"
            ? capitalize(data[valueKey])
            : data[valueKey]) || fallback}
        subtitle={data[singularKey] ? "obviously" : ""}
      />
    {/each}
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 w-full">
    {#if projectEntries.length > 1}
      <div class="lg:col-span-1">
        <HorizontalBarList
          title="Project Durations"
          entries={projectEntries}
          empty_message="No data yet."
          useLogScale
        />
      </div>
    {/if}

    {#if Object.keys(langStats).length > 0}
      <PieChart
        title="Languages"
        stats={langStats}
        colorMap={data.language_colors || {}}
      />
    {/if}

    {#if Object.keys(editorStats).length > 0}
      <PieChart title="Editors" stats={editorStats} />
    {/if}

    {#if Object.keys(osStats).length > 0}
      <PieChart title="Operating Systems" stats={osStats} />
    {/if}

    <div class="lg:col-span-2">
      <ProjectTimelineChart {weeklyStats} />
    </div>
  </div>
</div>
