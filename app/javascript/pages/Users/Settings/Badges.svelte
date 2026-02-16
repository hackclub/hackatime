<script lang="ts">
  import Select from "../../../components/Select.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { BadgesPageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    options,
    badges,
    errors,
    admin_tools,
  }: BadgesPageProps = $props();

  const defaultTheme = (themes: string[]) =>
    themes.includes("darcula") ? "darcula" : themes[0] || "default";

  let selectedTheme = $state("default");
  let selectedProject = $state("");

  $effect(() => {
    if (
      options.badge_themes.length > 0 &&
      !options.badge_themes.includes(selectedTheme)
    ) {
      selectedTheme = defaultTheme(options.badge_themes);
    }
  });

  $effect(() => {
    if (badges.projects.length === 0) {
      selectedProject = "";
      return;
    }

    if (!badges.projects.includes(selectedProject)) {
      selectedProject = badges.projects[0];
    }
  });

  const badgeUrl = () => {
    const url = new URL(badges.general_badge_url);
    url.searchParams.set("theme", selectedTheme);
    return url.toString();
  };

  const projectBadgeUrl = () => {
    if (!badges.project_badge_base_url || !selectedProject) return "";
    return `${badges.project_badge_base_url}${encodeURIComponent(selectedProject)}`;
  };
</script>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
  {admin_tools}
>
  <div class="space-y-8">
    <section id="user_stats_badges">
      <h2 class="text-xl font-semibold text-surface-content">Stats Badges</h2>
      <p class="mt-1 text-sm text-muted">
        Generate links for profile badges that display your coding stats.
      </p>

      <div class="mt-4 space-y-4">
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
            items={options.badge_themes.map((theme) => ({
              value: theme,
              label: theme,
            }))}
          />
        </div>

        <div class="rounded-md border border-surface-200 bg-darker p-4">
          <img
            src={badgeUrl()}
            alt="General coding stats badge preview"
            class="max-w-full rounded"
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
              value: project,
              label: project,
            }))}
          />
          <div class="mt-4 rounded-md border border-surface-200 bg-darker p-4">
            <img
              src={projectBadgeUrl()}
              alt="Project stats badge preview"
              class="max-w-full rounded"
            />
            <pre
              class="mt-3 overflow-x-auto text-xs text-surface-content">{projectBadgeUrl()}</pre>
          </div>
        </div>
      {/if}
    </section>

    <section id="user_markscribe">
      <h2 class="text-xl font-semibold text-surface-content">
        Markscribe Template
      </h2>
      <p class="mt-1 text-sm text-muted">
        Use this snippet with markscribe to include your coding stats in a
        README.
      </p>
      <div class="mt-4 rounded-md border border-surface-200 bg-darker p-4">
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
        class="mt-4 w-full max-w-3xl rounded-md border border-surface-200"
      />
    </section>
  </div>
</SettingsShell>
