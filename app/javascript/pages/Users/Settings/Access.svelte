<script lang="ts">
  import { Form, router } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import Select from "../../../components/Select.svelte";
  import SectionCard from "./components/SectionCard.svelte";
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
    rotated_api_key = "",
    errors,
  }: AccessPageProps = $props();

  let rotatingApiKey = $state(false);
  let rotatedApiKey = $derived(rotated_api_key || "");
  let rotatedApiKeyError = $state("");
  let apiKeyCopied = $state(false);
  let rotateApiKeyModalOpen = $state(false);

  const rotateApiKey = () => {
    if (rotatingApiKey || typeof window === "undefined") return;

    rotatingApiKey = true;
    rotatedApiKeyError = "";
    apiKeyCopied = false;

    router.post(
      paths.rotate_api_key_path,
      {},
      {
        preserveScroll: true,
        onError: () => {
          rotatedApiKeyError = "Unable to rotate API key.";
        },
        onFinish: () => {
          rotatingApiKey = false;
        },
      },
    );
  };

  const openRotateApiKeyModal = () => {
    if (rotatingApiKey) return;
    rotateApiKeyModalOpen = true;
  };

  const confirmRotateApiKey = () => {
    rotateApiKeyModalOpen = false;
    rotateApiKey();
  };

  const copyApiKey = async () => {
    if (!rotatedApiKey || typeof navigator === "undefined") return;
    await navigator.clipboard.writeText(rotatedApiKey);
    apiKeyCopied = true;
  };
</script>

<svelte:head>
  <title>Access - Hackatime Settings</title>
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
    id="user_tracking_setup"
    title="Time Tracking Setup"
    description="Use the setup guide if you are configuring a new editor or device."
  >
    <p class="text-sm text-muted">
      Hackatime uses the WakaTime plugin ecosystem, so the setup guide covers
      editor installation, API keys, and API URL configuration.
    </p>

    {#snippet footer()}
      <Button href={paths.wakatime_setup_path}>Open setup guide</Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_hackatime_extension"
    title="Extension Display"
    description="Choose how coding time appears in the extension status text."
  >
    <Form
      id="access-extension-form"
      action={settings_update_path}
      method="patch"
      class="space-y-4"
    >
      <div>
        <label
          for="extension_type"
          class="mb-2 block text-sm text-surface-content"
        >
          Display style
        </label>
        <Select
          id="extension_type"
          name="user[hackatime_extension_text_type]"
          value={user.hackatime_extension_text_type}
          items={options.extension_text_types}
        />
      </div>
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="access-extension-form">
        Save extension settings
      </Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_api_key"
    title="API Key"
    description="Rotate your API key if you think it has been exposed."
    hasBody={Boolean(rotatedApiKeyError || rotatedApiKey)}
  >
    {#if rotatedApiKeyError}
      <p
        class="rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red"
      >
        {rotatedApiKeyError}
      </p>
    {/if}

    {#if rotatedApiKey}
      <div class="rounded-md border border-surface-200 bg-darker p-3">
        <p class="text-xs font-semibold uppercase tracking-wide text-muted">
          New API key
        </p>
        <code class="mt-2 block break-all text-sm text-surface-content"
          >{rotatedApiKey}</code
        >
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

    {#snippet footer()}
      <Button
        type="button"
        onclick={openRotateApiKeyModal}
        disabled={rotatingApiKey}
      >
        {rotatingApiKey ? "Rotating..." : "Rotate API key"}
      </Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_config_file"
    title="WakaTime Config File"
    description="Copy this into your ~/.wakatime.cfg file."
    wide
  >
    {#if config_file.has_api_key && config_file.content}
      <pre
        class="overflow-x-auto rounded-md border border-surface-200 bg-darker p-4 text-xs text-surface-content">{config_file.content}</pre>
    {:else}
      <p
        class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
      >
        {config_file.empty_message}
      </p>
    {/if}
  </SectionCard>
</SettingsShell>

<Modal
  bind:open={rotateApiKeyModalOpen}
  title="Rotate API key?"
  description="This immediately invalidates your current API key. Any integrations using the old key will stop until updated."
  maxWidth="max-w-md"
  hasActions
>
  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted"
        onclick={() => (rotateApiKeyModalOpen = false)}
      >
        Cancel
      </Button>
      <Button
        type="button"
        variant="primary"
        class="h-10 w-full text-on-primary"
        onclick={confirmRotateApiKey}
        disabled={rotatingApiKey}
      >
        {rotatingApiKey ? "Rotating..." : "Rotate key"}
      </Button>
    </div>
  {/snippet}
</Modal>
