<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import TextInput from "../../../components/TextInput.svelte";
  import { adminTrustLevelAuditLogs } from "../../../api";

  type User = {
    id: number;
    display_name: string;
    avatar_url: string | null;
    admin_level: string | null;
  };
  type Log = {
    id: number;
    created_at: string;
    previous_trust_level: string;
    new_trust_level: string;
    reason: string | null;
    user: User;
    changed_by: User;
  };
  let {
    audit_logs,
    filters,
    filtered_user,
    filtered_admin,
  }: {
    audit_logs: Log[];
    filters: {
      user_search: string | null;
      admin_search: string | null;
      trust_level: string;
    };
    filtered_user: string | null;
    filtered_admin: string | null;
  } = $props();
  const indexPath = adminTrustLevelAuditLogs.index.path();
  const emoji = (level: string) =>
    ({ blue: "🔵", red: "🔴", green: "🟢", yellow: "🟡" })[level] ?? "";
  const badge = (level: string | null) =>
    ({
      superadmin: ["supa admin", "border-red text-red"],
      admin: ["admin", "border-yellow text-yellow"],
      viewer: ["viewer", "border-blue text-blue"],
    })[level ?? ""];
</script>

<svelte:head><title>admin aboose logs</title></svelte:head>
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <div class="mb-8">
    <h1 class="mb-2 text-3xl font-bold text-surface-content">
      admin aboose logs
    </h1>
    <p class="text-muted">look at all the funky shit that admins do</p>
  </div>
  <div class="mb-6 rounded-lg bg-dark p-6">
    <Form action={indexPath} method="get" class="space-y-4">
      <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
        <div>
          <label
            for="user_search"
            class="mb-2 block text-sm font-medium text-muted">user lookup</label
          ><TextInput
            id="user_search"
            name="user_search"
            value={filters.user_search ?? ""}
            placeholder="just put anything here or something"
            class="w-full rounded-md bg-darkless px-3 py-2 text-surface-content placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue"
          />
        </div>
        <div>
          <label
            for="admin_search"
            class="mb-2 block text-sm font-medium text-muted"
            >admin lookup</label
          ><TextInput
            id="admin_search"
            name="admin_search"
            value={filters.admin_search ?? ""}
            placeholder="just put anything here or something"
            class="w-full rounded-md bg-darkless px-3 py-2 text-surface-content placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue"
          />
        </div>
        <div>
          <label
            for="trust_level_filter"
            class="mb-2 block text-sm font-medium text-muted"
            >filter by trust updates</label
          ><select
            id="trust_level_filter"
            name="trust_level_filter"
            value={filters.trust_level}
            class="w-full rounded-md bg-darkless px-3 py-2 text-surface-content focus:outline-none focus:ring-2 focus:ring-blue"
            ><option value="all">All Changes</option><option
              value="to_convicted">🔴 Set to Convicted</option
            ><option value="to_trusted">🟢 Set to Trusted</option><option
              value="to_suspected">🟡 Set to Suspected</option
            ><option value="to_unscored">🔵 Set to Unscored</option></select
          >
        </div>
      </div>
      <div class="flex items-center gap-4">
        <Button type="submit" variant="primary">run that shit</Button><Link
          href={indexPath}
          class="rounded-md bg-surface-100 px-4 py-2 font-medium text-surface-content transition-colors hover:bg-darkless"
          >alt+f4</Link
        ><span class="text-md text-muted"
          >found {audit_logs.length} result{audit_logs.length === 1
            ? ""
            : "s"}</span
        >
      </div>
    </Form>
  </div>
  {#if filtered_user || filtered_admin}<div
      class="mb-6 rounded-lg border border-blue/30 bg-dark p-4"
    >
      <div class="flex items-center justify-between">
        <div>
          {#if filtered_user}<p class="text-sm text-blue">
              filtering logs by <strong>{filtered_user}</strong>
            </p>{/if}{#if filtered_admin}<p class="text-sm text-blue">
              filtering logs by admin: <strong>{filtered_admin}</strong>
            </p>{/if}
        </div>
        <Link
          href={indexPath}
          class="rounded bg-blue px-3 py-1 text-sm text-on-primary"
          >fuckin abort</Link
        >
      </div>
    </div>{/if}
  <div class="overflow-hidden rounded-lg bg-dark shadow-xl">
    <div class="overflow-x-auto">
      <table class="min-w-full">
        <thead
          ><tr
            >{#each ["time", "goober", "change", "goobed by", "why", "link"] as heading}<th
                class="px-6 py-3 text-left text-sm font-medium text-muted"
                >{heading}</th
              >{/each}</tr
          ></thead
        ><tbody class="divide-y divide-gray-950">
          {#each audit_logs as log}<tr class="hover:bg-darkless"
              ><td class="whitespace-nowrap px-6 py-4 text-sm text-muted"
                >{log.created_at}</td
              ><td class="whitespace-nowrap px-6 py-4"
                ><div class="flex items-center">
                  {#if log.user.avatar_url}<img
                      class="mr-3 h-8 w-8 rounded-full"
                      src={log.user.avatar_url}
                      alt=""
                    />{/if}
                  <div>
                    <div class="text-sm font-medium text-surface-content">
                      {log.user.display_name}
                    </div>
                    <div class="text-sm text-muted">ID: {log.user.id}</div>
                  </div>
                </div></td
              >
              <td class="whitespace-nowrap px-6 py-4 text-sm text-muted"
                >{emoji(log.previous_trust_level)}
                <strong
                  >{log.previous_trust_level[0].toUpperCase() +
                    log.previous_trust_level.slice(1)}</strong
                >
                → {emoji(log.new_trust_level)}
                <strong
                  >{log.new_trust_level[0].toUpperCase() +
                    log.new_trust_level.slice(1)}</strong
                ></td
              >
              <td class="whitespace-nowrap px-6 py-4"
                ><div class="flex items-center">
                  {#if log.changed_by.avatar_url}<img
                      class="mr-2 h-6 w-6 rounded-full"
                      src={log.changed_by.avatar_url}
                      alt=""
                    />{/if}
                  <div class="text-sm text-surface-content">
                    {log.changed_by.display_name}
                    {#if badge(log.changed_by.admin_level)}{@const data = badge(
                        log.changed_by.admin_level,
                      )!}<span
                        class="inline-flex items-center rounded border px-1.5 py-0.2 text-sm font-medium {data[1]}"
                        >{data[0]}</span
                      >{/if}
                  </div>
                </div></td
              >
              <td class="px-6 py-4 text-sm text-muted"
                >{#if log.reason}<div
                    class="max-w-xs truncate"
                    title={log.reason}
                  >
                    {log.reason}
                  </div>{:else}<span class="italic text-muted"
                    >plead the 5th</span
                  >{/if}</td
              ><td class="whitespace-nowrap px-6 py-4 text-sm font-medium"
                ><Link
                  href={adminTrustLevelAuditLogs.show.path({ id: log.id })}
                  class="text-blue hover:text-blue">the deets</Link
                ></td
              ></tr
            >{/each}
        </tbody>
      </table>
    </div>
    {#if audit_logs.length === 0}<div class="py-12 text-center">
        <div class="mb-2 text-lg text-muted">theres nothin</div>
        <p class="text-muted">new shit will be seen here</p>
      </div>{/if}
  </div>
</div>
