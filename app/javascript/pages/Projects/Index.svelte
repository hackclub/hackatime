<script lang="ts">
  import { Deferred, Link, router } from "@inertiajs/svelte";
  import Search from "hcicons-svelte/search";
  import { onDestroy, onMount, tick } from "svelte";
  import { ChevronDown, ChevronUp, Icon, XMark } from "svelte-hero-icons";
  import { WindowVirtualizer } from "virtua/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import IntervalSelect from "../Home/signedIn/IntervalSelect.svelte";
  import ProjectCard from "./components/ProjectCard.svelte";
  import { myProjectRepoMappings, sessions, settingsProfile } from "../../api";
  import { buildIntervalChange, intervalParams } from "./intervalNav";
  import type { ProjectCard as ProjectCardType } from "./types";

  let {
    page_title,
    show_archived,
    archived_count,
    github_connected,
    interval = "",
    from = "",
    to = "",
    total_projects,
    projects_data,
    errors = {},
  }: {
    page_title: string;
    show_archived: boolean;
    archived_count: number;
    github_connected: boolean;
    interval?: string | null;
    from?: string | null;
    to?: string | null;
    interval_label: string;
    total_projects: number;
    projects_data?: {
      total_time_label: string;
      has_activity: boolean;
      projects: ProjectCardType[];
    };
    errors?: {
      repo_url?: string;
      repo_url_project_name?: string;
      repo_url_value?: string;
    };
  } = $props();

  const indexPath = myProjectRepoMappings.index.path();
  const githubAuthPath = sessions.githubNew.path();
  const settingsPath = `${settingsProfile.mySettings.path()}#user_github_account`;

  const intervalQueryString = $derived(
    intervalParams(interval, from, to).toString(),
  );

  const buildProjectsPath = (nextShowArchived: boolean) => {
    const q = intervalParams(interval, from, to);
    if (nextShowArchived) q.set("show_archived", "true");
    const qs = q.toString();
    return qs ? `${indexPath}?${qs}` : indexPath;
  };

  let editingProjectKey = $state<string | null>(null);
  let repoUrlDraft = $state("");
  let statusChangeModalOpen = $state(false);
  let brokenNameModalOpen = $state(false);
  let pendingStatusAction = $state<{
    path: string;
    title: string;
    description: string;
    confirmLabel: string;
  } | null>(null);

  $effect(() => {
    if (errors.repo_url && errors.repo_url_project_name) {
      editingProjectKey = errors.repo_url_project_name;
      repoUrlDraft = errors.repo_url_value || "";
    }
  });

  const skeletonCount = $derived(
    Math.min(
      Math.max(Number.isFinite(total_projects) ? total_projects : 0, 4),
      10,
    ),
  );

  const PROJECT_CARD_MIN_WIDTH = 280;
  const PROJECT_GRID_GAP = 20;
  const PROJECT_ROW_ESTIMATE = 208;

  let projectGridContainer: HTMLDivElement | undefined = $state();
  let projectVirtualizer: WindowVirtualizer<ProjectCardType[]> | undefined =
    $state();
  let projectColumnCount = $state(1);
  let searchQuery = $state("");
  let searchOpen = $state(false);
  let searchInput: HTMLInputElement | undefined = $state();
  let currentMatchIndex = $state(0);

  const normalizedSearchQuery = $derived(
    searchQuery.trim().toLocaleLowerCase(),
  );
  const matchingProjects = $derived(
    normalizedSearchQuery
      ? (projects_data?.projects || []).filter((project) =>
          project.name.toLocaleLowerCase().includes(normalizedSearchQuery),
        )
      : [],
  );
  const visibleProjects = $derived(
    normalizedSearchQuery ? matchingProjects : projects_data?.projects || [],
  );

  const openSearch = async () => {
    searchOpen = true;
    await tick();
    searchInput?.focus();
    searchInput?.select();
  };

  const closeSearch = () => {
    searchOpen = false;
    searchQuery = "";
    currentMatchIndex = 0;
  };

  const navigateMatches = (direction: 1 | -1) => {
    if (matchingProjects.length === 0) return;

    currentMatchIndex =
      (currentMatchIndex + direction + matchingProjects.length) %
      matchingProjects.length;
    projectVirtualizer?.scrollToIndex(
      Math.floor(currentMatchIndex / projectColumnCount),
      { align: "center", smooth: true },
    );
  };

  const handleSearchKeydown = (event: KeyboardEvent) => {
    if (event.key === "Enter") {
      event.preventDefault();
      navigateMatches(event.shiftKey ? -1 : 1);
    }
  };

  const handlePageKeydown = (event: KeyboardEvent) => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "f") {
      event.preventDefault();
      void openSearch();
    } else if (event.key === "Escape" && searchOpen) {
      event.preventDefault();
      closeSearch();
    }
  };

  const updateProjectColumnCount = () => {
    if (!projectGridContainer) return;

    const width = projectGridContainer.clientWidth;
    projectColumnCount = Math.max(
      1,
      Math.floor(
        (width + PROJECT_GRID_GAP) /
          (PROJECT_CARD_MIN_WIDTH + PROJECT_GRID_GAP),
      ),
    );
  };

  const projectRows = $derived.by(() => {
    const rows: ProjectCardType[][] = [];

    for (
      let index = 0;
      index < visibleProjects.length;
      index += projectColumnCount
    ) {
      rows.push(visibleProjects.slice(index, index + projectColumnCount));
    }

    return rows;
  });

  $effect(() => {
    searchQuery;
    currentMatchIndex = 0;
  });

  $effect(() => {
    updateProjectColumnCount();

    if (!projectGridContainer) return;

    const observer = new ResizeObserver(updateProjectColumnCount);
    observer.observe(projectGridContainer);

    return () => observer.disconnect();
  });

  onMount(() => document.addEventListener("keydown", handlePageKeydown));
  onDestroy(() => document.removeEventListener("keydown", handlePageKeydown));

  const changeInterval = (
    nextInterval: string,
    nextFrom: string,
    nextTo: string,
  ) => {
    const q = buildIntervalChange(nextInterval, nextFrom, nextTo);
    if (show_archived) q.set("show_archived", "true");
    const qs = q.toString();
    router.visit(qs ? `${indexPath}?${qs}` : indexPath, {
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

  const openMappingEditor = (project: ProjectCardType) => {
    editingProjectKey = project.project_key || null;
    repoUrlDraft = project.repo_url || "";
  };

  const closeMappingEditor = () => {
    editingProjectKey = null;
    repoUrlDraft = "";
  };

  const openStatusChangeModal = (
    project: ProjectCardType,
    restoring: boolean,
  ) => {
    if (!project.url_safe || !project.project_key) return;
    const path = (
      restoring
        ? myProjectRepoMappings.unarchive
        : myProjectRepoMappings.archive
    ).path({ projectName: encodeURIComponent(project.project_key) });

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
      { preserveScroll: true, onSuccess: closeStatusChangeModal },
    );
  };
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

{#if searchOpen}
  <div
    role="search"
    aria-label="Find projects"
    class="fixed right-4 top-4 z-50 flex h-10 w-[min(22rem,calc(100vw-2rem))] items-center rounded-lg border border-surface-200 bg-dark px-2 shadow-xl shadow-black/30"
  >
    <label for="project-search" class="sr-only">Find projects</label>
    <input
      bind:this={searchInput}
      id="project-search"
      name="project-search"
      type="text"
      bind:value={searchQuery}
      onkeydown={handleSearchKeydown}
      placeholder="Find in projects"
      autocomplete="off"
      class="h-full min-w-0 flex-1 border-0 bg-transparent px-2 text-sm text-surface-content placeholder:text-muted focus:outline-none focus:ring-0"
    />
    <span
      aria-live="polite"
      class="w-14 shrink-0 text-center text-xs tabular-nums text-muted"
    >
      {matchingProjects.length > 0
        ? currentMatchIndex + 1
        : 0}/{matchingProjects.length}
    </span>
    <Button
      type="button"
      unstyled
      aria-label="Previous match"
      title="Previous match (Shift+Enter)"
      class="flex h-8 w-8 shrink-0 cursor-pointer items-center justify-center rounded-full text-muted hover:bg-surface-200 hover:text-surface-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50"
      onclick={() => navigateMatches(-1)}
    >
      <Icon src={ChevronUp} size="17" />
    </Button>
    <Button
      type="button"
      unstyled
      aria-label="Next match"
      title="Next match (Enter)"
      class="flex h-8 w-8 shrink-0 cursor-pointer items-center justify-center rounded-full text-muted hover:bg-surface-200 hover:text-surface-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50"
      onclick={() => navigateMatches(1)}
    >
      <Icon src={ChevronDown} size="17" />
    </Button>
    <Button
      type="button"
      unstyled
      aria-label="Close search"
      title="Close (Escape)"
      class="flex h-8 w-8 shrink-0 cursor-pointer items-center justify-center rounded-full text-muted hover:bg-surface-200 hover:text-surface-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50"
      onclick={closeSearch}
    >
      <Icon src={XMark} size="18" />
    </Button>
  </div>
{/if}

<div>
  <div class="mb-4 flex flex-wrap items-center justify-between gap-4">
    <div class="flex items-center gap-4">
      <h1 class="text-2xl sm:text-3xl font-bold text-surface-content">
        My Projects
      </h1>
      {#if archived_count > 0}
        <div class="project-toggle-group">
          <Link
            href={buildProjectsPath(false)}
            class={`project-toggle-btn ${!show_archived ? "active" : "inactive"}`}
          >
            Active
          </Link>
          <Link
            href={buildProjectsPath(true)}
            class={`project-toggle-btn ${show_archived ? "active" : "inactive"}`}
          >
            Archived
          </Link>
        </div>
      {/if}
    </div>
  </div>

  <div class="flex items-center gap-3">
    <div class="relative min-w-0 flex-1">
      <label for="project-filter" class="sr-only">Search projects</label>
      <Search
        size={24}
        aria-hidden="true"
        class="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-muted"
      />
      <input
        id="project-filter"
        name="project-filter"
        type="search"
        bind:value={searchQuery}
        placeholder="Search projects"
        class="h-10 w-full rounded-lg border border-surface-200 bg-input pl-11 pr-4 text-base text-surface-content placeholder:text-muted focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/30"
      />
    </div>

    <Button
      type="button"
      variant="surface"
      class="h-10 shrink-0 gap-2 px-3"
      onclick={openSearch}
    >
      <Search size={18} aria-hidden="true" class="text-muted" />
      <span>Find</span>
      <kbd
        class="hidden rounded border border-surface-300 bg-dark px-1.5 py-0.5 font-sans text-[10px] font-medium text-muted sm:inline"
        >Ctrl F</kbd
      >
    </Button>

    <div class="w-44 shrink-0 sm:w-56">
      <IntervalSelect
        from={from || ""}
        selected={interval || ""}
        to={to || ""}
        onchange={changeInterval}
        showLabel={false}
        showIcon
      />
    </div>
  </div>

  <Deferred data="projects_data">
    {#snippet fallback()}
      <section class="mt-6 animate-pulse">
        <div class="h-7 w-80 rounded bg-darkless"></div>
        <div
          class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-5"
        >
          {#each Array.from( { length: skeletonCount } ) as _unused, index (index)}
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

          {#if !github_connected}
            <div
              class="mt-4 rounded-xl border border-yellow/30 bg-yellow/10 p-4"
            >
              <p class="text-base font-medium text-surface-content">
                Heads up! You can't link projects to GitHub until you connect
                your account.
              </p>
              <div class="mt-3 flex flex-wrap gap-2">
                <Button href={githubAuthPath} native class="w-full sm:w-fit">
                  Sign in with GitHub
                </Button>
                <Button
                  href={settingsPath}
                  variant="surface"
                  class="w-full sm:w-fit"
                >
                  Open settings
                </Button>
              </div>
            </div>
          {/if}

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
          {:else if projectRows.length == 0}
            <div
              class="mt-4 rounded-xl border border-surface-200 bg-dark p-8 text-center"
            >
              <p class="text-muted">No projects match your search.</p>
            </div>
          {:else}
            <div bind:this={projectGridContainer} class="mt-6">
              <WindowVirtualizer
                bind:this={projectVirtualizer}
                data={projectRows}
                getKey={(row) => row[0]?.id || "empty-row"}
                itemSize={PROJECT_ROW_ESTIMATE}
                bufferSize={1_000}
              >
                {#snippet children(row)}
                  <div
                    class="grid gap-5 pb-5"
                    style={`grid-template-columns: repeat(${projectColumnCount}, minmax(0, 1fr));`}
                  >
                    {#each row as project (project.id)}
                      <div
                        class:rounded-2xl={searchQuery &&
                          matchingProjects[currentMatchIndex]?.id ===
                            project.id}
                        class:ring-2={searchQuery &&
                          matchingProjects[currentMatchIndex]?.id ===
                            project.id}
                        class:ring-primary={searchQuery &&
                          matchingProjects[currentMatchIndex]?.id ===
                            project.id}
                        class:ring-offset-2={searchQuery &&
                          matchingProjects[currentMatchIndex]?.id ===
                            project.id}
                        class:ring-offset-surface={searchQuery &&
                          matchingProjects[currentMatchIndex]?.id ===
                            project.id}
                      >
                        <ProjectCard
                          {project}
                          showArchived={show_archived}
                          {intervalQueryString}
                          onEditMapping={openMappingEditor}
                          onArchive={openStatusChangeModal}
                          onShowBrokenInfo={() => (brokenNameModalOpen = true)}
                          editing={editingProjectKey === project.project_key}
                          repoUrlError={errors.repo_url_project_name ===
                          project.project_key
                            ? errors.repo_url
                            : undefined}
                          highlightQuery={searchQuery}
                          bind:repoUrlDraft
                          onCancelEdit={closeMappingEditor}
                        />
                      </div>
                    {/each}
                  </div>
                {/snippet}
              </WindowVirtualizer>
            </div>
          {/if}
        </section>
      {/if}
    {/snippet}
  </Deferred>
</div>

<Modal
  bind:open={statusChangeModalOpen}
  title={pendingStatusAction?.title ?? "Confirm project change"}
  description={pendingStatusAction?.description ??
    "Confirm this project status change."}
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

<Modal
  bind:open={brokenNameModalOpen}
  title="Why is my project invalid?"
  description="Your editor isn't sending a valid project name."
  maxWidth="max-w-lg"
  hasBody
>
  {#snippet body()}
    <div class="space-y-3 text-sm leading-relaxed text-surface-content/80">
      <p>
        The WakaTime extension needs one of two things in order for time to
        properly count:
      </p>
      <ul class="list-disc space-y-1 pl-5">
        <li>You have a Git repo inside your project folder, or</li>
        <li>
          You have a <code
            class="rounded bg-surface-content/10 px-1 py-0.5 text-xs"
            >.wakatime-project</code
          >
          file in your folder's root, with the contents set to the name you want for
          your project.
        </li>
      </ul>
      <p>To get your time to properly track, do one of the above!</p>
    </div>
  {/snippet}
</Modal>
