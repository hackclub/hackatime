<script lang="ts">
  import { Form, Link, router } from "@inertiajs/svelte";
  import Archive from "hcicons-svelte/archive";
  import Edit from "hcicons-svelte/edit";
  import GithubFill from "hcicons-svelte/github-fill";
  import Reply from "hcicons-svelte/reply";
  import Web from "hcicons-svelte/web";
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

  const skeletonCount = $derived.by(() => {
    const safeCount = Number.isFinite(total_projects) ? total_projects : 0;
    return Math.min(Math.max(safeCount, 4), 10);
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
          class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-5"
        >
          {#each projects_data.projects as project (project.id)}
            {@const projectHref = project.show_path || null}
            <article
              class="group relative flex min-h-36 overflow-hidden rounded-2xl {projectHref
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
                class="relative flex min-w-0 flex-1 flex-col rounded-2xl border border-surface-200 bg-dark p-5 transition-colors duration-300 ease-out group-hover:border-surface-300"
              >
                <div class="grid gap-3">
                  <div class="flex min-w-0 items-start justify-between gap-3">
                    <div class="min-w-0 flex-1">
                      <h3
                        class="truncate text-xl font-bold tracking-tight text-surface-content"
                        title={project.name}
                      >
                        {project.name}
                      </h3>
                    </div>
                    <p
                      class="shrink-0 text-lg font-semibold tabular-nums text-primary/80"
                    >
                      {project.duration_label}
                    </p>
                  </div>

                  {#if project.repository?.description}
                    <p
                      class="line-clamp-2 text-sm leading-relaxed text-surface-content/70 text-pretty"
                    >
                      {project.repository.description}
                    </p>
                  {/if}

                  <div class="relative z-20 flex flex-wrap items-center gap-2">
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
                        onclick={() => openStatusChangeModal(project, false)}
                      >
                        <Archive size={20} />
                      </Button>
                    {/if}
                  </div>
                </div>

                <div
                  class="mt-auto flex flex-wrap items-center gap-2 pt-5 text-sm text-surface-content/55"
                >
                  <!-- {#if project.repository?.stars}
                    <p
                      class="inline-flex items-center gap-1.5 rounded-full bg-yellow/10 px-3 py-1.5 font-semibold tabular-nums text-yellow"
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
                  {/if} -->

                  {#if project.repository?.formatted_languages}
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

                  {#if project.repository?.last_commit_ago}
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

                {#if project.broken_name}
                  <div
                    class="mt-4 rounded-2xl border border-yellow/30 bg-yellow/10 p-3"
                  >
                    <p
                      class="text-sm leading-relaxed text-yellow/80 text-pretty"
                    >
                      Your editor may be sending invalid project names. Time is
                      shown here but can't be submitted to Hack Club programs.
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
  {:else}
    <section class="mt-6 animate-pulse">
      <div class="h-7 w-80 rounded bg-darkless"></div>
      <div
        class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-5"
      >
        {#each Array.from({ length: skeletonCount }) as _unused, index (index)}
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
