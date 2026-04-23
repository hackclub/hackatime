<script lang="ts">
  import { Checkbox, RadioGroup } from "bits-ui";
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { ProfilePageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    region_update_path,
    privacy_update_path,
    username_update_path,
    theme_update_path,
    username_max_length,
    user,
    options,
    profile_url,
    errors,
  }: ProfilePageProps = $props();

  let csrfToken = $state("");
  let selectedTheme = $state("rose");
  let allowPublicStatsLookup = $state(false);

  $effect(() => {
    selectedTheme = user.theme || "rose";
    allowPublicStatsLookup = user.allow_public_stats_lookup;
  });

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";
  });
</script>

<svelte:head>
  <title>Profile - Hackatime Settings</title>
</svelte:head>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
>
  <SectionCard
    id="user_region"
    title="Region and Timezone"
    description="Use your local region and timezone for accurate dashboards and leaderboards."
  >
    <form
      id="profile-region-form"
      method="post"
      action={region_update_path}
      class="space-y-4"
    >
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken} />

      <div>
        <label
          for="country_code"
          class="mb-2 block text-sm text-surface-content"
        >
          Country
        </label>
        <Select
          id="country_code"
          name="user[country_code]"
          value={user.country_code || ""}
          items={[
            { value: "", label: "Select a country" },
            ...options.countries,
          ]}
        />
      </div>

      <div id="user_timezone">
        <label for="timezone" class="mb-2 block text-sm text-surface-content">
          Timezone
        </label>
        <Select
          id="timezone"
          name="user[timezone]"
          value={user.timezone}
          items={options.timezones}
        />
      </div>
    </form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-region-form">
        Save region settings
      </Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_username"
    title="Username"
    description="This username is used in links and public profile pages."
  >
    <form
      id="profile-username-form"
      method="post"
      action={username_update_path}
      class="space-y-3"
    >
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
    </form>

    {#if profile_url}
      <p class="text-sm text-muted">
        Public profile:
        <a href={profile_url} target="_blank" class="text-primary underline">
          {profile_url}
        </a>
      </p>
    {/if}

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-username-form">
        Save username
      </Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_privacy"
    title="Privacy"
    description="Control whether your coding stats can be used by public APIs."
  >
    <form
      id="profile-privacy-form"
      method="post"
      action={privacy_update_path}
      class="space-y-3"
    >
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken} />

      <label class="flex items-center gap-3 text-sm text-surface-content">
        <input type="hidden" name="user[allow_public_stats_lookup]" value="0" />
        <Checkbox.Root
          bind:checked={allowPublicStatsLookup}
          name="user[allow_public_stats_lookup]"
          value="1"
          class="inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border border-surface-200 bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary"
        >
          {#snippet children({ checked })}
            <span class={checked ? "text-[10px]" : "hidden"}>✓</span>
          {/snippet}
        </Checkbox.Root>
        Allow public stats lookup
      </label>
    </form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-privacy-form">
        Save privacy settings
      </Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_theme"
    title="Theme"
    description="Pick how Hackatime looks for your account."
    wide
  >
    <form
      id="profile-theme-form"
      method="post"
      action={theme_update_path}
      class="space-y-4"
    >
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken} />

      <RadioGroup.Root
        name="user[theme]"
        bind:value={selectedTheme}
        class="grid grid-cols-1 gap-4 md:grid-cols-2"
      >
        {#each options.themes as theme}
          <RadioGroup.Item
            value={theme.value}
            class="block cursor-pointer rounded-xl border p-4 text-left outline-none transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-surface-100 data-[state=unchecked]:border-surface-200 data-[state=unchecked]:bg-darker/40 data-[state=unchecked]:hover:border-surface-300"
          >
            {#snippet children({ checked })}
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-surface-content">
                    {theme.label}
                  </p>
                  <p class="mt-1 text-xs text-muted">{theme.description}</p>
                </div>
                {#if checked}
                  <span
                    class="rounded-full bg-primary/20 px-2 py-0.5 text-xs font-medium text-primary"
                  >
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
                  <span
                    class="h-2 rounded"
                    style={`background:${theme.preview.primary};`}
                  ></span>
                  <span
                    class="h-2 w-8 rounded"
                    style={`background:${theme.preview.darkless};`}
                  ></span>
                </div>

                <div class="mt-2 flex gap-1.5">
                  <span
                    class="h-1.5 w-6 rounded"
                    style={`background:${theme.preview.info};`}
                  ></span>
                  <span
                    class="h-1.5 w-6 rounded"
                    style={`background:${theme.preview.success};`}
                  ></span>
                  <span
                    class="h-1.5 w-6 rounded"
                    style={`background:${theme.preview.warning};`}
                  ></span>
                </div>
              </div>
            {/snippet}
          </RadioGroup.Item>
        {/each}
      </RadioGroup.Root>
    </form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="profile-theme-form">
        Save theme
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>
