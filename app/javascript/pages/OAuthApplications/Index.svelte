<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import DestructiveActionModal from "./DestructiveActionModal.svelte";
  import type { OAuthApplicationsIndexProps } from "./types";

  let {
    page_title,
    heading,
    subheading,
    new_application_path,
    applications,
  }: OAuthApplicationsIndexProps = $props();

  const csrfToken =
    typeof document === "undefined"
      ? ""
      : document
          .querySelector("meta[name='csrf-token']")
          ?.getAttribute("content") || "";

  let deleteModalOpen = $state(false);
  let pendingDelete = $state<{ name: string; path: string } | null>(null);

  const openDeleteModal = (applicationName: string, destroyPath: string) => {
    pendingDelete = { name: applicationName, path: destroyPath };
    deleteModalOpen = true;
  };

</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6">
  <header class="flex flex-wrap items-start justify-between gap-3">
    <div>
      <h1 class="text-3xl font-bold text-surface-content">{heading}</h1>
      <p class="mt-1 text-sm text-muted">{subheading}</p>
    </div>

    <Button href={new_application_path} variant="primary"
      >New application</Button
    >
  </header>

  {#if applications.length > 0}
    <div class="space-y-3">
      {#each applications as application (application.id)}
        <article class="rounded-xl border border-surface-200 bg-dark p-5">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="min-w-0 flex-1 space-y-3">
              <div class="flex flex-wrap items-center gap-2">
                <h2 class="truncate text-lg font-semibold text-surface-content">
                  {application.name}
                </h2>

                {#if application.verified}
                  <span
                    class="rounded-full border border-green/40 bg-green/15 px-2 py-0.5 text-xs font-semibold text-green"
                  >
                    Verified
                  </span>
                {/if}

                {#if application.confidential}
                  <span
                    class="rounded-full border border-primary/35 bg-primary/12 px-2 py-0.5 text-xs font-semibold text-primary"
                  >
                    Confidential
                  </span>
                {/if}
              </div>

              <div class="space-y-2">
                <div>
                  <p class="text-xs uppercase tracking-wide text-muted">
                    Callback URLs
                  </p>
                  {#if application.redirect_uris.length > 0}
                    <div class="mt-1 flex flex-wrap gap-1.5">
                      {#each application.redirect_uris as uri}
                        <span
                          class="max-w-full truncate rounded-md border border-surface-200 bg-darker px-2 py-1 font-mono text-xs text-surface-content"
                        >
                          {uri}
                        </span>
                      {/each}
                    </div>
                  {:else}
                    <p class="mt-1 text-sm text-muted">
                      No callback URLs configured.
                    </p>
                  {/if}
                </div>

                <div>
                  <p class="text-xs uppercase tracking-wide text-muted">
                    Scopes
                  </p>
                  {#if application.scopes.length > 0}
                    <div class="mt-1 flex flex-wrap gap-1.5">
                      {#each application.scopes as scope}
                        <span
                          class="rounded-md border border-primary/30 bg-primary/10 px-2 py-0.5 font-mono text-xs text-primary"
                        >
                          {scope}
                        </span>
                      {/each}
                    </div>
                  {:else}
                    <p class="mt-1 text-sm text-muted">No scopes configured.</p>
                  {/if}
                </div>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <Link
                href={application.show_path}
                class="inline-flex items-center justify-center rounded-lg border border-surface-200 bg-surface-100 px-3 py-2 text-sm font-medium text-surface-content transition-colors hover:bg-surface-200"
              >
                View
              </Link>
              <Link
                href={application.edit_path}
                class="inline-flex items-center justify-center rounded-lg border border-primary bg-primary px-3 py-2 text-sm font-medium text-on-primary transition-opacity hover:opacity-90"
              >
                Edit
              </Link>

              <Button
                type="button"
                variant="surface"
                class="!border-red/45 !bg-red/15 !text-red hover:!bg-red/25"
                onclick={() =>
                  openDeleteModal(application.name, application.destroy_path)}
              >
                Delete
              </Button>
            </div>
          </div>
        </article>
      {/each}
    </div>
  {:else}
    <section
      class="rounded-xl border border-surface-200 bg-dark p-10 text-center"
    >
      <h2 class="text-xl font-semibold text-surface-content">
        No applications yet
      </h2>
      <p class="mt-2 text-sm text-muted">
        Create your first OAuth application to start integrating with Hackatime.
      </p>
      <div class="mt-5">
        <Button href={new_application_path} variant="primary"
          >New application</Button
        >
      </div>
    </section>
  {/if}
</div>

<DestructiveActionModal
  bind:open={deleteModalOpen}
  title={pendingDelete
    ? `Delete ${pendingDelete.name}?`
    : "Delete OAuth application?"}
  description="This action permanently deletes the OAuth application and any integrations using it will stop working."
  actionPath={pendingDelete?.path || ""}
  confirmLabel="Delete application"
  {csrfToken}
  method="delete"
  confirmStyle="danger"
/>
