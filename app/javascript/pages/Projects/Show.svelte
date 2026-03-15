<script lang="ts">
  import { Link, Deferred, router } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import IntervalSelect from "../Home/signedIn/IntervalSelect.svelte";
  import ProjectStatsContent from "./ProjectStatsContent.svelte";
  import type { ProjectShowProps } from "../../types/index";

  let {
    page_title,
    project_name,
    back_path,
    since_date,
    repo_url,
    is_shared,
    share_url,
    toggle_share_path,
    interval = "",
    from = "",
    to = "",
    project_stats,
  }: ProjectShowProps = $props();

  let shareModalOpen = $state(false);
  let copied = $state(false);
  let toggling = $state(false);

  const changeInterval = (
    nextInterval: string,
    nextFrom: string,
    nextTo: string,
  ) => {
    const isCustom = Boolean(nextFrom || nextTo);
    const query = new URLSearchParams();
    if (isCustom) {
      query.set("interval", "custom");
      query.set("from", nextFrom);
      query.set("to", nextTo);
    } else if (nextInterval) {
      query.set("interval", nextInterval);
    }
    const qs = query.toString();
    router.visit(`${window.location.pathname}${qs ? `?${qs}` : ""}`, {
      only: ["project_stats"],
      preserveState: true,
      preserveScroll: true,
      replace: true,
      async: true,
    });
  };

  const copyShareUrl = async () => {
    if (!share_url) return;
    try {
      await navigator.clipboard.writeText(share_url);
      copied = true;
      setTimeout(() => (copied = false), 2000);
    } catch {
      // silently fail
    }
  };

  const toggleShare = () => {
    toggling = true;
    router.patch(
      toggle_share_path,
      {},
      {
        preserveScroll: true,
        onFinish: () => {
          toggling = false;
        },
      },
    );
  };
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <div class="mb-6 flex flex-wrap items-start justify-between gap-4">
    <div>
      <Link
        href={back_path}
        class="text-sm text-muted transition-colors hover:text-primary"
      >
        ← Back to Projects
      </Link>
      <h1 class="mt-1 text-3xl font-bold text-surface-content">
        {project_name}
      </h1>
      {#if since_date}
        <p class="mt-1 text-sm text-muted">Since {since_date}</p>
      {/if}
    </div>
    <div class="flex items-center gap-2">
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
        <svg
          class="mr-1.5 h-4 w-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"
          />
        </svg>
        Share
      </Button>
    </div>
  </div>

  <div class="mb-6 sm:max-w-3xs">
    <IntervalSelect
      from={from || ""}
      selected={interval || ""}
      to={to || ""}
      onchange={changeInterval}
    />
  </div>

  <Deferred data="project_stats">
    {#snippet fallback()}
      <div class="animate-pulse space-y-6">
        <div class="grid grid-cols-1 gap-4">
          {#each Array(6) as _}
            <div class="h-20 rounded-xl bg-darkless"></div>
          {/each}
        </div>
        <div class="h-40 rounded-xl bg-darkless"></div>
        <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <div class="h-64 rounded-xl bg-darkless"></div>
          <div class="h-64 rounded-xl bg-darkless"></div>
        </div>
      </div>
    {/snippet}

    {#snippet children()}
      {#if project_stats}
        <ProjectStatsContent
          total_time_label={project_stats.total_time_label}
          file_count={project_stats.file_count}
          language_stats={project_stats.language_stats}
          language_colors={project_stats.language_colors}
          editor_stats={project_stats.editor_stats}
          os_stats={project_stats.os_stats}
          category_stats={project_stats.category_stats}
          file_stats={project_stats.file_stats}
          branch_stats={project_stats.branch_stats}
          activity_graph={project_stats.activity_graph}
        />
      {:else}
        <div
          class="rounded-xl border border-surface-200 bg-dark p-8 text-center"
        >
          <p class="text-muted">
            No activity found for this project in this time range.
          </p>
        </div>
      {/if}
    {/snippet}
  </Deferred>
</div>

<Modal
  bind:open={shareModalOpen}
  title="Share project"
  description={is_shared
    ? "Anyone with the link can view this project's stats."
    : "Share a public link so anyone can view this project's stats."}
  maxWidth="max-w-sm"
  hasBody
  bodyClass="mb-4"
  hasActions
>
  {#snippet body()}
    {#if is_shared && share_url}
      <div class="flex items-center gap-2">
        <input
          bind:this={urlInput}
          type="text"
          readonly
          value={share_url}
          class="flex-1 rounded-lg border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content"
          onclick={(e) => e.currentTarget.select()}
        />
        <Button
          type="button"
          variant="primary"
          size="sm"
          onclick={copyShareUrl}
        >
          {copied ? "Copied!" : "Copy"}
        </Button>
      </div>
    {/if}
  {/snippet}

  {#snippet actions()}
    <Button
      type="button"
      variant={is_shared ? "dark" : "primary"}
      class="w-full"
      disabled={toggling}
      onclick={toggleShare}
    >
      {is_shared ? "Make private" : "Share project"}
    </Button>
  {/snippet}
</Modal>
