<script lang="ts">
  import StatCard from "$lib/components/StatCard.svelte";
  import { duration } from "$lib/format";

  let { data } = $props();
</script>

<svelte:head><title>{data.username} on Hackatime</title></svelte:head>

<section class="profile panel">
  <p class="eyebrow">Public profile</p>
  <h1>@{data.username}</h1>
  <div class="stats-grid">
    <StatCard label="Tracked time" value={duration(data.totalSeconds)} />
    <StatCard label="Projects" value={String(data.projects.length)} />
  </div>
  <div class="project-list">
    <h2>Projects</h2>
    <div class="chips">
      {#each data.projects as project}<span>{project}</span>{/each}
    </div>
  </div>
</section>
