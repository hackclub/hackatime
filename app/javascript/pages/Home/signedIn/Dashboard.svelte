<script lang="ts">
  import { secondsToDisplay } from "./utils";
  import StatCard from "./StatCard.svelte";
  import HorizontalBarList from "./HorizontalBarList.svelte";
  import ProjectTimeline from "./ProjectTimeline.svelte";

  let {
    data,
  }: {
    data: Record<string, any>;
  } = $props();

  const langEntries = $derived(
    Object.entries(data.language_stats || {}) as [string, number][],
  );
  const editorEntries = $derived(
    Object.entries(data.editor_stats || {}) as [string, number][],
  );
  const osEntries = $derived(
    Object.entries(data.operating_system_stats || {}) as [string, number][],
  );
  const projectEntries = $derived(
    Object.entries(data.project_durations || {}) as [string, number][],
  );
  const timelineEntries = $derived(
    Object.entries(data.weekly_project_stats || {}) as [
      string,
      Record<string, number>,
    ][],
  );
</script>

<div class="flex flex-col gap-6 w-full">
  <div
    class="grid grid-cols-[repeat(auto-fill,minmax(9.375rem,1fr))] gap-4"
  >
    <StatCard
      label="Total Time"
      value={secondsToDisplay(data.total_time)}
      large
    />
    <StatCard label="Top Project" value={data.top_project} />
    <StatCard label="Top Language" value={data.top_language} />
    <StatCard label="Top Editor" value={data.top_editor} />
    <StatCard label="Top OS" value={data.top_operating_system} />
    <StatCard label="Heartbeats" value={data.total_heartbeats || 0} large />
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
    <HorizontalBarList
      title="Project Durations"
      entries={projectEntries}
      empty_message="No data yet."
    />
    <HorizontalBarList
      title="Languages"
      entries={langEntries}
      empty_message="No language data."
    />
    <HorizontalBarList
      title="Editors"
      entries={editorEntries}
      empty_message="No editor data."
    />
    <HorizontalBarList
      title="Operating Systems"
      entries={osEntries}
      empty_message="No OS data."
    />
    <ProjectTimeline entries={timelineEntries} />
  </div>
</div>
