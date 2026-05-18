<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { BadgesPageProps } from "./types";
  import { settingsPrivacy } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    badge_themes,
    badges,
    allow_public_stats_lookup,
    errors,
  }: BadgesPageProps = $props();

  // Public stats live on the Privacy controller; toggle via that endpoint.
  const privacyUpdatePath = settingsPrivacy.update.path();

  function enablePublicStats() {
    router.patch(
      privacyUpdatePath,
      {
        user: { allow_public_stats_lookup: true },
      },
      { preserveScroll: true },
    );
  }

  const defaultTheme = (themes: string[]) =>
    themes.includes("darcula") ? "darcula" : themes[0] || "default";

  let selectedTheme = $state("default");
  let selectedProject = $state<string>("");

  $effect(() => {
    if (badge_themes.length > 0 && !badge_themes.includes(selectedTheme)) {
      selectedTheme = defaultTheme(badge_themes);
    }
  });

  $effect(() => {
    if (badges.projects.length === 0) {
      selectedProject = "";
      return;
    }

    const projectRepoPath = badges.projects.find(
      (p) => p.repo_path === selectedProject,
    );
    if (!projectRepoPath) {
      selectedProject = badges.projects[0]?.repo_path || "";
    }
  });

  const badgeUrl = () => {
    const url = new URL(badges.general_badge_url);
    url.searchParams.set("theme", selectedTheme);
    return url.toString();
  };

  const projectBadgeUrl = () => {
    if (!badges.project_badge_base_url || !selectedProject) return "";
    // selectedProject is already in owner/repo format
    return `${badges.project_badge_base_url}${selectedProject}`;
  };
</script>

<svelte:head>
  <title>Badges - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  {#if !allow_public_stats_lookup}
    <div
      class="rounded-2xl border border-warning/30 bg-warning/10 p-4 text-sm text-surface-content"
    >
      <p class="font-medium">Public stats are disabled</p>
      <p class="mt-1 text-muted">
        Badges require public stats to be enabled so they can be viewed by
        others. Enable public stats to use badges.
      </p>
      <Button
        onclick={enablePublicStats}
        variant="primary"
        size="sm"
        class="mt-3"
      >
        Enable public stats
      </Button>
    </div>
  {/if}

  <div
    class={allow_public_stats_lookup
      ? "space-y-5"
      : "space-y-5 pointer-events-none opacity-50"}
  >
    <SectionCard
      id="user_stats_badges"
      title="Stats Badges"
      description="Generate links for profile badges that display your coding stats."
      wide
    >
      <div class="space-y-4">
        <div>
          <label
            for="badge_theme"
            class="mb-2 block text-sm text-surface-content"
          >
            Theme
          </label>
          <Select
            id="badge_theme"
            bind:value={selectedTheme}
            items={badge_themes.map((theme) => ({
              value: theme,
              label: theme,
            }))}
          />
        </div>

        <div class="rounded-md border border-surface-200 bg-darker p-4">
          <img
            src={badgeUrl()}
            alt="General coding stats badge preview"
            class="settings-image-outline max-w-full rounded"
          />
          <pre
            class="mt-3 overflow-x-auto text-xs text-surface-content">{badgeUrl()}</pre>
        </div>
      </div>

      {#if badges.projects.length > 0 && badges.project_badge_base_url}
        <div class="mt-6 border-t border-surface-200 pt-6">
          <label
            for="badge_project"
            class="mb-2 block text-sm text-surface-content"
          >
            Project
          </label>
          <Select
            id="badge_project"
            bind:value={selectedProject}
            items={badges.projects.map((project) => ({
              value: project.repo_path,
              label: project.display_name,
            }))}
          />
          <div class="mt-4 rounded-md border border-surface-200 bg-darker p-4">
            <img
              src={projectBadgeUrl()}
              alt="Project stats badge preview"
              class="settings-image-outline max-w-full rounded"
            />
            <pre
              class="mt-3 overflow-x-auto text-xs text-surface-content">{projectBadgeUrl()}</pre>
          </div>
        </div>
      {/if}
    </SectionCard>

    <SectionCard
      id="user_markscribe"
      title="Markscribe Template"
      description="Use this snippet with markscribe to include your coding stats in a README."
      wide
    >
      <div class="rounded-md border border-surface-200 bg-darker p-4">
        <pre
          class="overflow-x-auto text-sm text-surface-content">{badges.markscribe_template}</pre>
      </div>
      <p class="mt-3 text-sm text-muted">
        Reference:
        <a
          href={badges.markscribe_reference_url}
          target="_blank"
          class="text-primary underline"
        >
          markscribe template docs
        </a>
      </p>
      <img
        src={badges.markscribe_preview_image_url}
        alt="Example markscribe output"
        class="settings-image-outline mt-4 w-full max-w-3xl rounded-md"
      />
    </SectionCard>

    <SectionCard
      id="user_heatmap"
      title="Activity Heatmap"
      description="A customizable heatmap for your coding activity."
      wide
    >
      <p class="text-sm text-muted">
        Configuration:
        <a
          class="text-primary underline"
          href={badges.heatmap_config_url}
          target="_blank">open heatmap builder</a
        >
      </p>
      <div class="mt-4 rounded-md border border-surface-200 bg-darker p-4 pb-3">
        <a href={badges.heatmap_config_url} target="_blank" class="block">
          <img
            src={badges.heatmap_badge_url}
            alt="Heatmap badge preview"
            class="settings-image-outline max-w-full"
          />
        </a>
        <pre
          class="mt-2 overflow-x-auto text-xs text-surface-content">{badges.heatmap_badge_url}</pre>
      </div>
    </SectionCard>
    <SectionCard
      id="user_hackabox"
      title="Hackabox Gist"
      description="Fork the Hackabox template repository to create a pinned profile gist with your coding stats, updated daily."
      wide
    >
      <p class="mt-3 text-sm text-muted">
        Reference:
        <a
          href={badges.hackabox_repo_url}
          target="_blank"
          class="text-primary underline"
        >
          hackabox setup instructions
        </a>
      </p>
      <img
        src={badges.hackabox_preview_image_url}
        alt="Example hackabox output"
        class="settings-image-outline mt-4 w-full max-w-3xl rounded-md"
      />
    </SectionCard>
  </div>
</SettingsShell>
