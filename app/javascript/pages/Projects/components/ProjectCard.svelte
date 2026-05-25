<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Archive from "hcicons-svelte/archive";
  import Clock from "hcicons-svelte/clock";
  import Edit from "hcicons-svelte/edit";
  import GithubFill from "hcicons-svelte/github-fill";
  import Reply from "hcicons-svelte/reply";
  import Terminal from "hcicons-svelte/terminal";
  import Web from "hcicons-svelte/web";
  import Button from "../../../components/Button.svelte";
  import { myProjectRepoMappings } from "../../../api";
  import type { ProjectCard } from "../types";

  let {
    project,
    showArchived,
    intervalQueryString,
    onEditMapping,
    onArchive,
    onShowBrokenInfo,
    editing,
    repoUrlDraft = $bindable(""),
    onCancelEdit,
  }: {
    project: ProjectCard;
    showArchived: boolean;
    intervalQueryString: string;
    onEditMapping: (project: ProjectCard) => void;
    onArchive: (project: ProjectCard, restoring: boolean) => void;
    onShowBrokenInfo: () => void;
    editing: boolean;
    repoUrlDraft?: string;
    onCancelEdit: () => void;
  } = $props();

  const key = $derived(project.url_safe ? project.project_key : null);
  const showPath = $derived(
    key ? myProjectRepoMappings.show.path({ projectName: key }) : null,
  );
  const updatePath = $derived(
    key ? myProjectRepoMappings.update.path({ projectName: key }) : null,
  );
  const projectHref = $derived(
    showPath
      ? `${showPath}${intervalQueryString ? `?${intervalQueryString}` : ""}`
      : null,
  );

  const actionClass =
    "inline-flex h-10 w-10 items-center justify-center rounded-xl border border-surface-200/60 bg-surface-content/5 text-surface-content/70 shadow-sm transition-colors duration-200 ease-out hover:bg-surface-content/10 hover:text-surface-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60 cursor-pointer";
  const chipClass =
    "flex items-center gap-1.5 rounded-full bg-surface-content/5 px-3 py-1.5";
</script>

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
        <h3
          class="min-w-0 flex-1 truncate text-xl font-bold tracking-tight text-surface-content"
          title={project.name}
        >
          {project.name}
        </h3>
        <p class="shrink-0 text-lg font-semibold tabular-nums text-primary/80">
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
            class={actionClass}
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
            class={actionClass}
          >
            <GithubFill size={20} />
          </a>
        {/if}
        {#if project.manage_enabled}
          <Button
            type="button"
            unstyled
            class={actionClass}
            title={project.repo_url ? "Edit mapping" : "Link repository"}
            onclick={() => onEditMapping(project)}
          >
            <Edit size={20} />
          </Button>
        {/if}
        {#if key && showArchived}
          <Button
            type="button"
            unstyled
            class={actionClass}
            title="Restore project"
            onclick={() => onArchive(project, true)}
          >
            <Reply size={20} />
          </Button>
        {:else if key && !showArchived}
          <Button
            type="button"
            unstyled
            class={actionClass}
            title="Archive project"
            onclick={() => onArchive(project, false)}
          >
            <Archive size={20} />
          </Button>
        {/if}
      </div>
    </div>

    <div
      class="mt-auto flex flex-wrap items-center gap-2 pt-5 text-sm text-surface-content/55"
    >
      {#if project.repository?.formatted_languages}
        <p class="{chipClass} min-w-0">
          <Terminal size={16} class="text-surface-content/50" />
          <span class="truncate text-surface-content/60"
            >{project.repository.formatted_languages}</span
          >
        </p>
      {/if}

      {#if project.repository?.last_commit_ago}
        <p class={chipClass}>
          <Clock size={16} class="text-surface-content/50" />
          <span class="text-surface-content/50"
            >Last commit {project.repository.last_commit_ago}</span
          >
        </p>
      {/if}
    </div>

    {#if project.broken_name}
      <Button
        type="button"
        unstyled
        class="mt-4 block w-full cursor-pointer rounded-2xl border border-yellow/30 bg-yellow/10 p-3 text-left hover:bg-yellow/15"
        onclick={onShowBrokenInfo}
      >
        <p class="text-sm leading-relaxed text-yellow/80 text-pretty">
          Time can't be used in Hack Club programs
          <span class="underline underline-offset-2 hover:text-yellow">
            (why?)
          </span>
        </p>
      </Button>
    {/if}

    {#if editing && updatePath}
      <div class="relative z-20 mt-4 border-t border-surface-200/40 pt-4">
        <Form action={updatePath} method="patch" class="space-y-3">
          <input
            type="url"
            name="project_repo_mapping[repo_url]"
            bind:value={repoUrlDraft}
            placeholder="https://github.com/owner/repo"
            class="w-full rounded-lg border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
          />
          <div class="flex gap-2">
            <Button type="submit" variant="primary" size="sm" class="flex-1"
              >Save</Button
            >
            <Button
              type="button"
              variant="dark"
              size="sm"
              class="flex-1"
              onclick={onCancelEdit}
            >
              Cancel
            </Button>
          </div>
        </Form>
      </div>
    {/if}
  </div>
</article>
