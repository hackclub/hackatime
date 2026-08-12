<script lang="ts">
  import Share from "hcicons-svelte/share";
  import Button from "../../components/Button.svelte";
  import IntervalSelect from "../Home/signedIn/IntervalSelect.svelte";
  import ProjectStatsContent from "./ProjectStatsContent.svelte";
  import ProjectHeader from "./components/ProjectHeader.svelte";
  import ShareModal from "./components/ShareModal.svelte";
  import type { ProjectShowProps } from "../../types/index";
  import { myProjectRepoMappings } from "../../api";
  import { buildIntervalChange, visitWithInterval } from "./intervalNav";

  let {
    page_title,
    project_name,
    since_date,
    repo_url,
    is_shared,
    share_url,
    interval = "",
    from = "",
    to = "",
    project_stats,
  }: ProjectShowProps = $props();

  let shareModalOpen = $state(false);

  const changeInterval = (
    nextInterval: string,
    nextFrom: string,
    nextTo: string,
  ) => {
    visitWithInterval(
      window.location.pathname,
      buildIntervalChange(nextInterval, nextFrom, nextTo),
      ["project_stats", "interval", "from", "to"],
    );
  };
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <ProjectHeader
    backHref={myProjectRepoMappings.index.path()}
    backLabel="← Back to Projects"
    projectName={project_name}
    subtitle={since_date ? `Since ${since_date}` : null}
  >
    {#snippet actions()}
      {#if repo_url}
        <Button href={repo_url} native variant="surface" size="sm">
          Repository
        </Button>
      {/if}
      <Button
        type="button"
        variant="surface"
        size="sm"
        onclick={() => (shareModalOpen = true)}
      >
        <Share size={16} class="mr-1.5" />
        Share
      </Button>
    {/snippet}
  </ProjectHeader>

  <div class="mb-6 sm:max-w-3xs">
    <IntervalSelect
      from={from || ""}
      selected={interval || ""}
      to={to || ""}
      onchange={changeInterval}
    />
  </div>

  <ProjectStatsContent {...project_stats} />
</div>

<ShareModal
  bind:open={shareModalOpen}
  projectName={project_name}
  isShared={is_shared}
  shareUrl={share_url}
/>
