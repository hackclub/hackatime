<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import PageIcon from "../../../components/PageIcon.svelte";
  import { adminOauthApplications, profiles } from "../../../api";

  type Application = {
    id: number;
    name: string;
    verified: boolean;
    redirect_uris: string[];
    created_at: string;
    owner: { id: number; username: string | null; display_name: string } | null;
  };
  let { applications }: { applications: Application[] } = $props();
  const path = (id: number) => adminOauthApplications.show.path({ id });
</script>

<svelte:head><title>All OAuth Applications - Admin</title></svelte:head>
<div class="max-w-6xl mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">
      All OAuth Applications
    </h1>
    <p class="text-secondary text-lg">
      Manage all OAuth applications across all users
    </p>
  </header>
  {#if applications.length}
    <div class="grid grid-cols-1 gap-4">
      {#each applications as app (app.id)}
        <div
          id={`application_${app.id}`}
          class="border border-primary rounded-xl p-6 bg-dark"
        >
          <div
            class="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4"
          >
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-3 mb-3">
                <div class="p-2 bg-primary/10 rounded">
                  <PageIcon name="monitor" class="w-6 h-6 text-primary" />
                </div>
                <div class="flex items-center gap-2">
                  <Link
                    href={path(app.id)}
                    class="text-xl font-semibold text-surface-content hover:text-primary transition-colors"
                    >{app.name}</Link
                  >{#if app.verified}<span
                      class="inline-flex items-center gap-1 px-2 py-0.5 bg-green/20 text-green border border-green/30 rounded text-xs"
                      ><PageIcon name="check" class="w-3 h-3" /> Verified</span
                    >{/if}
                </div>
              </div>
              <div class="space-y-2">
                <div class="flex items-center gap-2">
                  <span class="text-secondary text-sm">Owner:</span
                  >{#if app.owner?.username}<Link
                      href={profiles.show.path({
                        username: app.owner.username,
                      })}
                      class="text-surface-content hover:text-primary"
                      >@{app.owner.username}</Link
                    >{:else if app.owner}<span class="text-surface-content"
                      >{app.owner.display_name || `User #${app.owner.id}`}</span
                    >{:else}<span class="text-yellow text-sm">No owner</span
                    >{/if}
                </div>
                <div class="flex items-start gap-2">
                  <span class="text-secondary text-sm shrink-0"
                    >Callback URLs:</span
                  >
                  <div class="text-surface-content/80 text-sm break-all">
                    {#each app.redirect_uris as uri}<span
                        class="inline-block bg-darkless px-2 py-0.5 rounded text-xs mb-1"
                        >{uri}</span
                      >{/each}
                  </div>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-secondary text-sm">Created:</span><span
                    class="text-surface-content/80 text-sm"
                    >{app.created_at}</span
                  >
                </div>
              </div>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <Button href={path(app.id)} variant="dark" size="sm">View</Button
              ><Form
                action={adminOauthApplications.toggleVerified.path({
                  id: app.id,
                })}
                method="post"
                ><Button
                  type="submit"
                  class={app.verified
                    ? "bg-yellow hover:bg-yellow/80"
                    : "bg-green hover:bg-green/80"}
                  >{app.verified ? "Unverify" : "Verify"}</Button
                ></Form
              >
            </div>
          </div>
        </div>{/each}
    </div>
  {:else}<div class="border border-primary rounded-xl p-12 bg-dark text-center">
      <div class="p-4 bg-primary/10 rounded-full inline-block mb-4">
        <PageIcon name="monitor" class="w-12 h-12 text-primary" />
      </div>
      <h3 class="text-xl font-semibold text-surface-content mb-2">
        No applications
      </h3>
      <p class="text-secondary">No OAuth applications have been created yet.</p>
    </div>{/if}
</div>
