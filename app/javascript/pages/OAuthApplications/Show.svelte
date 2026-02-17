<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import DestructiveActionModal from "./DestructiveActionModal.svelte";
  import type { OAuthApplicationShowProps } from "./types";

  let {
    page_title,
    heading,
    subheading,
    application,
    secret,
    labels,
    confirmations,
  }: OAuthApplicationShowProps = $props();

  const csrfToken =
    typeof document === "undefined"
      ? ""
      : document
          .querySelector("meta[name='csrf-token']")
          ?.getAttribute("content") || "";

  let copiedValue = $state<string | null>(null);
  let destructiveModalOpen = $state(false);
  let pendingDestructiveAction = $state<"delete" | "rotate" | null>(null);

  const copyValue = async (key: "uid" | "secret") => {
    const value = key === "uid" ? application.uid : secret.value || "";
    if (!value) return;

    try {
      await navigator.clipboard.writeText(value);
      copiedValue = key;
      setTimeout(() => {
        if (copiedValue === key) copiedValue = null;
      }, 1500);
    } catch (_error) {
      copiedValue = null;
    }
  };

  const openDestructiveModal = (action: "delete" | "rotate") => {
    pendingDestructiveAction = action;
    destructiveModalOpen = true;
  };

  const destructiveModalTitle = $derived.by(() => {
    if (pendingDestructiveAction === "delete") {
      return `Delete ${application.name}?`;
    }

    if (pendingDestructiveAction === "rotate") {
      return "Rotate client secret?";
    }

    return "Confirm action";
  });

  const destructiveModalDescription = $derived.by(() => {
    if (pendingDestructiveAction === "delete") {
      return "This permanently deletes the OAuth application and breaks any integrations using it.";
    }

    if (pendingDestructiveAction === "rotate") {
      return confirmations.rotate_secret;
    }

    return "";
  });

  const destructiveActionPath = $derived.by(() => {
    if (pendingDestructiveAction === "delete") return application.destroy_path;
    if (pendingDestructiveAction === "rotate") {
      return application.rotate_secret_path;
    }

    return "";
  });

  const destructiveConfirmLabel = $derived.by(() => {
    if (pendingDestructiveAction === "delete") return "Delete application";
    if (pendingDestructiveAction === "rotate") return "Rotate secret";

    return "Confirm";
  });

  const destructiveMethod = $derived.by(() =>
    pendingDestructiveAction === "delete" ? "delete" : "post",
  );

  const destructiveConfirmStyle = $derived.by(() =>
    pendingDestructiveAction === "delete" ? "danger" : "primary",
  );

