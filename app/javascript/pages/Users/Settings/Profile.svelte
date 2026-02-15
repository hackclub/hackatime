<script lang="ts">
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
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
  let selectedTheme = $state(user.theme || "standard");

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

        <Button
          type="submit"
          variant="primary"
        >
          Save region settings
        </Button>
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
            <p class="mt-2 text-xs text-red">{errors.username[0]}</p>
          {/if}
        </div>

        <Button
          type="submit"
          variant="primary"
        >
          Save username
        </Button>
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

        <Button
          type="submit"
          variant="primary"
        >
          Save privacy settings
        </Button>
      </form>
    </section>

    <section id="user_theme">
      <h2 class="text-xl font-semibold text-surface-content">Theme</h2>
      <p class="mt-1 text-sm text-muted">
        Pick how Hackatime looks for your account.
      </p>
      <form method="post" action={settings_update_path} class="mt-4 space-y-4">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          {#each options.themes as theme}
            {@const isSelected = selectedTheme === theme.value}
            <label
              class={`block cursor-pointer rounded-xl border p-4 transition-colors ${
                isSelected
                  ? "border-primary bg-surface-100"
                  : "border-surface-200 bg-darker/40 hover:border-surface-300"
              }`}
            >
              <input
                type="radio"
                name="user[theme]"
                value={theme.value}
                checked={isSelected}
                class="sr-only"
                onchange={() => (selectedTheme = theme.value)}
              />

              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-surface-content">{theme.label}</p>
                  <p class="mt-1 text-xs text-muted">{theme.description}</p>
                </div>
                {#if isSelected}
                  <span class="rounded-full bg-primary/20 px-2 py-0.5 text-xs font-medium text-primary">
                    Selected
                  </span>
                {/if}
              </div>

              <div
                class="mt-3 rounded-lg border p-2"
                style={`background:${theme.preview.darker};border-color:${theme.preview.darkless};color:${theme.preview.content};`}
              >
                <div
                  class="flex items-center justify-between rounded-md px-2 py-1"
                  style={`background:${theme.preview.dark};`}
                >
                  <span class="text-[11px] font-semibold">Dashboard</span>
                  <span class="text-[10px] opacity-80">2h 14m</span>
                </div>

                <div class="mt-2 grid grid-cols-[1fr_auto] items-center gap-2">
                  <span class="h-2 rounded" style={`background:${theme.preview.primary};`}></span>
                  <span class="h-2 w-8 rounded" style={`background:${theme.preview.darkless};`}></span>
                </div>

                <div class="mt-2 flex gap-1.5">
                  <span class="h-1.5 w-6 rounded" style={`background:${theme.preview.info};`}></span>
                  <span class="h-1.5 w-6 rounded" style={`background:${theme.preview.success};`}></span>
                  <span class="h-1.5 w-6 rounded" style={`background:${theme.preview.warning};`}></span>
                </div>
              </div>
            </label>
          {/each}
        </div>

        <Button
          type="submit"
          variant="primary"
        >
          Save theme
        </Button>
      </form>
    </section>
  </div>
</SettingsShell>
