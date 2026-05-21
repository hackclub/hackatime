<script lang="ts">
  import { Form, router } from "@inertiajs/svelte";
  import { Checkbox } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { PrivacyPageProps } from "./types";
  import { settingsPrivacy, deletionRequests } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    user,
    rotated_api_key = "",
    errors,
  }: PrivacyPageProps = $props();

  const privacyUpdatePath = settingsPrivacy.update.path();
  const rotateApiKeyPath = settingsPrivacy.rotateApiKey.path();
  const createDeletionPath = deletionRequests.create.path();

  const deletionReasons = [
    "Switching to an alternative",
    "Concerns about my data",
    "Don't see the need to track my time",
    "Couldn't figure out how to install Hackatime",
    "Hackatime is missing stats I want to see",
    "Something else",
  ];

  let rotatingApiKey = $state(false);
  let rotatedApiKey = $derived(rotated_api_key || "");
  let rotatedApiKeyError = $state("");
  let apiKeyCopied = $state(false);
  let rotateApiKeyModalOpen = $state(false);
  let deletionRequestModalOpen = $state(false);
  let deletionReason = $state("");
  let deletionReasonDetails = $state("");
  let canSubmitDeletionRequest = $derived(
    deletionReason.length > 0 && deletionReasonDetails.trim().length > 0,
  );

  const rotateApiKey = () => {
    if (rotatingApiKey || typeof window === "undefined") return;

    rotatingApiKey = true;
    rotatedApiKeyError = "";
    apiKeyCopied = false;

    router.post(
      rotateApiKeyPath,
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
  <title>Privacy & Security - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_privacy"
    title="Public Stats"
    description="Control whether your coding stats can be looked up by other users and public APIs."
  >
    <Form
      id="privacy-public-stats-form"
      action={privacyUpdatePath}
      method="patch"
      class="space-y-3"
      options={{ preserveScroll: true }}
    >
      <label class="flex items-center gap-3 text-sm text-surface-content">
        <input type="hidden" name="user[allow_public_stats_lookup]" value="0" />
        <Checkbox.Root
          bind:checked={user.allow_public_stats_lookup}
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
    </Form>

    {#snippet footer()}
      <Button type="submit" variant="primary" form="privacy-public-stats-form">
        Save privacy settings
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

  {#if user.can_request_deletion}
    <SectionCard
      id="delete_account"
      title="Account Deletion"
      description="Request permanent deletion. The account enters a waiting period before final removal."
      tone="danger"
      hasBody={false}
    >
      {#snippet footer()}
        <Button
          type="button"
          variant="surface"
          class="rounded-md"
          onclick={() => (deletionRequestModalOpen = true)}
        >
          Request deletion
        </Button>
      {/snippet}
    </SectionCard>
  {:else}
    <SectionCard
      id="delete_account"
      title="Account Deletion"
      description="Request permanent deletion. The account enters a waiting period before final removal."
      tone="danger"
    >
      <p
        class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
      >
        Deletion request is unavailable for this account right now.
      </p>
    </SectionCard>
  {/if}
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

<Modal
  bind:open={deletionRequestModalOpen}
  title="Why are you deleting your account?"
  description="This helps us understand what to improve before your deletion request starts."
  maxWidth="max-w-lg"
  hasBody
>
  {#snippet body()}
    <Form
      id="account-deletion-request-form"
      method="post"
      action={createDeletionPath}
      class="m-0"
      options={{ preserveScroll: true }}
    >
      <fieldset class="mb-6 space-y-2.5">
        <legend class="text-sm font-semibold text-surface-content">
          Choose the closest reason
        </legend>

        {#each deletionReasons as reason}
          <label class="flex items-center gap-3 text-sm text-surface-content">
            <input
              type="radio"
              name="deletion_request[reason]"
              value={reason}
              bind:group={deletionReason}
              required
              class="deletion-reason-radio h-4 w-4 shrink-0 border border-surface-300 bg-darker focus:outline-none focus:ring-2 focus:ring-primary/40"
            />
            <span>{reason}</span>
          </label>
        {/each}
      </fieldset>

      <label
        class="mb-2 block text-sm font-semibold text-surface-content"
        for="deletion_reason_details"
      >
        Tell us more
      </label>
      <textarea
        id="deletion_reason_details"
        name="deletion_request[reason_details]"
        rows="4"
        bind:value={deletionReasonDetails}
        required
        class="block w-full rounded-lg border border-surface-300 bg-darker px-3 py-2 text-sm text-surface-content placeholder:text-muted focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/30"
        placeholder="Tell us anything else we should know."
      ></textarea>

      <div class="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Button
          type="button"
          variant="dark"
          class="h-10 w-full border border-surface-300 text-muted"
          onclick={() => (deletionRequestModalOpen = false)}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          variant="primary"
          class="h-10 w-full text-on-primary"
          disabled={!canSubmitDeletionRequest}
        >
          Submit deletion request
        </Button>
      </div>
    </Form>
  {/snippet}
</Modal>

<style>
  .deletion-reason-radio {
    appearance: none;
    border-radius: 9999px;
  }

  .deletion-reason-radio:checked {
    border-color: var(--color-primary);
    background: radial-gradient(
      circle,
      var(--color-primary) 42%,
      transparent 46%
    );
  }
</style>
