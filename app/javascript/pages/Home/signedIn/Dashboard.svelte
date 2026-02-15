<script lang="ts">
  import { secondsToDisplay } from "./utils";
  import StatCard from "./StatCard.svelte";
  import HorizontalBarList from "./HorizontalBarList.svelte";
  import PieChart from "./PieChart.svelte";
  import ProjectTimelineChart from "./ProjectTimelineChart.svelte";
  import IntervalSelect from "./IntervalSelect.svelte";
  import MultiSelect from "./MultiSelect.svelte";

  let {
    data,
    onFiltersChange,
  }: {
    data: Record<string, any>;
    onFiltersChange?: (search: string) => Promise<void> | void;
  } = $props();

  let loading = $state(false);

  const langStats = $derived(
    (data.language_stats || {}) as Record<string, number>,
  );
  const editorStats = $derived(
    (data.editor_stats || {}) as Record<string, number>,
  );
  const osStats = $derived(
    (data.operating_system_stats || {}) as Record<string, number>,
  );
  const projectEntries = $derived(
    Object.entries(data.project_durations || {}) as [string, number][],
  );
  const weeklyStats = $derived(
    (data.weekly_project_stats || {}) as Record<string, Record<string, number>>,
  );

  const capitalize = (s: string) =>
    s ? s.charAt(0).toUpperCase() + s.slice(1) : "";

  async function applyFilters(overrides: Record<string, string>) {
    const current = new URL(window.location.href);
    for (const [k, v] of Object.entries(overrides)) {
      if (v) {
        current.searchParams.set(k, v);
      } else {
        current.searchParams.delete(k);
      }
    }

    window.history.pushState({}, "", current.pathname + current.search);

    loading = true;
    try {
      await onFiltersChange?.(current.search);
    } finally {
      loading = false;
    }
  }

  function onIntervalChange(interval: string, from: string, to: string) {
    if (from || to) {
      void applyFilters({ interval: "custom", from, to });
    } else {
      void applyFilters({ interval, from: "", to: "" });
    }
  }

  function onFilterChange(param: string, selected: string[]) {
    void applyFilters({ [param]: selected.join(",") });
  }
</script>

<div class="flex flex-col gap-6 w-full" class:opacity-60={loading}>
  <!-- Filters -->
  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-2">
    <IntervalSelect
      selected={data.selected_interval || ""}
      from={data.selected_from || ""}
      to={data.selected_to || ""}
      onchange={onIntervalChange}
    />
    <MultiSelect
      label="Project"
      param="project"
      values={data.project || []}
      selected={data.selected_project || []}
      onchange={(s) => onFilterChange("project", s)}
    />
    <MultiSelect
      label="Language"
      param="language"
      values={data.language || []}
      selected={data.selected_language || []}
      onchange={(s) => onFilterChange("language", s)}
    />
    <MultiSelect
      label="OS"
      param="operating_system"
      values={data.operating_system || []}
      selected={data.selected_operating_system || []}
      onchange={(s) => onFilterChange("operating_system", s)}
    />
    <MultiSelect
      label="Editor"
      param="editor"
      values={data.editor || []}
      selected={data.selected_editor || []}
      onchange={(s) => onFilterChange("editor", s)}
    />
    <MultiSelect
      label="Category"
      param="category"
      values={data.category || []}
      selected={data.selected_category || []}
      onchange={(s) => onFilterChange("category", s)}
    />
  </div>

  <!-- Stats Grid -->
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
    <StatCard
      label="Total Time"
      value={secondsToDisplay(data.total_time)}
      highlight
    />
    <StatCard
      label="Top Project"
      value={data.top_project || "None"}
      subtitle={data.singular_project ? "obviously" : ""}
    />
    <StatCard
      label="Top Language"
      value={data.top_language || "Unknown"}
      subtitle={data.singular_language ? "obviously" : ""}
    />
    <StatCard
      label="Top OS"
      value={data.top_operating_system || "Unknown"}
      subtitle={data.singular_operating_system ? "obviously" : ""}
    />
    <StatCard
      label="Top Editor"
      value={data.top_editor || "Unknown"}
      subtitle={data.singular_editor ? "obviously" : ""}
    />
    <StatCard
      label="Top Category"
      value={capitalize(data.top_category) || "Unknown"}
      subtitle={data.singular_category ? "obviously" : ""}
    />
  </div>

  <!-- Charts Layout -->
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
      <PieChart title="Languages" stats={langStats} />
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
