<script lang="ts">
  import { onMount } from "svelte";
  import SettingsShell from "./Shell.svelte";
  import type { ProfilePageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    settings_update_path,
    username_max_length,
    user,
    options,
    badges,
    errors,
    admin_tools,
  }: ProfilePageProps = $props();

  let csrfToken = $state("");

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";
  });
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
    <section id="user_region">
      <h2 class="text-xl font-semibold text-surface-content">Region and Timezone</h2>
      <p class="mt-1 text-sm text-muted">
        Use your local region and timezone for accurate dashboards and
        leaderboards.
      </p>
      <form method="post" action={settings_update_path} class="mt-4 space-y-4">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <div>
          <label for="country_code" class="mb-2 block text-sm text-surface-content">
            Country
          </label>
          <select
            id="country_code"
            name="user[country_code]"
            class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
            value={user.country_code || ""}
          >
            <option value="">Select a country</option>
            {#each options.countries as country}
              <option value={country.value}>{country.label}</option>
            {/each}
          </select>
        </div>

        <div id="user_timezone">
          <label for="timezone" class="mb-2 block text-sm text-surface-content">
            Timezone
          </label>
          <select
            id="timezone"
            name="user[timezone]"
            class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
            value={user.timezone}
          >
            {#each options.timezones as timezone}
              <option value={timezone.value}>{timezone.label}</option>
            {/each}
          </select>
        </div>

        <button
          type="submit"
          class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
        >
          Save region settings
        </button>
      </form>
    </section>

    <section id="user_username">
      <h2 class="text-xl font-semibold text-surface-content">Username</h2>
      <p class="mt-1 text-sm text-muted">
        This username is used in links and public profile pages.
      </p>
      <form method="post" action={settings_update_path} class="mt-4 space-y-3">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <div>
          <label for="username" class="mb-2 block text-sm text-surface-content">
            Username
          </label>
          <input
            id="username"
            name="user[username]"
            value={user.username || ""}
            maxlength={username_max_length}
            placeholder="your-name"
            class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
          />
          {#if errors.username.length > 0}
            <p class="mt-2 text-xs text-red-300">{errors.username[0]}</p>
          {/if}
        </div>

        <button
          type="submit"
          class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
        >
          Save username
        </button>
      </form>

      {#if badges.profile_url}
        <p class="mt-3 text-sm text-muted">
          Public profile:
          <a
            href={badges.profile_url}
            target="_blank"
            class="text-primary underline"
          >
            {badges.profile_url}
          </a>
        </p>
      {/if}
    </section>

    <section id="user_privacy">
      <h2 class="text-xl font-semibold text-surface-content">Privacy</h2>
      <p class="mt-1 text-sm text-muted">
        Control whether your coding stats can be used by public APIs.
      </p>
      <form method="post" action={settings_update_path} class="mt-4 space-y-3">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <label class="flex items-center gap-3 text-sm text-surface-content">
          <input type="hidden" name="user[allow_public_stats_lookup]" value="0" />
          <input
            type="checkbox"
            name="user[allow_public_stats_lookup]"
            value="1"
            checked={user.allow_public_stats_lookup}
            class="h-4 w-4 rounded border-surface-200 bg-darker text-primary"
          />
          Allow public stats lookup
        </label>

        <button
          type="submit"
          class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
        >
          Save privacy settings
        </button>
      </form>
    </section>
  </div>
</SettingsShell>
