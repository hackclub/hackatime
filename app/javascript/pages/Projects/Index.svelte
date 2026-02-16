<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import { onMount } from "svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
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

  const skeletonCount = $derived.by(() => {
    const safeCount = Number.isFinite(total_projects) ? total_projects : 0;
    return Math.min(Math.max(safeCount, 4), 10);
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
    const query = new URLSearchParams();

    if (nextShowArchived) query.set("show_archived", "true");
    if (nextInterval) query.set("interval", nextInterval);
    if (nextFrom) query.set("from", nextFrom);
    if (nextTo) query.set("to", nextTo);

    const queryString = query.toString();
    return queryString ? `${index_path}?${queryString}` : index_path;
  };

  const changeInterval = (
    nextInterval: string,
    nextFrom: string,
    nextTo: string,
  ) => {
    const isCustom = Boolean(nextFrom || nextTo);
    window.location.href = buildProjectsPath({
      nextInterval: isCustom ? "custom" : nextInterval,
      nextFrom: isCustom ? nextFrom : "",
      nextTo: isCustom ? nextTo : "",
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

  const cardActionClass =
    "inline-flex h-9 w-9 items-center justify-center rounded-lg bg-surface-content/5 text-surface-content/70 transition-colors duration-200 hover:bg-surface-content/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60";
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
      <p class="text-base font-medium text-yellow">
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

  <div class="sm:max-w-3xs">
    <IntervalSelect
      from={from || ""}
      selected={interval || ""}
      to={to || ""}
      onchange={changeInterval}
    />
  </div>

  {#if projects_data}
    <section class="mt-6">
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
      {:else}
        <div
          class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6"
        >
          {#each projects_data.projects as project (project.id)}
            <article
              class="flex h-full flex-col gap-4 rounded-xl border border-primary bg-dark p-6 shadow-lg backdrop-blur-sm transition-all duration-300"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <h3
                    class="truncate text-lg font-semibold text-surface-content"
                    title={project.name}
                  >
                    {project.name}
                  </h3>
                  {#if project.repository?.stars}
                    <p
                      class="mt-2 inline-flex items-center gap-1 text-sm text-yellow"
                    >
                      <svg
                        class="h-4 w-4 fill-current"
                        viewBox="0 0 20 20"
                        aria-hidden="true"
                      >
                        <path
                          d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
                        />
                      </svg>
                      {project.repository.stars}
                    </p>
                  {/if}
                </div>

                <div class="flex shrink-0 items-center gap-2">
                  {#if project.repository?.homepage}
                    <a
                      href={project.repository.homepage}
                      target="_blank"
                      rel="noopener noreferrer"
                      title="View project website"
                      class={cardActionClass}
                    >
                      <svg
                        class="h-5 w-5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          fill="currentColor"
                          d="M16.36 14c.08-.66.14-1.32.14-2s-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2m-5.15 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95a8.03 8.03 0 0 1-4.33 3.56M14.34 14H9.66c-.1-.66-.16-1.32-.16-2s.06-1.35.16-2h4.68c.09.65.16 1.32.16 2s-.07 1.34-.16 2M12 19.96c-.83-1.2-1.5-2.53-1.91-3.96h3.82c-.41 1.43-1.08 2.76-1.91 3.96M8 8H5.08A7.92 7.92 0 0 1 9.4 4.44C8.8 5.55 8.35 6.75 8 8m-2.92 8H8c.35 1.25.8 2.45 1.4 3.56A8 8 0 0 1 5.08 16m-.82-2C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2s.06 1.34.14 2M12 4.03c.83 1.2 1.5 2.54 1.91 3.97h-3.82c.41-1.43 1.08-2.77 1.91-3.97M18.92 8h-2.95a15.7 15.7 0 0 0-1.38-3.56c1.84.63 3.37 1.9 4.33 3.56M12 2C6.47 2 2 6.5 2 12a10 10 0 0 0 10 10a10 10 0 0 0 10-10A10 10 0 0 0 12 2"
                        />
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
                      <svg
                        class="h-5 w-5"
                        fill="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          fill="currentColor"
                          d="M2.6 10.59L8.38 4.8l1.69 1.7c-.24.85.15 1.78.93 2.23v5.54c-.6.34-1 .99-1 1.73a2 2 0 0 0 2 2a2 2 0 0 0 2-2c0-.74-.4-1.39-1-1.73V9.41l2.07 2.09c-.07.15-.07.32-.07.5a2 2 0 0 0 2 2a2 2 0 0 0 2-2a2 2 0 0 0-2-2c-.18 0-.35 0-.5.07L13.93 7.5a1.98 1.98 0 0 0-1.15-2.34c-.43-.16-.88-.2-1.28-.09L9.8 3.38l.79-.78c.78-.79 2.04-.79 2.82 0l7.99 7.99c.79.78.79 2.04 0 2.82l-7.99 7.99c-.78.79-2.04.79-2.82 0L2.6 13.41c-.79-.78-.79-2.04 0-2.82"
                        />
                      </svg>
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
                      <svg
                        class="h-5 w-5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                        aria-hidden="true"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M16.862 3.487a2.1 2.1 0 0 1 2.97 2.97L9.75 16.54 6 17.25l.71-3.75z"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M14.5 5.85l3.65 3.65"
                        />
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
                      <svg
                        class="h-5 w-5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                        aria-hidden="true"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M10 14l-3-3 3-3"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M7 11h9a4 4 0 0 1 0 8h-2"
                        />
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
                      <svg
                        class="h-5 w-5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                        aria-hidden="true"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M3 7h18l-2 11H5z"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M8 7V4h8v3"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M10 11h4"
                        />
                      </svg>
                    </Button>
                  {/if}
                </div>
              </div>

              <p class="text-2xl font-bold text-primary">
                {project.duration_label}
              </p>

              {#if project.repository?.description}
                <p
                  class="line-clamp-2 text-sm leading-relaxed text-surface-content/70"
                >
                  {project.repository.description}
                </p>
              {/if}

              {#if project.repository?.formatted_languages}
                <p class="flex items-center gap-1 text-sm">
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
                  <span class="truncate text-surface-content/50"
                    >{project.repository.formatted_languages}</span
                  >
                </p>
              {/if}

              {#if project.repository?.last_commit_ago}
                <p class="flex items-center gap-1 text-sm">
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

              {#if project.broken_name}
                <div
                  class="rounded-lg border border-yellow/30 bg-yellow/10 p-3"
                >
                  <p class="text-sm leading-relaxed text-yellow/80">
                    Your editor may be sending invalid project names. Time is
                    shown here but can't be submitted to Hack Club programs.
                  </p>
                </div>
              {/if}

              {#if project.manage_enabled && editingProjectKey === project.project_key && project.update_path}
                <div class="mt-1 border-t border-surface-200/40 pt-4">
                  <form
                    method="post"
                    action={project.update_path}
                    class="space-y-3"
                  >
                    <input type="hidden" name="_method" value="patch" />
                    <input
                      type="hidden"
                      name="authenticity_token"
                      value={csrfToken}
                    />

                    <input
                      type="url"
                      name="project_repo_mapping[repo_url]"
                      bind:value={repoUrlDraft}
                      placeholder="https://github.com/owner/repo"
                      class="w-full rounded-lg border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
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
      <div
        class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6"
      >
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
        <form method="post" action={pendingStatusAction.path} class="m-0">
          <input type="hidden" name="_method" value="patch" />
          <input type="hidden" name="authenticity_token" value={csrfToken} />
          <Button
            type="submit"
            variant="primary"
            class="h-10 w-full text-on-primary"
          >
            {pendingStatusAction.confirmLabel}
          </Button>
        </form>
      </div>
    {/if}
  {/snippet}
</Modal>
