<script lang="ts">
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { AccessPageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    settings_update_path,
    user,
    options,
    paths,
    config_file,
    errors,
    admin_tools,
  }: AccessPageProps = $props();

  let csrfToken = $state("");
  let rotatingApiKey = $state(false);
  let rotatedApiKey = $state("");
  let rotatedApiKeyError = $state("");
  let apiKeyCopied = $state(false);

  const rotateApiKey = async () => {
    if (rotatingApiKey || typeof window === "undefined") return;

    const confirmed = window.confirm(
      "Rotate your API key now? This immediately invalidates the current key.",
    );
    if (!confirmed) return;

    rotatingApiKey = true;
    rotatedApiKey = "";
    rotatedApiKeyError = "";
    apiKeyCopied = false;

    try {
      const response = await fetch(paths.rotate_api_key_path, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({}),
      });

      const body = await response.json();
      if (!response.ok || !body.token) {
        throw new Error(body.error || "Unable to rotate API key.");
      }

      rotatedApiKey = body.token;
    } catch (error) {
      rotatedApiKeyError =
        error instanceof Error ? error.message : "Unable to rotate API key.";
    } finally {
      rotatingApiKey = false;
    }
  };

  const copyApiKey = async () => {
    if (!rotatedApiKey || typeof navigator === "undefined") return;
    await navigator.clipboard.writeText(rotatedApiKey);
    apiKeyCopied = true;
  };

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
    <section>
      <h2 class="text-xl font-semibold text-surface-content">Time Tracking Setup</h2>
      <p class="mt-1 text-sm text-muted">
        Use the setup guide if you are configuring a new editor or device.
      </p>
      <Button
        href={paths.wakatime_setup_path}
        class="mt-4"
      >
        Open setup guide
      </Button>
    </section>

    <section id="user_hackatime_extension">
      <h2 class="text-xl font-semibold text-surface-content">Extension Display</h2>
      <p class="mt-1 text-sm text-muted">
        Choose how coding time appears in the extension status text.
      </p>
      <form method="post" action={settings_update_path} class="mt-4 space-y-4">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <div>
          <label for="extension_type" class="mb-2 block text-sm text-surface-content">
            Display style
          </label>
          <select
            id="extension_type"
            name="user[hackatime_extension_text_type]"
            value={user.hackatime_extension_text_type}
            class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
          >
            {#each options.extension_text_types as textType}
              <option value={textType.value}>{textType.label}</option>
            {/each}
          </select>
        </div>

        <Button
          type="submit"
          variant="primary"
        >
          Save extension settings
        </Button>
      </form>
    </section>

    <section id="user_api_key">
      <h2 class="text-xl font-semibold text-surface-content">API Key</h2>
      <p class="mt-1 text-sm text-muted">
        Rotate your API key if you think it has been exposed.
      </p>
      <Button
        type="button"
        class="mt-4"
        onclick={rotateApiKey}
        disabled={rotatingApiKey}
      >
        {rotatingApiKey ? "Rotating..." : "Rotate API key"}
      </Button>

      {#if rotatedApiKeyError}
        <p class="mt-3 rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red">
          {rotatedApiKeyError}
        </p>
      {/if}

      {#if rotatedApiKey}
        <div class="mt-4 rounded-md border border-surface-200 bg-darker p-3">
          <p class="text-xs font-semibold uppercase tracking-wide text-muted">
            New API key
          </p>
          <code class="mt-2 block break-all text-sm text-surface-content">{rotatedApiKey}</code>
          <Button
            type="button"
            variant="surface"
            size="xs"
            class="mt-3"
            onclick={copyApiKey}
          >
            {apiKeyCopied ? "Copied" : "Copy key"}
          </Button>
        </div>
      {/if}
    </section>

    <section id="user_config_file">
      <h2 class="text-xl font-semibold text-surface-content">WakaTime Config File</h2>
      <p class="mt-1 text-sm text-muted">
        Copy this into your <code class="rounded bg-darker px-1 py-0.5 text-xs">~/.wakatime.cfg</code> file.
      </p>

      {#if config_file.has_api_key && config_file.content}
        <pre class="mt-4 overflow-x-auto rounded-md border border-surface-200 bg-darker p-4 text-xs text-surface-content">{config_file.content}</pre>
      {:else}
        <p class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
          {config_file.empty_message}
        </p>
      {/if}
    </section>
  </div>
</SettingsShell>
