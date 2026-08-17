<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import { adminDeletionRequests } from "../../../api";
  type User = {
    display_name: string;
    avatar_url: string;
    email: string;
    trust_level: string;
  };
  type Request = {
    id: number;
    user: User;
    approver: string;
    requested_at?: string;
    approved_at?: string;
    deletion_at?: string;
    days?: number;
  };
  type Done = { user_id: number; approver: string; completed_at: string };
  let {
    pending,
    approved,
    done,
  }: { pending: Request[]; approved: Request[]; done: Done[] } = $props();
  const trust: Record<string, string> = {
    green: "bg-green/20 text-green",
    yellow: "bg-yellow/20 text-yellow",
    red: "bg-red/20 text-red",
  };
</script>

<svelte:head><title>gdpr nerds</title></svelte:head>
<div class="max-w-6xl mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">gdpr nerds</h1>
  </header>
  <section class="border border-primary rounded-xl p-6 bg-dark">
    <h2 class="text-2xl font-semibold text-yellow mb-4">
      approval queue ({pending.length})
    </h2>
    {#if pending.length}<div class="overflow-x-auto">
        <table class="w-full text-left">
          <thead
            ><tr class="border-b border-surface-200"
              >{#each ["goober", "email", "date", "trust", "exec"] as h}<th
                  class="py-3 px-4">{h}</th
                >{/each}</tr
            ></thead
          ><tbody
            >{#each pending as request}<tr
                class="border-b border-surface-200 hover:bg-surface-100/50"
                ><td class="py-3 px-4">{@render User(request.user)}</td><td
                  class="py-3 px-4 text-muted">{request.user.email}</td
                ><td class="py-3 px-4 text-muted">{request.requested_at}</td><td
                  class="py-3 px-4">{@render Trust(request.user)}</td
                ><td class="py-3 px-4"
                  ><div class="flex gap-2">
                    <Form
                      action={adminDeletionRequests.approve.path({
                        id: request.id,
                      })}
                      method="post"
                      ><Button
                        unstyled
                        type="submit"
                        class="px-3 py-1 bg-green hover:bg-green text-on-primary text-sm font-medium rounded cursor-pointer"
                        >yuh</Button
                      ></Form
                    ><Form
                      action={adminDeletionRequests.reject.path({
                        id: request.id,
                      })}
                      method="post"
                      onsubmit={(event: SubmitEvent) => {
                        if (!confirm("yo ")) event.preventDefault();
                      }}
                      ><Button
                        unstyled
                        type="submit"
                        class="px-3 py-1 bg-red hover:bg-red text-on-primary text-sm font-medium rounded cursor-pointer"
                        >nah</Button
                      ></Form
                    >
                  </div></td
                ></tr
              >{/each}</tbody
          >
        </table>
      </div>{:else}<p class="text-muted">nuthing here</p>{/if}
  </section>
  <section class="border border-primary rounded-xl p-6 bg-dark">
    <h2 class="text-2xl font-semibold text-red mb-4">
      accounts waiting to go kerblam ({approved.length})
    </h2>
    {#if approved.length}<table class="w-full text-left">
        <thead
          ><tr class="border-b border-surface-200"
            >{#each ["goober", "approver", "approved", "exploded", "eta"] as h}<th
                class="py-3 px-4">{h}</th
              >{/each}</tr
          ></thead
        ><tbody
          >{#each approved as request}<tr
              class="border-b border-surface-200 hover:bg-surface-100/50"
              ><td class="py-3 px-4">{@render User(request.user)}</td><td
                class="py-3 px-4 text-muted">{request.approver}</td
              ><td class="py-3 px-4 text-muted">{request.approved_at}</td><td
                class="py-3 px-4 text-red">{request.deletion_at}</td
              ><td class="py-3 px-4"
                ><span
                  class="px-2 py-1 rounded text-xs font-medium bg-red/20 text-red"
                >
                  {request.days} days
                </span></td
              ></tr
            >{/each}</tbody
        >
      </table>{:else}<p class="text-muted">nuthing here</p>{/if}
  </section>
  <section class="border border-primary rounded-xl p-6 bg-dark">
    <h2 class="text-2xl font-semibold text-muted mb-4">recently kerblamed</h2>
    {#if done.length}<table class="w-full text-left">
        <thead
          ><tr class="border-b border-surface-200"
            >{#each ["goober", "approver", "kerblamed"] as h}<th
                class="py-3 px-4">{h}</th
              >{/each}</tr
          ></thead
        ><tbody
          >{#each done as request}<tr
              class="border-b border-surface-200 hover:bg-surface-100/50"
              ><td class="py-3 px-4 text-muted">#{request.user_id}</td><td
                class="py-3 px-4 text-muted">{request.approver}</td
              ><td class="py-3 px-4 text-muted">{request.completed_at}</td></tr
            >{/each}</tbody
        >
      </table>{:else}<p class="text-muted">nuthing here</p>{/if}
  </section>
</div>
{#snippet User(user: User)}<div class="flex items-center gap-2">
    <img src={user.avatar_url} alt="Avatar" class="w-8 h-8 rounded-full" /><span
      class="text-surface-content">{user.display_name}</span
    >
  </div>{/snippet}{#snippet Trust(user: User)}<span
    class="px-2 py-1 rounded text-xs font-medium {trust[user.trust_level] ||
      'bg-blue/20 text-blue'}">{user.trust_level}</span
  >{/snippet}