</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6">
  <header>
    <h1 class="text-3xl font-bold text-surface-content">{heading}</h1>
    <p class="mt-1 text-sm text-muted">{subheading}</p>
  </header>

  <div class="grid gap-4 lg:grid-cols-[1fr_270px]">
    <section class="space-y-4">
      <article class="rounded-xl border border-surface-200 bg-dark p-5">
        <h2 class="text-lg font-semibold text-surface-content">Credentials</h2>

        <div class="mt-4 space-y-4">
          <div>
            <p class="mb-1 text-xs uppercase tracking-wide text-muted">
              {labels.application_id}
            </p>
            <div class="flex flex-wrap items-center gap-2">
              <code
                class="min-w-0 flex-1 break-all rounded-md border border-surface-200 bg-darker px-3 py-2 font-mono text-xs text-surface-content"
              >
                {application.uid}
              </code>
              <Button
                type="button"
                variant="surface"
                onclick={() => copyValue("uid")}
                >{copiedValue === "uid" ? "Copied" : "Copy"}</Button
              >
            </div>
          </div>

          <div>
            <p class="mb-1 text-xs uppercase tracking-wide text-muted">
              {labels.secret}
            </p>

            {#if secret.hashed}
              <div
                class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
              >
                {labels.secret_hashed}
              </div>
              <p class="mt-2 text-xs text-yellow">
                The secret is only shown once when the application is created.
              </p>
            {:else if secret.value}
              <div class="flex flex-wrap items-center gap-2">
                <code
                  class="min-w-0 flex-1 break-all rounded-md border border-surface-200 bg-darker px-3 py-2 font-mono text-xs text-surface-content"
                >
                  {secret.value}
                </code>
                <Button
                  type="button"
                  variant="surface"
                  onclick={() => copyValue("secret")}
                >
                  {copiedValue === "secret" ? "Copied" : "Copy"}
                </Button>
              </div>
              {#if secret.just_rotated}
                <p class="mt-2 text-xs text-green">
                  Here is your new secret. Store it now because it may not be
                  shown again.
                </p>
              {/if}
            {/if}
          </div>

          <div>
            <p class="mb-1 text-xs uppercase tracking-wide text-muted">
              {labels.scopes}
            </p>
            {#if application.scopes.length > 0}
              <div class="flex flex-wrap gap-1.5">
                {#each application.scopes as scope}
                  <span
                    class="rounded-md border border-primary/30 bg-primary/10 px-2 py-0.5 font-mono text-xs text-primary"
                  >
                    {scope}
                  </span>
                {/each}
              </div>
            {:else}
              <p class="text-sm text-muted">{labels.not_defined}</p>
            {/if}
          </div>

          <div>
            <p class="mb-1 text-xs uppercase tracking-wide text-muted">
              {labels.confidential}
            </p>
            {#if application.confidential}
              <span
                class="inline-flex rounded-full border border-green/40 bg-green/15 px-2 py-0.5 text-xs font-semibold text-green"
              >
                Yes
              </span>
            {:else}
              <span
                class="inline-flex rounded-full border border-yellow/40 bg-yellow/15 px-2 py-0.5 text-xs font-semibold text-yellow"
              >
                No
              </span>
            {/if}
          </div>

          <div>
            <p class="mb-1 text-xs uppercase tracking-wide text-muted">
              Verified
            </p>
            {#if application.verified}
              <span
                class="inline-flex rounded-full border border-green/40 bg-green/15 px-2 py-0.5 text-xs font-semibold text-green"
              >
                Verified
              </span>
            {:else}
              <span
                class="inline-flex rounded-full border border-yellow/40 bg-yellow/15 px-2 py-0.5 text-xs font-semibold text-yellow"
              >
                Unverified
              </span>
            {/if}
          </div>
        </div>
      </article>

      <article class="rounded-xl border border-surface-200 bg-dark p-5">
        <h2 class="text-lg font-semibold text-surface-content">
          {labels.callback_urls}
        </h2>

        {#if application.redirect_uris.length > 0}
          <div class="mt-4 space-y-2">
            {#each application.redirect_uris as redirect}
              <div
                class="flex flex-wrap items-center gap-2 rounded-lg border border-surface-200 bg-darker/70 p-3"
              >
                <code
                  class="min-w-0 flex-1 break-all font-mono text-xs text-surface-content"
                >
                  {redirect.value}
                </code>
                <a
                  href={redirect.authorize_path}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center justify-center rounded-lg border border-green bg-green px-3 py-2 text-xs font-semibold text-on-primary transition-opacity hover:opacity-90"
                >
                  Test auth
                </a>
              </div>
            {/each}
          </div>
        {:else}
          <p class="mt-2 text-sm text-muted">{labels.not_defined}</p>
        {/if}
      </article>
    </section>

    <aside class="h-fit rounded-xl border border-surface-200 bg-dark p-4">
      <h2 class="text-sm font-semibold uppercase tracking-wide text-muted">
        {labels.actions}
      </h2>

      <div class="mt-3 space-y-2">
        <Button href={application.edit_path} variant="primary" class="w-full"
          >Edit application</Button
        >

        <Button
          type="button"
          variant="surface"
          class="w-full !border-red/45 !bg-red/15 !text-red hover:!bg-red/25"
          onclick={() => openDestructiveModal("delete")}
        >
          Delete application
        </Button>

        {#if application.toggle_verified_path}
          <form
            method="post"
            action={application.toggle_verified_path}
            class="w-full"
          >
            <input type="hidden" name="authenticity_token" value={csrfToken} />
            <Button
              type="submit"
              variant="surface"
              class={`w-full ${application.verified ? "!border-yellow/40 !bg-yellow/15 !text-yellow hover:!bg-yellow/25" : "!border-green/45 !bg-green/15 !text-green hover:!bg-green/25"}`}
            >
              {application.verified
                ? "Remove verification"
                : "Verify application"}
            </Button>
          </form>
        {/if}

        <Button
          type="button"
          variant="outlinePrimary"
          class="w-full"
          onclick={() => openDestructiveModal("rotate")}
        >
          Rotate secret
        </Button>

        <Link
          href={application.index_path}
          class="inline-flex w-full items-center justify-center rounded-lg border border-surface-200 bg-surface-100 px-4 py-2 text-sm font-semibold text-surface-content transition-colors hover:bg-surface-200"
        >
          Back to applications
        </Link>
      </div>
    </aside>
  </div>
</div>

<DestructiveActionModal
  bind:open={destructiveModalOpen}
  title={destructiveModalTitle}
  description={destructiveModalDescription}
  actionPath={destructiveActionPath}
  confirmLabel={destructiveConfirmLabel}
  {csrfToken}
  method={destructiveMethod}
  confirmStyle={destructiveConfirmStyle}
/>
