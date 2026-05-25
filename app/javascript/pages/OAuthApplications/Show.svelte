<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import DestructiveActionModal from "./DestructiveActionModal.svelte";
  import Badge from "./components/Badge.svelte";
  import ChipList from "./components/ChipList.svelte";
  import CopyableCode from "./components/CopyableCode.svelte";
  import Field from "./components/Field.svelte";
  import type { OAuthApplicationShowProps } from "./types";
  import {
    doorkeeperApplications,
    adminOauthApplications,
    customDoorkeeperAuthorizations,
  } from "../../api";

  let {
    page_title,
    heading,
    subheading,
    application,
    secret,
    labels,
    confirmations,
  }: OAuthApplicationShowProps = $props();

  const id = $derived(application.id);
  const toggleVerifiedPath = $derived(
    application.can_toggle_verified
      ? adminOauthApplications.toggleVerified.path({ id })
      : null,
  );

  const authorizePathFor = (uri: string) =>
    customDoorkeeperAuthorizations.new.path({
      query: {
        client_id: application.uid,
        redirect_uri: uri,
        response_type: "code",
        scope: application.scopes.join(" "),
      },
    });

  type ActionKey = "delete" | "rotate";
  let modalOpen = $state(false);
  let pending = $state<ActionKey | null>(null);

  const modal = $derived(
    pending === "delete"
      ? {
          title: `Delete ${application.name}?`,
          description:
            "This permanently deletes the OAuth application and breaks any integrations using it.",
          actionPath: doorkeeperApplications.destroy.path({ id }),
          confirmLabel: "Delete application",
          method: "delete" as const,
          confirmStyle: "danger" as const,
        }
      : pending === "rotate"
        ? {
            title: "Rotate client secret?",
            description: confirmations.rotate_secret,
            actionPath: doorkeeperApplications.rotateSecret.path({ id }),
            confirmLabel: "Rotate secret",
            method: "post" as const,
            confirmStyle: "primary" as const,
          }
        : {
            title: "Confirm action",
            description: "",
            actionPath: "",
            confirmLabel: "Confirm",
            method: "post" as const,
            confirmStyle: "primary" as const,
          },
  );

  const openModal = (action: ActionKey) => {
    pending = action;
    modalOpen = true;
  };

  const dangerBtn =
    "w-full border-red/45! bg-red/15! text-red! hover:bg-red/25!";
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
          <Field label={labels.application_id}>
            <CopyableCode value={application.uid} />
          </Field>

          <Field label={labels.secret}>
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
              <CopyableCode value={secret.value} />
              {#if secret.just_rotated}
                <p class="mt-2 text-xs text-green">
                  Here is your new secret. Store it now because it may not be
                  shown again.
                </p>
              {/if}
            {/if}
          </Field>

          <Field label={labels.scopes}>
            <ChipList items={application.scopes} empty={labels.not_defined} />
          </Field>

          <Field label={labels.confidential}>
            <Badge tone={application.confidential ? "green" : "yellow"}>
              {application.confidential ? "Yes" : "No"}
            </Badge>
          </Field>

          <Field label="Verified">
            <Badge tone={application.verified ? "green" : "yellow"}>
              {application.verified ? "Verified" : "Unverified"}
            </Badge>
          </Field>
        </div>
      </article>

      <article class="rounded-xl border border-surface-200 bg-dark p-5">
        <h2 class="text-lg font-semibold text-surface-content">
          {labels.callback_urls}
        </h2>

        {#if application.redirect_uris.length > 0}
          <div class="mt-4 space-y-2">
            {#each application.redirect_uris as uri}
              <div
                class="flex flex-wrap items-center gap-2 rounded-lg border border-surface-200 bg-darker/70 p-3"
              >
                <code
                  class="min-w-0 flex-1 break-all font-mono text-xs text-surface-content"
                >
                  {uri}
                </code>
                <a
                  href={authorizePathFor(uri)}
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
        <Button
          href={doorkeeperApplications.edit.path({ id })}
          variant="primary"
          class="w-full">Edit application</Button
        >

        <Button
          type="button"
          variant="surface"
          class={dangerBtn}
          onclick={() => openModal("delete")}>Delete application</Button
        >

        <Button
          type="button"
          variant="surface"
          class={dangerBtn}
          onclick={() => openModal("rotate")}>Rotate secret</Button
        >

        {#if toggleVerifiedPath}
          <Form action={toggleVerifiedPath} method="post" class="w-full">
            <Button
              type="submit"
              variant="surface"
              class={`w-full ${application.verified ? "border-yellow/40! bg-yellow/40! text-yellow! hover:bg-yellow/60!" : "!border-green/45 bg-green/40! !text-green! hover:bg-green/60!"}`}
            >
              {application.verified
                ? "Remove verification"
                : "Verify application"}
            </Button>
          </Form>
        {/if}

        <Link
          href={doorkeeperApplications.index.path()}
          class="inline-flex w-full items-center justify-center rounded-lg border border-surface-200 bg-surface-100 px-4 py-2 text-sm font-semibold text-surface-content transition-colors hover:bg-surface-200"
        >
          Back to applications
        </Link>
      </div>
    </aside>
  </div>
</div>

<DestructiveActionModal bind:open={modalOpen} {...modal} />
