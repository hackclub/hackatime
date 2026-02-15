<script lang="ts">
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { AdminPageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    admin_tools,
    paths,
    errors,
  }: AdminPageProps = $props();

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
  {#if admin_tools.visible}
    <div class="space-y-8">
      <section id="wakatime_mirror">
        <h2 class="text-xl font-semibold text-surface-content">WakaTime Mirrors</h2>
        <p class="mt-1 text-sm text-muted">
          Mirror heartbeats to external WakaTime-compatible endpoints.
        </p>

        {#if admin_tools.mirrors.length > 0}
          <div class="mt-4 space-y-2">
            {#each admin_tools.mirrors as mirror}
              <div class="rounded-md border border-surface-200 bg-darker p-3">
                <p class="text-sm font-semibold text-surface-content">
                  {mirror.endpoint_url}
                </p>
                <p class="mt-1 text-xs text-muted">Last synced: {mirror.last_synced_ago}</p>
                <form
                  method="post"
                  action={mirror.destroy_path}
                  class="mt-3"
                  onsubmit={(event) => {
                    if (!window.confirm("Delete this mirror endpoint?")) {
                      event.preventDefault();
                    }
                  }}
                >
                  <input type="hidden" name="_method" value="delete" />
                  <input type="hidden" name="authenticity_token" value={csrfToken} />
                  <Button
                    type="submit"
                    variant="surface"
                    size="xs"
                  >
                    Delete
                  </Button>
                </form>
              </div>
            {/each}
          </div>
        {/if}

        <form method="post" action={paths.user_wakatime_mirrors_path} class="mt-5 space-y-3">
          <input type="hidden" name="authenticity_token" value={csrfToken} />
          <div>
            <label for="endpoint_url" class="mb-2 block text-sm text-surface-content">
              Endpoint URL
            </label>
            <input
              id="endpoint_url"
              type="url"
              name="wakatime_mirror[endpoint_url]"
              value="https://wakatime.com/api/v1"
              required
              class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
            />
          </div>
          <div>
            <label for="mirror_key" class="mb-2 block text-sm text-surface-content">
              WakaTime API Key
            </label>
            <input
              id="mirror_key"
              type="password"
              name="wakatime_mirror[encrypted_api_key]"
              required
              class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
            />
          </div>
          <Button
            type="submit"
            variant="primary"
          >
            Add mirror
          </Button>
        </form>
      </section>
    </div>
  {:else}
    <p class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
      You are not authorized to access this section.
    </p>
  {/if}
</SettingsShell>
