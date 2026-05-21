<script lang="ts">
  import { Deferred, Form, Link, router } from "@inertiajs/svelte";
  import Archive from "hcicons-svelte/archive";
  import Edit from "hcicons-svelte/edit";
  import GithubFill from "hcicons-svelte/github-fill";
  import Reply from "hcicons-svelte/reply";
  import Web from "hcicons-svelte/web";
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
  let archivalStatus = $state(show_archived ? "archived" : "active");

  const skeletonCount = $derived.by(() => {
    const safeCount = Number.isFinite(total_projects) ? total_projects : 0;
    return Math.min(Math.max(safeCount, 4), 10);
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

  const intervalQueryString = $derived.by(() => {
    const queryString = buildIntervalQuery().toString();
    return queryString ? `?${queryString}` : "";
  });

  const withIntervalParams = (path: string) => {
    if (!intervalQueryString) return path;

    const separator = path.includes("?") ? "&" : "?";
    return `${path}${separator}${intervalQueryString.slice(1)}`;
  };

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

  $effect(() => {
    const expectedValue = show_archived ? "archived" : "active";
    if (archivalStatus !== expectedValue) {
      changeArchivedStatus(archivalStatus);
    }
  });

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
      only: [
        "projects_data",
        "interval",
        "from",
        "to",
        "interval_label",
        "total_projects",
      ],
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
  <div class="mb-4 flex flex-wrap items-center justify-between gap-4">
    <div class="flex items-center gap-4">
      <h1 class="text-3xl font-bold text-surface-content">My Projects</h1>
      {#if archived_count > 0}
        <div class="project-toggle-group">
          <Link
            href={buildProjectsPath({ nextShowArchived: false })}
            class={`project-toggle-btn ${!show_archived ? "active" : "inactive"}`}
          >
            Active
          </Link>
          <Link
            href={buildProjectsPath({ nextShowArchived: true })}
            class={`project-toggle-btn ${show_archived ? "active" : "inactive"}`}
          >
            Archived
          </Link>
        </div>
      {/if}
    </div>
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

  <div class="mt-6 flex flex-wrap items-end gap-3">
    <div class="sm:max-w-3xs">
      <IntervalSelect
        from={from || ""}
        selected={interval || ""}
        to={to || ""}
        onchange={changeInterval}
      />
    </div>

    {#if projects_data}
      <div class="min-w-0 flex-1">
        <div class="flex flex-wrap items-end gap-3">
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
      </div>
    {/if}
  </div>

  <Deferred data="projects_data">
    {#snippet fallback()}
      <section class="mt-6 animate-pulse">
        <div class="h-7 w-80 rounded bg-darkless"></div>
        <div
          class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(360px,1fr))] gap-6"
        >
          {#each Array.from( { length: skeletonCount }, ) as _unused, index (index)}
            <div
              class="min-h-36 rounded-2xl border border-surface-200 bg-dark p-5"
            >
              <div class="h-6 w-28 rounded bg-darkless"></div>
              <div class="mt-3 h-7 w-20 rounded bg-darkless"></div>
              <div class="mt-4 h-4 w-full rounded bg-darkless"></div>
              <div class="mt-2 h-4 w-3/4 rounded bg-darkless"></div>
              <div class="mt-4 h-8 w-full rounded bg-darkless"></div>
            </div>
          {/each}
        </div>
      </section>
    {/snippet}

    {#snippet children({ reloading })}
      {#if projects_data}
        <section
          class="mt-6 transition-opacity duration-200 ease-out"
          class:opacity-60={reloading}
        >
          <p class="text-lg text-surface-content">
            {#if projects_data.has_activity}
              You've spent
              <span class="font-semibold text-primary"
                >{projects_data.total_time_label}</span
              >
              coding across {show_archived ? "archived" : "active"} projects.
            {:else}
              You haven't logged any time for this interval yet.
            {/if}
          </p>

          {#if projects_data.projects.length == 0}
            <div
              class="mt-4 rounded-xl border border-surface-200 bg-dark p-8 text-center"
            >
              <p class="text-muted">
                {show_archived
                  ? "No archived projects match this filter."
                  : "No active projects match this filter."}
              </p>
            </div>
          {:else if filteredAndSortedProjects.length == 0}
            <div
              class="mt-4 rounded-xl border border-surface-200 bg-dark p-8 text-center"
            >
              <p class="text-muted">No projects match your search query.</p>
            </div>
          {:else}
            <div
              class={viewMode === "grid"
                ? "mt-6 grid grid-cols-[repeat(auto-fill,minmax(360px,1fr))] justify-items-stretch gap-6"
                : "mt-6 space-y-4"}
            >
              {#each filteredAndSortedProjects as project (project.id)}
                {@const projectHref = project.show_path
                  ? withIntervalParams(project.show_path)
                  : null}
                <article
                  class="group relative flex w-full {viewMode === 'list' ? 'flex-row items-start sm:items-center sm:justify-between' : ''} min-h-36 overflow-hidden rounded-2xl {projectHref
                    ? 'cursor-pointer'
                    : ''}"
                >
                  {#if projectHref}
                    <Link
                      href={projectHref}
                      aria-label={`View ${project.name}`}
                      class="absolute inset-0 z-10 rounded-2xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
                    ></Link>
                  {/if}
                  <div
                    class="relative flex w-full min-w-0 {viewMode === 'list' ? 'flex-1' : ''} flex-col rounded-2xl border border-surface-200 bg-dark p-5 transition-colors duration-300 ease-out group-hover:border-surface-300"
                  >
                    <div class="grid gap-3">
                      <div
                        class="flex min-w-0 {viewMode === 'list' ? 'flex-1' : ''} items-start justify-between gap-3"
                      >
                        <div class="min-w-0 flex-1">
                          <h3
                            class="truncate text-xl font-bold tracking-tight text-surface-content"
                            title={project.name}
                          >
                            {project.name}
                          </h3>
                        </div>
                        {#if viewMode === "grid"}
                          <p
                            class="shrink-0 text-lg font-semibold tabular-nums text-primary/80"
                          >
                            {project.duration_label}
                          </p>
                        {:else}
                          <p
                            class="shrink-0 text-lg font-semibold tabular-nums text-primary/80"
                          >
                            {project.duration_label}
                          </p>
                        {/if}
                      </div>

                      {#if project.repository?.description && viewMode === "grid"}
                        <p
                          class="line-clamp-2 text-sm leading-relaxed text-surface-content/70 text-pretty"
                        >
                          {project.repository.description}
                        </p>
                      {/if}

                      <div
                        class="relative z-20 flex flex-wrap items-center gap-2"
                      >
                        {#if project.repository?.homepage}
                          <a
                            href={project.repository.homepage}
                            target="_blank"
                            rel="noopener noreferrer"
                            title="View project website"
                            class={cardActionClass}
                          >
                            <Web size={20} />
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
                            <GithubFill size={20} />
                          </a>
                        {/if}
                        {#if project.manage_enabled}
                          <Button
                            type="button"
                            unstyled
                            class={cardActionClass}
                            title={project.repo_url
                              ? "Edit mapping"
                              : "Link repository"}
                            onclick={() => openMappingEditor(project)}
                          >
                            <Edit size={20} />
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
                            <Reply size={20} />
                          </Button>
                        {:else if !show_archived && project.archive_path}
                          <Button
                            type="button"
                            unstyled
                            class={cardActionClass}
                            title="Archive project"
                            onclick={() =>
                              openStatusChangeModal(project, false)}
                          >
                            <Archive size={20} />
                          </Button>
                        {/if}
                      </div>
                    </div>

                    <div
                      class="mt-auto flex flex-wrap items-center gap-2 {viewMode === 'grid' ? 'pt-5' : viewMode === 'list' ? 'pt-0' : ''} text-sm text-surface-content/55"
                    >
                      {#if project.repository?.formatted_languages && viewMode === "grid"}
                        <p
                          class="flex min-w-0 items-center gap-1.5 rounded-full bg-surface-content/5 px-3 py-1.5"
                        >
                          <svg
                            class="h-4 w-4 text-surface-content/50"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                            aria-hidden="true"
                          >
                            <path
                              fill="currentColor"
                              d="M5.59 3.41L7 4.82L3.82 8L7 11.18L5.59 12.6L1 8zm5.82 0L16 8l-4.59 4.6L10 11.18L13.18 8L10 4.82zM22 6v12c0 1.11-.89 2-2 2H4a2 2 0 0 1-2-2v-4h2v4h16V6h-2.97V4H20c1.11 0 2 .89 2 2"
                            />
                          </svg>
                          <span class="truncate text-surface-content/60"
                            >{project.repository.formatted_languages}</span
                          >
                        </p>
                      {/if}

                      {#if project.repository?.last_commit_ago && viewMode === "grid"}
                        <p
                          class="flex items-center gap-1.5 rounded-full bg-surface-content/5 px-3 py-1.5"
                        >
                          <svg
                            class="h-4 w-4 text-surface-content/50"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                            aria-hidden="true"
                          >
                            <path
                              fill="currentColor"
                              d="M12 20c4.4 0 8-3.6 8-8s-3.6-8-8-8s-8 3.6-8 8s3.6 8 8 8m0-18c5.5 0 10 4.5 10 10s-4.5 10-10 10S2 17.5 2 12S6.5 2 12 2m.5 10.8l-4.8 2.8l-.7-1.4l4-2.3V7h1.5z"
                            />
                          </svg>
                          <span class="text-surface-content/50"
                            >Last commit {project.repository.last_commit_ago}</span
                          >
                        </p>
                      {/if}
                    </div>

                    {#if project.broken_name && viewMode === "grid"}
                      <div
                        class="mt-4 rounded-2xl border border-yellow/30 bg-yellow/10 p-3"
                      >
                        <p
                          class="text-sm leading-relaxed text-yellow/80 text-pretty"
                        >
                          Your editor may be sending invalid project names. Time
                          is shown here but can't be submitted to Hack Club
                          programs.
                        </p>
                      </div>
                    {/if}

                    {#if project.manage_enabled && editingProjectKey === project.project_key && project.update_path}
                      <div
                        class="relative z-20 mt-4 border-t border-surface-200/40 pt-4"
                      >
                        <Form
                          action={project.update_path}
                          method="patch"
                          class="space-y-3"
                        >
                          <input
                            type="url"
                            name="project_repo_mapping[repo_url]"
                            bind:value={repoUrlDraft}
                            placeholder="https://github.com/owner/repo"
                            class="w-full rounded-lg border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
                          />

                          <div class="flex gap-2">
                            <Button
                              type="submit"
                              variant="primary"
                              size="sm"
                              class="flex-1">Save</Button
                            >
                            <Button
                              type="button"
                              variant="dark"
                              size="sm"
                              class="flex-1"
                              onclick={closeMappingEditor}
                            >
                              Cancel
                            </Button>
                          </div>
                        </Form>
                      </div>
                    {/if}
                  </div>
                </article>
              {/each}
            </div>
          {/if}
        </section>
      {/if}
    {/snippet}
  </Deferred>
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
