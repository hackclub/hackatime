<script lang="ts">
  import StatCard from "../Home/signedIn/StatCard.svelte";
  import HorizontalBarList from "../Home/signedIn/HorizontalBarList.svelte";
  import PieChart from "../Home/signedIn/PieChart.svelte";
  import ActivityGraph from "../Home/signedIn/ActivityGraph.svelte";
  import FileList from "./FileList.svelte";
  import type { ActivityGraphData } from "../../types/index";

  let {
    total_time_label,
    language_count,
    branch_count,
    file_count,
    language_stats = {},
    language_colors = {},
    editor_stats,
    os_stats,
    category_stats,
    file_stats = [],
    branch_stats = [],
    activity_graph,
  }: {
    total_time_label: string;
    language_count: number;
    branch_count: number;
    file_count: number;
    language_stats: Record<string, number>;
    language_colors: Record<string, string>;
    editor_stats?: Record<string, number>;
    os_stats?: Record<string, number>;
    category_stats?: Record<string, number>;
    file_stats: [string, number][];
    branch_stats: [string, number][];
    activity_graph?: ActivityGraphData | null;
  } = $props();
</script>

<div class="space-y-6">
  <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
    <StatCard label="Total Time" value={total_time_label} highlight />
    <StatCard label="Languages" value={String(language_count)} />
    <StatCard label="Branches" value={String(branch_count)} />
    <StatCard label="Files" value={String(file_count)} />
  </div>

  {#if file_stats.length > 0}
    <FileList entries={file_stats} totalFileCount={file_count} />
  {/if}

  <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
    {#if Object.keys(language_stats).length > 0}
      <PieChart
        title="Languages"
        stats={language_stats}
        colorMap={language_colors}
      />
    {/if}

    {#if editor_stats && Object.keys(editor_stats).length > 0}
      <PieChart title="Editors" stats={editor_stats} />
    {/if}

    {#if os_stats && Object.keys(os_stats).length > 0}
      <PieChart title="Operating Systems" stats={os_stats} />
    {/if}

    {#if category_stats && Object.keys(category_stats).length > 0}
      <PieChart title="Categories" stats={category_stats} />
    {/if}
  </div>

  {#if branch_stats.length > 0}
    <HorizontalBarList
      title="Branches"
      entries={branch_stats}
      empty_message="No branch data yet."
    />
  {/if}

  {#if activity_graph}
    <div class="rounded-xl border border-surface-200 bg-surface p-6">
      <h2 class="text-xl font-semibold text-surface-content">
        Development Activity
      </h2>
      <ActivityGraph data={activity_graph} />
    </div>
  {/if}
</div>
