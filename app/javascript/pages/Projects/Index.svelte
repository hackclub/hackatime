<script lang="ts">
  import { Link, router } from "@inertiajs/svelte";
  import { onMount } from "svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import Select from "../../components/Select.svelte";
  import IntervalSelect from "../Home/signedIn/IntervalSelect.svelte";

  type RepositorySummary = {
    homepage?: string | null;
    stars?: number | null;
    description?: string | null;
    formatted_languages?: string | null;
    last_commit_ago?: string | null;
  };

  type ProjectCard = {
    id: string;
    name: string;
    project_key?: string | null;
    duration_seconds: number;
    duration_label: string;
    duration_percent: number;
    show_path?: string | null;
    repo_url?: string | null;
    repository?: RepositorySummary | null;
    broken_name: boolean;
    manage_enabled: boolean;
    update_path?: string | null;
    archive_path?: string | null;
    unarchive_path?: string | null;
  };

  type ProjectsData = {
    total_time_seconds: number;
    total_time_label: string;
    has_activity: boolean;
    projects: ProjectCard[];
  };

  type PageProps = {
    page_title: string;
    index_path: string;
    show_archived: boolean;
    archived_count: number;
    github_connected: boolean;
    github_auth_path: string;
    settings_path: string;
    interval?: string | null;
    from?: string | null;
    to?: string | null;
    interval_label: string;
    total_projects: number;
    projects_data?: ProjectsData;
  };

  let {
    page_title,
    index_path,
    show_archived,
    archived_count,
    github_connected,
    github_auth_path,
    settings_path,
    interval = "",
    from = "",
    to = "",
    interval_label,
    total_projects,
    projects_data,
  }: PageProps = $props();

  let csrfToken = $state("");
  let editingProjectKey = $state<string | null>(null);
  let repoUrlDraft = $state("");
  let statusChangeModalOpen = $state(false);
  let pendingStatusAction = $state<{
    path: string;
    title: string;
    description: string;
    confirmLabel: string;
  } | null>(null);
  let viewMode = $state<"grid" | "list">("grid");
  let searchQuery = $state("");
  let sortBy = $state<"most_time" | "least_time" | "name_az" | "name_za">(
    "most_time",
  );
  let archivalStatus = $state("active");

  const skeletonCount = $derived.by(() => {
    const safeCount = Number.isFinite(total_projects) ? total_projects : 0;
    return Math.min(Math.max(safeCount, 4), 10);
  });

  const filteredAndSortedProjects = $derived.by(() => {
    if (!projects_data?.projects) return [];

    const searchLower = searchQuery.toLowerCase();
    const filtered = projects_data.projects.filter((project) => {
      return (
        project.name.toLowerCase().includes(searchLower) ||
        (project.repo_url?.toLowerCase().includes(searchLower) ?? false)
      );
    });

    return filtered.sort((a, b) => {
      switch (sortBy) {
        case "name_az":
          return a.name.localeCompare(b.name);
        case "name_za":
          return b.name.localeCompare(a.name);
        case "least_time":
          return a.duration_seconds - b.duration_seconds;
        case "most_time":
          return b.duration_seconds - a.duration_seconds;
        default:
          return b.duration_seconds - a.duration_seconds;
      }
    });
  });

  const buildIntervalQuery = ({
    nextInterval = interval || "",
    nextFrom = from || "",
    nextTo = to || "",
  }: {
    nextInterval?: string;
    nextFrom?: string;
    nextTo?: string;
  } = {}) => {
    const query = new URLSearchParams();

    if (nextInterval) query.set("interval", nextInterval);
    if (nextFrom) query.set("from", nextFrom);
    if (nextTo) query.set("to", nextTo);

    return query;
  };

  const intervalQueryString = $derived.by(() => {
    const queryString = buildIntervalQuery().toString();
    return queryString ? `?${queryString}` : "";
  });

  const withIntervalParams = (path: string) => {
    if (!intervalQueryString) return path;

    const separator = path.includes("?") ? "&" : "?";
    return `${path}${separator}${intervalQueryString.slice(1)}`;
  };

  $effect(() => {
    archivalStatus = show_archived ? "archived" : "active";
  });

  $effect(() => {
    const expectedValue = show_archived ? "archived" : "active";
    if (archivalStatus !== expectedValue) {
      changeArchivedStatus(archivalStatus);
    }
  });

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";
  });

  const buildProjectsPath = ({
    nextShowArchived = show_archived,
    nextInterval = interval || "",
    nextFrom = from || "",
    nextTo = to || "",
  }: {
    nextShowArchived?: boolean;
    nextInterval?: string;
    nextFrom?: string;
    nextTo?: string;
  } = {}) => {
    const query = buildIntervalQuery({ nextInterval, nextFrom, nextTo });

    if (nextShowArchived) query.set("show_archived", "true");

    const queryString = query.toString();
    return queryString ? `${index_path}?${queryString}` : index_path;
  };

  const changeInterval = (
    nextInterval: string,
    nextFrom: string,
    nextTo: string,
  ) => {
    const isCustom = Boolean(nextFrom || nextTo);
    const nextPath = buildProjectsPath({
      nextInterval: isCustom ? "custom" : nextInterval,
      nextFrom: isCustom ? nextFrom : "",
      nextTo: isCustom ? nextTo : "",
    });

    router.visit(nextPath, {
      only: ["projects_data", "interval", "from", "to", "interval_label", "total_projects"],
      preserveState: true,
      preserveScroll: true,
      replace: true,
      async: true,
    });
  };

  const changeArchivedStatus = (nextValue: string) => {
    window.location.href = buildProjectsPath({
      nextShowArchived: nextValue === "archived",
    });
  };

  const openMappingEditor = (project: ProjectCard) => {
    editingProjectKey = project.project_key || null;
    repoUrlDraft = project.repo_url || "";
  };

  const closeMappingEditor = () => {
    editingProjectKey = null;
    repoUrlDraft = "";
  };

  const openStatusChangeModal = (project: ProjectCard, restoring: boolean) => {
    const path = restoring ? project.unarchive_path : project.archive_path;
    if (!path) return;

    pendingStatusAction = {
      path,
      title: restoring
        ? `Restore ${project.name}?`
        : `Archive ${project.name}?`,
      description: restoring
        ? "This project will return to your active projects list and stats."
        : "This project will be hidden from most stats and listings, but it'll still be visible to you and any time logged will still count towards it. You can restore it anytime from the Archived Projects page.",
      confirmLabel: restoring ? "Restore project" : "Archive project",
    };
    statusChangeModalOpen = true;
  };

  const closeStatusChangeModal = () => {
    statusChangeModalOpen = false;
    pendingStatusAction = null;
  };

  const confirmStatusChange = () => {
    if (!pendingStatusAction) return;
    router.patch(
      pendingStatusAction.path,
      {},
      {
        preserveScroll: true,
        onSuccess: () => {
          statusChangeModalOpen = false;
          pendingStatusAction = null;
        },
      },
    );
  };

  const cardActionClass =
    "inline-flex h-10 w-10 items-center justify-center rounded-xl border border-surface-200/60 bg-surface-content/5 text-surface-content/70 shadow-sm transition-colors duration-200 ease-out hover:bg-surface-content/10 hover:text-surface-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60 cursor-pointer";
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <div class="mb-4 flex flex-wrap items-center gap-4">
    <h1 class="text-3xl font-bold text-surface-content">My Projects</h1>
  </div>

  {#if !github_connected}
    <div class="mb-4 rounded-xl border border-yellow/30 bg-yellow/10 p-4">
      <p class="text-base font-medium text-surface-content">
        Heads up! You can't link projects to GitHub until you connect your
        account.
      </p>
      <div class="mt-3 flex flex-wrap gap-2">
        <Button href={github_auth_path} native class="w-full sm:w-fit">
          Sign in with GitHub
        </Button>
        <Button href={settings_path} variant="surface" class="w-full sm:w-fit">
          Open settings
        </Button>
      </div>
    </div>
  {/if}

  {#if projects_data}
    <div class="mt-6 flex flex-wrap items-end gap-3">
      <div class="min-w-0 flex-[0_1_16rem]">
        <span class="mb-1.5 block text-xs font-medium uppercase tracking-wider text-secondary/80">
          Search Projects
        </span>
        <input
          id="project-search"
          type="text"
          placeholder="Search by name or URL..."
          bind:value={searchQuery}
          class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-left text-sm text-surface-content transition-all duration-200 hover:border-surface-300 focus-visible:border-primary/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/45 focus-visible:ring-offset-2 focus-visible:ring-offset-surface placeholder-surface-content/60"
        />
      </div>

      <div class="min-w-0 flex-[0_1_12rem]">
        <IntervalSelect
          from={from || ""}
          selected={interval || ""}
          to={to || ""}
          onchange={changeInterval}
        />
      </div>

      <div class="min-w-0 flex-[0_1_12rem]">
        <span class="mb-1.5 block text-xs font-medium uppercase tracking-wider text-secondary/80">
          Archival Status
        </span>
        <Select
          id="archival-status"
          bind:value={archivalStatus}
          items={[
            { value: "active", label: "Active" },
            { value: "archived", label: "Archived" },
          ]}
          class="bg-surface-100"
        />
      </div>

      {#if projects_data.projects && projects_data.projects.length > 0}
        <div class="min-w-0 flex-[0_1_18rem]">
          <div class="flex min-w-0 items-end gap-3">
            <div class="min-w-0 flex-[0_1_12rem]">
              <div class="mb-1.5 flex items-end gap-3">
                <span class="block text-xs font-medium uppercase tracking-wider text-secondary/80">
                  Sort
                </span>
              </div>
              <Select
                id="project-sort"
                bind:value={sortBy}
                items={[
                  { value: "most_time", label: "Most time" },
                  { value: "least_time", label: "Least time" },
                  { value: "name_az", label: "Name (A-Z)" },
                  { value: "name_za", label: "Name (Z-A)" },
                ]}
                class="bg-surface-100"
              />
            </div>
            <div class="shrink-0 flex flex-col items-start">
              <span class="mb-1.5 block text-xs font-medium uppercase tracking-wider text-secondary/80">
                View
              </span>
              <div class="inline-flex shrink-0 gap-1 rounded-lg border border-surface-200 bg-surface-content/5 p-1">
                <Button
                  type="button"
                  unstyled
                  class={`inline-flex h-8 w-8 items-center justify-center rounded transition-colors ${
                    viewMode === "grid"
                      ? "bg-primary text-on-primary"
                      : "text-surface-content/70 hover:bg-surface-content/10"
                  }`}
                  title="Grid view"
                  onclick={() => (viewMode = "grid")}
                >
                  <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M3 3h8v8H3V3zm10 0h8v8h-8V3zM3 13h8v8H3v-8zm10 0h8v8h-8v-8z" />
                  </svg>
                </Button>
                <Button
                  type="button"
                  unstyled
                  class={`inline-flex h-8 w-8 items-center justify-center rounded transition-colors ${
                    viewMode === "list"
                      ? "bg-primary text-on-primary"
                      : "text-surface-content/70 hover:bg-surface-content/10"
                  }`}
                  title="List view"
                  onclick={() => (viewMode = "list")}
                >
                  <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M3 4h18v2H3V4zm0 7h18v2H3v-2zm0 7h18v2H3v-2z" />
                  </svg>
                </Button>
              </div>
            </div>
          </div>
        </div>
      {/if}
    </div>

    <section class="mt-6">
      <p class="text-lg text-surface-content">
        {#if projects_data.has_activity}
          You've spent
          <span class="font-semibold text-primary">{projects_data.total_time_label}</span>
          coding across
          <span class="font-semibold text-primary">{total_projects}</span>
          {show_archived ? "archived" : "active"}
          {total_projects === 1 ? "project" : "projects"}.
        {:else}
          You haven't logged any time for this interval yet.
        {/if}
      </p>

      {#if projects_data.projects.length == 0}
        <div class="mt-4 rounded-xl border border-surface-200 bg-dark p-8 text-center">
          <p class="text-muted">
            {show_archived
              ? "No archived projects match this filter."
              : "No active projects match this filter."}
          </p>
        </div>
      {:else if filteredAndSortedProjects.length == 0}
        <div class="mt-4 rounded-xl border border-surface-200 bg-dark p-8 text-center">
          <p class="text-muted">No projects match your search query.</p>
        </div>
      {:else}
        <div
          class={viewMode === "grid"
            ? "mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6"
            : "mt-6 space-y-4"}
        >
          {#each filteredAndSortedProjects as project (project.id)}
            {@const projectHref = project.show_path ? withIntervalParams(project.show_path) : null}
            <article
              class={viewMode === "grid"
                ? "relative flex h-full flex-col gap-4 overflow-hidden rounded-xl border border-primary bg-dark p-6 shadow-xs backdrop-blur-sm transition-all duration-300"
                : "relative flex flex-col gap-4 overflow-hidden rounded-xl border border-primary bg-dark p-6 shadow-xs backdrop-blur-sm transition-all duration-300 sm:flex-row sm:items-center sm:justify-between"}
            >
              {#if projectHref}
                <Link
                  href={projectHref}
                  aria-label={`View ${project.name}`}
                  class="absolute inset-0 z-10 rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
                ></Link>
              {/if}

              <div
                class={viewMode === "grid"
                  ? "relative z-20 flex items-start justify-between gap-3"
                  : "relative z-20 flex flex-1 items-center gap-3"}
              >
                <div class="min-w-0 flex-1">
                  <h3
                    class="truncate text-lg font-semibold text-surface-content"
                    title={project.name}
                  >
                    {project.name}
                  </h3>

                  {#if project.repository?.stars}
                    <p
                      class={viewMode === "grid"
                        ? "mt-2 inline-flex items-center gap-1 text-sm text-yellow"
                        : "mt-1 inline-flex items-center gap-1 text-sm text-yellow"}
                    >
                      <svg class="h-4 w-4 fill-current" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                      </svg>
                      {project.repository.stars}
                    </p>
                  {/if}
                </div>

                {#if viewMode === "grid"}
                  <p class="shrink-0 text-2xl font-bold text-primary">{project.duration_label}</p>
                {/if}
              </div>

              {#if viewMode === "grid"}
                {#if project.repository?.description}
                  <p class="relative z-20 line-clamp-2 text-sm leading-relaxed text-surface-content/70 text-pretty">
                    {project.repository.description}
                  </p>
                {/if}

                {#if project.repository?.formatted_languages}
                  <p class="relative z-20 flex items-center gap-1 text-sm">
                    <svg class="h-4 w-4 text-surface-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path fill="currentColor" d="M5.59 3.41L7 4.82L3.82 8L7 11.18L5.59 12.6L1 8zm5.82 0L16 8l-4.59 4.6L10 11.18L13.18 8L10 4.82zM22 6v12c0 1.11-.89 2-2 2H4a2 2 0 0 1-2-2v-4h2v4h16V6h-2.97V4H20c1.11 0 2 .89 2 2" />
                    </svg>
                    <span class="truncate text-surface-content/50">{project.repository.formatted_languages}</span>
                  </p>
                {/if}

                {#if project.repository?.last_commit_ago}
                  <p class="relative z-20 flex items-center gap-1 text-sm">
                    <svg class="h-4 w-4 text-surface-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path fill="currentColor" d="M12 20c4.4 0 8-3.6 8-8s-3.6-8-8-8s-8 3.6-8 8s3.6 8 8 8m0-18c5.5 0 10 4.5 10 10s-4.5 10-10 10S2 17.5 2 12S6.5 2 12 2m.5 10.8l-4.8 2.8l-.7-1.4l4-2.3V7h1.5z" />
                    </svg>
                    <span class="text-surface-content/50">Last commit {project.repository.last_commit_ago}</span>
                  </p>
                {/if}

                {#if project.broken_name}
                  <div class="relative z-20 rounded-lg border border-yellow/30 bg-yellow/10 p-3">
                    <p class="text-sm leading-relaxed text-yellow/80">
                      Your editor may be sending invalid project names. Time is shown here but can't be submitted to Hack Club programs.
                    </p>
                  </div>
                {/if}
              {/if}

              <div class="relative z-20 flex flex-wrap items-center gap-2 text-sm text-surface-content/55">
                {#if project.repository?.homepage}
                  <a
                    href={project.repository.homepage}
                    target="_blank"
                    rel="noopener noreferrer"
                    title="View project website"
                    class={cardActionClass}
                  >
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path fill="currentColor" d="M16.36 14c.08-.66.14-1.32.14-2s-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2m-5.15 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95a8.03 8.03 0 0 1-4.33 3.56M14.34 14H9.66c-.1-.66-.16-1.32-.16-2s.06-1.35.16-2h4.68c.09.65.16 1.32.16 2s-.07 1.34-.16 2M12 19.96c-.83-1.2-1.5-2.53-1.91-3.96h3.82c-.41 1.43-1.08 2.76-1.91 3.96M8 8H5.08A7.92 7.92 0 0 1 9.4 4.44C8.8 5.55 8.35 6.75 8 8m-2.92 8H8c.35 1.25.8 2.45 1.4 3.56A8 8 0 0 1 5.08 16m-.82-2C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2s.06 1.34.14 2M12 4.03c.83 1.2 1.5 2.54 1.91 3.97h-3.82c.41-1.43 1.08-2.77 1.91-3.97M18.92 8h-2.95a15.7 15.7 0 0 0-1.38-3.56c1.84.63 3.37 1.9 4.33 3.56M12 2C6.47 2 2 6.5 2 12a10 10 0 0 0 10 10a10 10 0 0 0 10-10A10 10 0 0 0 12 2" />
                    </svg>
                  </a>
                {/if}

                {#if project.repo_url}
                  <a
                    href={project.repo_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    title="View repository"
                    class={cardActionClass}
                  >
                    <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                      <path fill="currentColor" d="M2.6 10.59L8.38 4.8l1.69 1.7c-.24.85.15 1.78.93 2.23v5.54c-.6.34-1 .99-1 1.73a2 2 0 0 0 2 2a2 2 0 0 0 2-2c0-.74-.4-1.39-1-1.73V9.41l2.07 2.09c-.07.15-.07.32-.07.5a2 2 0 0 0 2 2a2 2 0 0 0 2-2a2 2 0 0 0-2-2c-.18 0-.35 0-.5.07L13.93 7.5a1.98 1.98 0 0 0-1.15-2.34c-.43-.16-.88-.2-1.28-.09L9.8 3.38l.79-.78c.78-.79 2.04-.79 2.82 0l7.99 7.99c.79.78.79 2.04 0 2.82l-7.99 7.99c-.78.79-2.04.79-2.82 0L2.6 13.41c-.79-.78-.79-2.04 0-2.82" />
                    </svg>
                  </a>
                {/if}

                {#if project.manage_enabled}
                  <Button
                    type="button"
                    unstyled
                    class={cardActionClass}
                    title={project.repo_url ? "Edit mapping" : "Link repository"}
                    onclick={() => openMappingEditor(project)}
                  >
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16.862 3.487a2.1 2.1 0 0 1 2.97 2.97L9.75 16.54 6 17.25l.71-3.75z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.5 5.85l3.65 3.65" />
                    </svg>
                  </Button>
                {/if}

                {#if show_archived && project.unarchive_path}
                  <Button
                    type="button"
                    unstyled
                    class={cardActionClass}
                    title="Restore project"
                    onclick={() => openStatusChangeModal(project, true)}
                  >
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l-3-3 3-3" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 11h9a4 4 0 0 1 0 8h-2" />
                    </svg>
                  </Button>
                {:else if !show_archived && project.archive_path}
                  <Button
                    type="button"
                    unstyled
                    class={cardActionClass}
                    title="Archive project"
                    onclick={() => openStatusChangeModal(project, false)}
                  >
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7h18l-2 11H5z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V4h8v3" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 11h4" />
                    </svg>
                  </Button>
                {/if}
              </div>

              {#if viewMode === "list"}
                <div class="relative z-20 flex shrink-0 items-center gap-3 text-sm">
                  <p class="text-lg font-bold leading-none text-primary sm:text-xl">
                    {project.duration_label}
                  </p>
                </div>
              {/if}

              {#if project.manage_enabled && editingProjectKey === project.project_key && project.update_path}
                <div class="relative z-20 mt-1 border-t border-surface-200/40 pt-4">
                  <form method="post" action={project.update_path} class="space-y-3">
                    <input type="hidden" name="_method" value="patch" />
                    <input type="hidden" name="authenticity_token" value={csrfToken} />

                    <input
                      type="url"
                      name="project_repo_mapping[repo_url]"
                      bind:value={repoUrlDraft}
                      placeholder="https://github.com/owner/repo"
                      class="w-full rounded-lg border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                    />

                    <div class="flex gap-2">
                      <Button type="submit" variant="primary" size="sm" class="flex-1">Save</Button>
                      <Button type="button" variant="dark" size="sm" class="flex-1" onclick={closeMappingEditor}>
                        Cancel
                      </Button>
                    </div>
                  </form>
                </div>
              {/if}
            </article>
          {/each}
        </div>
      {/if}
    </section>
  {:else}
    <section class="mt-6 animate-pulse">
      <div class="h-7 w-80 rounded bg-darkless"></div>
      <div class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6">
        {#each Array.from({ length: skeletonCount }) as _unused, index (index)}
          <div class="rounded-xl border border-primary bg-dark p-6">
            <div class="h-6 w-28 rounded bg-darkless"></div>
            <div class="mt-3 h-7 w-20 rounded bg-darkless"></div>
            <div class="mt-4 h-4 w-full rounded bg-darkless"></div>
            <div class="mt-2 h-4 w-3/4 rounded bg-darkless"></div>
            <div class="mt-4 h-8 w-full rounded bg-darkless"></div>
          </div>
        {/each}
      </div>
    </section>
  {/if}
</div>

<Modal
  bind:open={statusChangeModalOpen}
  title={pendingStatusAction
    ? pendingStatusAction.title
    : "Confirm project change"}
  description={pendingStatusAction
    ? pendingStatusAction.description
    : "Confirm this project status change."}
  maxWidth="max-w-md"
  hasActions
>
  {#snippet actions()}
    {#if pendingStatusAction}
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Button
          type="button"
          variant="dark"
          class="h-10 w-full border border-surface-300 text-muted"
          onclick={closeStatusChangeModal}
        >
          Cancel
        </Button>
        <Button
          type="button"
          variant="primary"
          class="h-10 w-full text-on-primary"
          onclick={confirmStatusChange}
        >
          {pendingStatusAction.confirmLabel}
        </Button>
      </div>
    {/if}
  {/snippet}
</Modal>