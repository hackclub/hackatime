<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import { deletionRequests, sessions } from "../../api";

  type DeletionRequestProps = {
    status: string;
    status_label: string;
    requested_at: string;
    scheduled_deletion_at?: string | null;
    days_until_deletion?: number | null;
    can_be_cancelled: boolean;
  };

  let { deletion_request }: { deletion_request: DeletionRequestProps } =
    $props();

  const signoutPath = sessions.destroy.path();
  const cancelDeletionPath = deletionRequests.cancel.path();
  const isPending = $derived(deletion_request.status === "pending");
  const isApproved = $derived(deletion_request.status === "approved");
</script>

<svelte:head>
  <title>Account Deletion Pending - Hackatime</title>
</svelte:head>

<div class="mx-auto w-full max-w-2xl py-8">
  <header class="mb-6">
    <h1
      class="text-2xl sm:text-3xl font-bold tracking-tight text-surface-content text-balance"
    >
      Account scheduled for deletion
    </h1>
    <p class="mt-1 text-muted text-pretty">We're sorry to see you go!</p>
  </header>

  <div class="rounded-2xl border border-surface-200 bg-dark p-6">
    <dl class="divide-y divide-surface-200/60">
      <div class="flex items-center justify-between gap-4 pb-4">
        <dt class="text-sm text-muted">Status</dt>
        <dd>
          <span
            class={`rounded-full px-2.5 py-1 text-xs font-medium tabular-nums ${isApproved ? "bg-green/15 text-green" : "bg-yellow/15 text-yellow"}`}
          >
            {deletion_request.status_label}
          </span>
        </dd>
      </div>

      {#if isApproved && deletion_request.scheduled_deletion_at}
        <div class="flex items-center justify-between gap-4 py-4">
          <dt class="text-sm text-muted">Deletion date</dt>
          <dd class="text-right text-sm font-semibold tabular-nums text-red">
            {deletion_request.scheduled_deletion_at}
            <span class="font-normal text-muted">
              ({deletion_request.days_until_deletion} days remaining)
            </span>
          </dd>
        </div>
      {/if}
    </dl>

    {#if isPending}
      <p
        class="border-l-2 border-yellow/70 pl-3 text-sm leading-relaxed text-yellow/90 text-pretty"
      >
        Your deletion request is pending approval. We'll review it and get back
        to you as soon as possible.
      </p>
    {:else if isApproved && deletion_request.scheduled_deletion_at}
      <p
        class="border-l-2 border-red/70 pl-3 text-sm leading-relaxed text-red/90 text-pretty"
      >
        Your account will be permanently deleted on {deletion_request.scheduled_deletion_at}.
        After deletion, your email address will be retained on file, but all
        other personal information will be removed or anonymized.
      </p>
    {/if}

    <div class="mt-6">
      <h3 class="text-sm font-semibold text-surface-content">
        Important information
      </h3>
      <ul
        class="mt-2 space-y-1.5 text-sm leading-relaxed text-muted text-pretty"
      >
        <li>
          During the 30-day waiting period, you cannot upload data, download
          data, or use your account for Hack Club programs.
        </li>
        <li>
          You can cancel this request at any time before the deletion date.
        </li>
        <li>
          After deletion, your email address will be retained to prevent ban
          evasion.
        </li>
      </ul>
    </div>
  </div>

  <div class="mt-5 grid grid-cols-1 items-center gap-3 sm:grid-cols-[1fr_auto]">
    <Form action={signoutPath} method="delete" class="w-full">
      <Button type="submit" variant="dark" class="w-full sm:w-auto">
        Return to login
      </Button>
    </Form>

    {#if deletion_request.can_be_cancelled}
      <Form action={cancelDeletionPath} method="delete" class="w-full">
        <Button type="submit" variant="primary" class="w-full sm:w-auto">
          I changed my mind
        </Button>
      </Form>
    {/if}
  </div>
</div>
