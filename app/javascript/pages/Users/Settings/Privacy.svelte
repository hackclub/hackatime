<script module lang="ts">
  import settingsLayout from "./layout";
  export const layout = settingsLayout;
</script>

<script lang="ts">
  import { Form, router } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import CheckboxField from "../../../components/CheckboxField.svelte";
  import ModalActions from "./components/ModalActions.svelte";
  import { settingsPrivacy, deletionRequests } from "../../../api";

  type Props = {
    user: {
      allow_public_stats_lookup: boolean;
      can_request_deletion: boolean;
    };
    authorized_applications: Array<{
      id: number;
      name: string;
      authorized_at: string;
    }>;
    rotated_api_key?: string | null;
    deletion_reason_details_max_length: number;
  };

  let {
    user,
    authorized_applications,
    rotated_api_key = "",
    deletion_reason_details_max_length,
  }: Props = $props();

  const deletionReasons = [
    "Switching to an alternative",
    "Concerns about my data",
    "Don't see the need to track my time",
    "Couldn't figure out how to install Hackatime",
    "Hackatime is missing stats I want to see",
    "Something else",
  ];

  let allowPublicStatsLookup = $state(false);
  let rotatingApiKey = $state(false);
  let apiKeyCopied = $state(false);
  let rotateApiKeyModalOpen = $state(false);
  let deletionRequestModalOpen = $state(false);
  let deletionReason = $state("");
  let deletionReasonDetails = $state("");
  let canSubmitDeletionRequest = $derived(
    deletionReason.length > 0 && deletionReasonDetails.trim().length > 0,
  );

  $effect(() => {
    allowPublicStatsLookup = user.allow_public_stats_lookup;
  });

  const rotateApiKey = () => {
    if (rotatingApiKey) return;
    rotatingApiKey = true;
    apiKeyCopied = false;
    router.post(
      settingsPrivacy.rotateApiKey.path(),
      {},
      {
        preserveScroll: true,
        onFinish: () => {
          rotatingApiKey = false;
        },
      },
    );
  };

  const copyApiKey = async () => {
    if (!rotated_api_key || typeof navigator === "undefined") return;
    await navigator.clipboard.writeText(rotated_api_key);
    apiKeyCopied = true;
  };
</script>

<svelte:head>
  <title>Privacy & Security - Hackatime Settings</title>
</svelte:head>

<SectionCard
  id="user_privacy"
  title="Public Stats"
  description="Control whether your coding stats can be looked up by other users and public APIs."
>
  <Form
    id="privacy-public-stats-form"
    action={settingsPrivacy.update.path()}
    method="patch"
    class="space-y-3"
    options={{ preserveScroll: true }}
  >
    <CheckboxField
      name="user[allow_public_stats_lookup]"
      bind:checked={allowPublicStatsLookup}
      label="Allow public stats lookup"
    />
  </Form>

  {#snippet footer()}
    <Button type="submit" variant="primary" form="privacy-public-stats-form"
      >Save privacy settings</Button
    >
  {/snippet}
</SectionCard>

<SectionCard
  id="authorized_applications"
  title="Authorized Applications"
  description="Applications that have access to your Hackatime account."
  wide
>
  {#if authorized_applications.length}
    <div class="divide-y divide-surface-200">
      {#each authorized_applications as application (application.id)}
        <div
          class="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0"
        >
          <div class="min-w-0">
            <p class="truncate font-medium text-surface-content">
              {application.name}
            </p>
            <p class="text-sm text-muted">
              Authorized {application.authorized_at}
            </p>
          </div>
          <Button
            type="button"
            variant="surface"
            size="sm"
            onclick={() => {
              if (!confirm("Are you sure?")) return;
              router.delete(
                settingsPrivacy.revokeApplication.path({
                  application_id: application.id,
                }),
                { preserveScroll: true },
              );
            }}
          >
            Revoke
          </Button>
        </div>
      {/each}
    </div>
  {:else}
    <p class="text-sm text-muted">
      You haven't authorized any third-party applications.
    </p>
  {/if}
</SectionCard>

<SectionCard
  id="user_api_key"
  title="API Key"
  description="Rotate your API key if you think it has been exposed."
  hasBody={Boolean(rotated_api_key)}
>
  {#if rotated_api_key}
    <div class="rounded-md border border-surface-200 bg-darker p-3">
      <p class="text-xs font-semibold uppercase tracking-wide text-muted">
        New API key
      </p>
      <code class="mt-2 block break-all text-sm text-surface-content"
        >{rotated_api_key}</code
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
      onclick={() => !rotatingApiKey && (rotateApiKeyModalOpen = true)}
      disabled={rotatingApiKey}
    >
      {rotatingApiKey ? "Rotating..." : "Rotate API key"}
    </Button>
  {/snippet}
</SectionCard>

<SectionCard
  id="delete_account"
  title="Account Deletion"
  description="Request permanent deletion. The account enters a waiting period before final removal."
  tone="danger"
  hasBody={!user.can_request_deletion}
>
  {#if !user.can_request_deletion}
    <p
      class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
    >
      Deletion request is unavailable for this account right now.
    </p>
  {/if}

  {#snippet footer()}
    {#if user.can_request_deletion}
      <Button
        type="button"
        variant="surface"
        class="rounded-md"
        onclick={() => (deletionRequestModalOpen = true)}
      >
        Request deletion
      </Button>
    {/if}
  {/snippet}
</SectionCard>

<Modal
  bind:open={rotateApiKeyModalOpen}
  title="Rotate API key?"
  description="This immediately invalidates your current API key. Any integrations using the old key will stop until updated."
  maxWidth="max-w-md"
  hasActions
>
  {#snippet actions()}
    <ModalActions onCancel={() => (rotateApiKeyModalOpen = false)}>
      {#snippet confirm()}
        <Button
          type="button"
          variant="primary"
          class="h-10 w-full text-on-primary"
          onclick={() => {
            rotateApiKeyModalOpen = false;
            rotateApiKey();
          }}
          disabled={rotatingApiKey}
        >
          {rotatingApiKey ? "Rotating..." : "Rotate key"}
        </Button>
      {/snippet}
    </ModalActions>
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
      action={deletionRequests.create.path()}
      class="m-0"
      options={{ preserveScroll: true }}
    >
      <fieldset class="mb-6 space-y-2.5">
        <legend class="text-sm font-semibold text-surface-content"
          >Choose the closest reason</legend
        >
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
        maxlength={deletion_reason_details_max_length}
        required
        class="block w-full rounded-lg border border-surface-300 bg-darker px-3 py-2 text-sm text-surface-content placeholder:text-muted focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/30"
        placeholder="Tell us anything else we should know."></textarea>

      <div class="mt-5">
        <ModalActions onCancel={() => (deletionRequestModalOpen = false)}>
          {#snippet confirm()}
            <Button
              type="submit"
              variant="primary"
              class="h-10 w-full text-on-primary"
              disabled={!canSubmitDeletionRequest}
            >
              Submit deletion request
            </Button>
          {/snippet}
        </ModalActions>
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
