<script lang="ts">
  import { Link, router } from "@inertiajs/svelte";
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
    projects_data,
  }: {
    page_title: string;
    show_archived: boolean;
    archived_count: number;
    github_connected: boolean;
    interval?: string | null;
    from?: string | null;
    to?: string | null;
    interval_label: string;
    projects_data: {
      total_time_label: string;
      has_activity: boolean;
      projects: ProjectCardType[];
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

  const changeInterval = (
    nextInterval: string,
    nextFrom: string,
    nextTo: string,
  ) => {
    const q = buildIntervalChange(nextInterval, nextFrom, nextTo);
    if (show_archived) q.set("show_archived", "true");
    const qs = q.toString();
    router.visit(qs ? `${indexPath}?${qs}` : indexPath, {
      only: ["projects_data", "interval", "from", "to", "interval_label"],
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
    ).path({ projectName: project.project_key });

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

  <div class="sm:max-w-3xs">
    <IntervalSelect
      from={from || ""}
      selected={interval || ""}
      to={to || ""}
      onchange={changeInterval}
    />
  </div>

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

    {#if !github_connected}
      <div class="mt-4 rounded-xl border border-yellow/30 bg-yellow/10 p-4">
        <p class="text-base font-medium text-surface-content">
          Heads up! You can't link projects to GitHub until you connect your
          account.
        </p>
        <div class="mt-3 flex flex-wrap gap-2">
          <Button href={githubAuthPath} native class="w-full sm:w-fit">
            Sign in with GitHub
          </Button>
          <Button href={settingsPath} variant="surface" class="w-full sm:w-fit">
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
    {:else}
      <div
        class="mt-6 grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-5"
      >
        {#each projects_data.projects as project (project.id)}
          <ProjectCard
            {project}
            showArchived={show_archived}
            {intervalQueryString}
            onEditMapping={openMappingEditor}
            onArchive={openStatusChangeModal}
            onShowBrokenInfo={() => (brokenNameModalOpen = true)}
            editing={editingProjectKey === project.project_key}
            bind:repoUrlDraft
            onCancelEdit={closeMappingEditor}
          />
        {/each}
      </div>
    {/if}
  </section>
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
