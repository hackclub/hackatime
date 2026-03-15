<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import ProjectStatsContent from "./ProjectStatsContent.svelte";
  import type { PublicProjectShowProps } from "../../types/index";

  let {
    page_title,
    project_name,
    username,
    profile_path,
    since_date,
    repo_url,
    total_time_label,
    file_count,
    language_stats,
    language_colors,
    file_stats,
    branch_stats,
  }: PublicProjectShowProps = $props();
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <div class="mb-6">
    <Link
      href={profile_path}
      class="text-sm text-muted transition-colors hover:text-primary"
    >
      ← @{username}'s profile
    </Link>
    <h1 class="mt-1 text-3xl font-bold text-surface-content">
      {project_name}
    </h1>
    {#if since_date}
      <p class="mt-1 text-sm text-muted">
        {total_time_label} · Since {since_date}
      </p>
    {/if}
  </div>

  <ProjectStatsContent
    {total_time_label}
    {file_count}
    {language_stats}
    {language_colors}
    {file_stats}
    {branch_stats}
  />

  {#if repo_url}
    <div class="mt-6 text-center">
      <Button href={repo_url} native variant="surface" size="sm">
        View Repository
      </Button>
    </div>
  {/if}
</div>
