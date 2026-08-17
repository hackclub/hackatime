<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import AdminUserMention from "../../../components/AdminUserMention.svelte";
  import DetailField from "../../../components/DetailField.svelte";
  import PageIcon from "../../../components/PageIcon.svelte";
  import CopyableCode from "../../OAuthApplications/components/CopyableCode.svelte";
  import { adminOauthApplications, doorkeeperApplications } from "../../../api";
  type Application = {
    id: number;
    name: string;
    uid: string;
    verified: boolean;
    confidential: boolean;
    redirect_to_hca_login: boolean;
    scopes: string[];
    redirect_uris: string[];
    created_at: string;
    owner: {
      id: number;
      display_name: string;
      avatar_url: string | null;
      can_impersonate: boolean;
    } | null;
  };
  let {
    application,
    secret,
  }: { application: Application; secret: string | null } = $props();
  const action =
    "w-full inline-flex items-center justify-center gap-2 px-4 py-2 text-on-primary font-medium rounded transition-colors duration-200";
</script>

<svelte:head
  ><title>{application.name} - Admin OAuth Application</title></svelte:head
>
<div class="max-w-4xl mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">
      {application.name}
      {#if application.verified}<span
          class="inline-flex items-center gap-1 px-3 py-1 bg-green/20 text-green border border-green/30 rounded text-sm ml-2 align-middle"
          ><PageIcon name="check" class="w-4 h-4" /> Verified</span
        >{/if}
    </h1>
    <p class="text-secondary text-lg">Admin view of OAuth application</p>
  </header>
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <div class="lg:col-span-2 space-y-6">
      <section class="border border-primary rounded-xl p-6 bg-dark">
        <div class="mb-6 flex items-center gap-3">
          <div class="rounded bg-primary/10 p-2">
            <PageIcon name="user" class="h-6 w-6 text-primary" />
          </div>
          <h2 class="text-xl font-semibold text-surface-content">
            Owner Information
          </h2>
        </div>
        {#if application.owner}<div
            class="flex items-center gap-2 p-4 bg-darkless rounded-lg"
          >
            <AdminUserMention user={application.owner} />
          </div>{:else}<div
            class="p-4 bg-yellow/10 border border-yellow/30 rounded-lg text-yellow"
          >
            This application has no owner assigned.
          </div>{/if}
      </section>
      <section class="border border-primary rounded-xl p-6 bg-dark">
        <div class="mb-6 flex items-center gap-3">
          <div class="rounded bg-primary/10 p-2">
            <PageIcon name="key" class="h-6 w-6 text-primary" />
          </div>
          <h2 class="text-xl font-semibold text-surface-content">
            Application Details
          </h2>
        </div>
        <div class="space-y-5">
          <DetailField label="Application ID" variant="secondary">
            <code
              class="block break-all rounded border border-darkless bg-darkless px-3 py-2 font-mono text-sm text-surface-content"
              >{application.uid}</code
            >
          </DetailField>
          <DetailField label="Scopes" variant="secondary">
            {#if application.scopes.length}<div class="flex flex-wrap gap-2">
                {#each application.scopes as scope}<span
                    class="px-2 py-1 bg-primary/20 text-primary border border-primary/30 rounded text-sm font-mono"
                    >{scope}</span
                  >{/each}
              </div>{:else}<span class="text-secondary italic text-sm"
                >No scopes defined</span
              >{/if}
          </DetailField>
          {#if secret}<DetailField label="Client Secret" variant="secondary">
              <CopyableCode value={secret} />
              <p class="mt-2 text-xs text-green">
                ✓ New secret generated! Copy it now - it won't be shown again.
              </p>
            </DetailField>{/if}
          <DetailField label="Confidential" variant="secondary">
            <span
              class={`inline-flex items-center gap-1.5 rounded border px-2 py-1 text-sm ${application.confidential ? "border-green/30 bg-green/20 text-green" : "border-yellow/30 bg-yellow/20 text-yellow"}`}
              ><PageIcon
                name={application.confidential ? "check" : "warning"}
                class="h-4 w-4"
              />
              {application.confidential
                ? "Yes - Confidential"
                : "No - Public Client"}</span
            >
          </DetailField>
          <DetailField label="Login Redirect" variant="secondary">
            <span
              class={`inline-flex items-center gap-1.5 rounded border px-2 py-1 text-sm ${application.redirect_to_hca_login ? "border-green/30 bg-green/20 text-green" : "border-yellow/30 bg-yellow/20 text-yellow"}`}
              >{application.redirect_to_hca_login
                ? "Hack Club Auth"
                : "Hackatime sign in"}</span
            >
          </DetailField>
          <DetailField label="Created" variant="secondary">
            <span class="text-surface-content">{application.created_at}</span>
          </DetailField>
        </div>
      </section>
      <section class="border border-primary rounded-xl p-6 bg-dark">
        <div class="mb-6 flex items-center gap-3">
          <div class="rounded bg-primary/10 p-2">
            <PageIcon name="link" class="h-6 w-6 text-primary" />
          </div>
          <h2 class="text-xl font-semibold text-surface-content">
            Callback URLs
          </h2>
        </div>
        {#if application.redirect_uris.length}<div class="space-y-3">
            {#each application.redirect_uris as uri}<code
                class="block p-3 bg-darkless border border-darkless rounded text-surface-content font-mono text-sm break-all"
                >{uri}</code
              >{/each}
          </div>{:else}<p class="text-secondary italic">
            No callback URLs defined
          </p>{/if}
      </section>
    </div>
    <aside class="space-y-3 border border-primary rounded-xl p-6 bg-dark h-fit">
      <h3 class="text-lg font-semibold text-surface-content mb-4">
        Admin Actions
      </h3>
      <Form
        action={adminOauthApplications.toggleVerified.path({
          id: application.id,
        })}
        method="post"
        ><Button
          unstyled
          type="submit"
          class={`${action} ${application.verified ? "bg-yellow" : "bg-green"}`}
          ><PageIcon
            name={application.verified ? "warning" : "check"}
            class="h-5 w-5"
          />
          {application.verified
            ? "Remove Verification"
            : "Verify Application"}</Button
        ></Form
      >
      <Form
        action={adminOauthApplications.rotateSecret.path({
          id: application.id,
        })}
        method="post"
        onsubmit={(e: SubmitEvent) => {
          if (
            !confirm(
              "Are you sure? This will invalidate the current client secret. Any integrations using the old secret will stop working.",
            )
          )
            e.preventDefault();
        }}
        ><Button unstyled type="submit" class={`${action} bg-yellow`}
          ><PageIcon name="rotate" class="h-5 w-5" /> Rotate Secret</Button
        ></Form
      >
      <Button
        unstyled
        href={adminOauthApplications.edit.path({ id: application.id })}
        class={`${action} bg-primary hover:opacity-90`}
        ><PageIcon name="edit" class="h-5 w-5" /> Edit Application</Button
      ><Button
        unstyled
        href={doorkeeperApplications.show.path({ id: application.id })}
        class="inline-flex w-full items-center justify-center gap-2 rounded border border-primary px-4 py-2 font-medium text-primary transition-colors duration-200 hover:bg-primary/75"
        ><PageIcon name="eye" class="h-5 w-5" /> View as Owner</Button
      ><Link
        href={adminOauthApplications.index.path()}
        class="inline-flex w-full items-center justify-center gap-2 rounded border border-darkless px-4 py-2 font-medium text-surface-content transition-colors duration-200 hover:bg-darkless"
        ><PageIcon name="arrow-left" class="h-5 w-5" /> Back to All Applications</Link
      >
    </aside>
  </div>
</div>
