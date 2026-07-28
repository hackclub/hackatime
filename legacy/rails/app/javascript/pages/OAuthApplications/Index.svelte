<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import DestructiveActionModal from "./DestructiveActionModal.svelte";
  import Badge from "./components/Badge.svelte";
  import ChipList from "./components/ChipList.svelte";
  import Field from "./components/Field.svelte";
  import type { OAuthApplicationsIndexProps } from "./types";
  import { doorkeeperApplications } from "../../api";

  let { page_title, applications }: OAuthApplicationsIndexProps = $props();

  const newApplicationPath = doorkeeperApplications.new.path();

  let deleteModalOpen = $state(false);
  let pendingDelete = $state<{ name: string; path: string } | null>(null);

  const openDeleteModal = (name: string, path: string) => {
    pendingDelete = { name, path };
    deleteModalOpen = true;
  };
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="space-y-6">
  <header class="flex flex-wrap items-start justify-between gap-3">
    <div class="min-w-0">
      <h1
        class="text-2xl sm:text-3xl font-bold text-surface-content mb-1 sm:mb-2"
      >
        Your applications
      </h1>
      <p class="text-sm sm:text-base text-muted">
        Manage your OAuth applications that integrate with Hackatime.
      </p>
    </div>

    {#if applications.length > 0}
      <Button href={newApplicationPath} variant="primary"
        >New application</Button
      >
    {/if}
  </header>

  {#if applications.length > 0}
    <div class="space-y-3">
      {#each applications as application (application.id)}
        <article
          class="rounded-xl border border-surface-200 bg-dark p-4 sm:p-5"
        >
          <div
            class="flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-start sm:justify-between"
          >
            <div class="min-w-0 flex-1 space-y-3">
              <div class="flex flex-wrap items-center gap-2">
                <h2 class="truncate text-lg font-semibold text-surface-content">
                  {application.name}
                </h2>
                {#if application.verified}
                  <Badge tone="green">Verified</Badge>
                {/if}
                {#if application.confidential}
                  <Badge tone="primary">Confidential</Badge>
                {/if}
              </div>

              <div class="space-y-2">
                <Field label="Callback URLs">
                  <div class="mt-1">
                    <ChipList
                      items={application.redirect_uris}
                      empty="No callback URLs configured."
                      variant="uri"
                    />
                  </div>
                </Field>
                <Field label="Scopes">
                  <div class="mt-1">
                    <ChipList
                      items={application.scopes}
                      empty="No scopes configured."
                    />
                  </div>
                </Field>
              </div>
            </div>

            <div class="flex flex-wrap items-center gap-2">
              <Link
                href={doorkeeperApplications.show.path({ id: application.id })}
                class="inline-flex flex-1 items-center justify-center rounded-lg border border-surface-200 bg-surface-100 px-3 py-2 text-sm font-medium text-surface-content transition-colors hover:bg-surface-200 sm:flex-none"
              >
                View
              </Link>
              <Link
                href={doorkeeperApplications.edit.path({ id: application.id })}
                class="inline-flex flex-1 items-center justify-center rounded-lg border border-primary bg-primary px-3 py-2 text-sm font-medium text-on-primary transition-opacity hover:opacity-90 sm:flex-none"
              >
                Edit
              </Link>
              <Button
                type="button"
                variant="surface"
                class="!flex-1 !border-red/45 !bg-red/15 !text-red hover:!bg-red/25 sm:!flex-none"
                onclick={() =>
                  openDeleteModal(
                    application.name,
                    doorkeeperApplications.destroy.path({ id: application.id }),
                  )}
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
      class="rounded-xl border border-surface-200 bg-dark p-6 text-center sm:p-10"
    >
      <h2 class="text-xl font-semibold text-surface-content">
        No applications yet
      </h2>
      <p class="mt-2 text-sm text-muted">
        Create your first OAuth application to start integrating with Hackatime.
      </p>
      <div class="mt-5">
        <Button href={newApplicationPath} variant="primary"
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
  method="delete"
  confirmStyle="danger"
/>
