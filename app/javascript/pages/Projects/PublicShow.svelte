<script lang="ts">
  import Button from "../../components/Button.svelte";
  import ProjectStatsContent from "./ProjectStatsContent.svelte";
  import ProjectHeader from "./components/ProjectHeader.svelte";
  import type { PublicProjectShowProps } from "../../types/index";
  import { profiles } from "../../api";

  let {
    page_title,
    project_name,
    username,
    since_date,
    repo_url,
    total_time_label,
    file_count,
    language_stats,
    language_colors,
    file_stats,
    branch_stats,
  }: PublicProjectShowProps = $props();

  const subtitle = $derived(
    since_date ? `${total_time_label} · Since ${since_date}` : null,
  );
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <ProjectHeader
    backHref={profiles.show.path({ username })}
    backLabel={`← @${username}'s profile`}
    projectName={project_name}
    {subtitle}
  />

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
