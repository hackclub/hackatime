<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import DetailField from "../../../components/DetailField.svelte";
  import { adminTrustLevelAuditLogs } from "../../../api";
  type User = {
    id: number;
    display_name: string;
    avatar_url: string | null;
    admin_level: string | null;
  };
  type Log = {
    id: number;
    created_at_long: string;
    previous_trust_level: string;
    new_trust_level: string;
    reason: string | null;
    notes: string | null;
    user: User;
    changed_by: User;
  };
  let { audit_log }: { audit_log: Log } = $props();
  const indexPath = adminTrustLevelAuditLogs.index.path();
  const emoji = (level: string) =>
    ({ blue: "🔵", red: "🔴", green: "🟢", yellow: "🟡" })[level] ?? "";
  const levelName = (level: string) => level[0].toUpperCase() + level.slice(1);
  const badge = (level: string | null) =>
    ({
      superadmin: ["supa admin", "border-red text-red"],
      admin: ["admin", "border-yellow text-yellow"],
      viewer: ["viewer", "border-blue text-blue"],
    })[level ?? ""];
</script>

<svelte:head><title>title</title></svelte:head>
<div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
  <div class="mb-8 flex items-center justify-between">
    <h1 class="text-3xl font-bold text-surface-content">
      looking at a single audit log
    </h1>
    <Link
      href={indexPath}
      class="rounded-lg bg-darkless px-4 py-2 text-surface-content"
      >get me outta here</Link
    >
  </div>
  <div class="rounded-lg bg-dark p-8 shadow-xl">
    <div class="grid grid-cols-1 gap-8 md:grid-cols-2">
      <div>
        <h2 class="mb-4 text-xl font-semibold text-surface-content">user</h2>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            {#if audit_log.user.avatar_url}<img
                src={audit_log.user.avatar_url}
                alt=""
                class="h-8 w-8 rounded-full border border-surface-200"
              />{/if}{audit_log.user.display_name}
          </div>
          <div class="text-sm text-muted">id: {audit_log.user.id}</div>
        </div>
        <div class="pt-4">
          <Link
            href={adminTrustLevelAuditLogs.index.path({
              query: { user_id: audit_log.user.id },
            })}
            class="text-blue">actions on this goober</Link
          >
        </div>
      </div>
      <div>
        <h2 class="mb-4 text-xl font-semibold text-surface-content">
          updated by
        </h2>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            {#if audit_log.changed_by.avatar_url}<img
                src={audit_log.changed_by.avatar_url}
                alt=""
                class="h-8 w-8 rounded-full border border-surface-200"
              />{/if}{audit_log.changed_by
              .display_name}{#if badge(audit_log.changed_by.admin_level)}{@const data =
                badge(audit_log.changed_by.admin_level)!}<span
                class="inline-flex items-center rounded border px-1.5 py-0.2 text-sm font-medium {data[1]}"
                >{data[0]}</span
              >{/if}
          </div>
          <div class="text-sm text-muted">id: {audit_log.changed_by.id}</div>
        </div>
        <div class="pt-4">
          <Link
            href={adminTrustLevelAuditLogs.index.path({
              query: { admin_id: audit_log.changed_by.id },
            })}
            class="text-blue">changes by this goober</Link
          >
        </div>
      </div>
    </div>
    <div class="mt-4">
      <h2 class="mb-4 text-xl font-semibold text-surface-content">the deets</h2>
      <div class="mb-6 grid grid-cols-1 gap-6 md:grid-cols-3">
        <DetailField label="executed at" variant="mutedSpaced">
          <div class="text-surface-content">{audit_log.created_at_long}</div>
        </DetailField>
        <DetailField label="before" variant="mutedSpaced">
          <div class="text-lg text-surface-content">
            {emoji(audit_log.previous_trust_level)}
            <strong>{levelName(audit_log.previous_trust_level)}</strong>
          </div>
        </DetailField>
        <DetailField label="after" variant="mutedSpaced">
          <div class="text-lg text-surface-content">
            {emoji(audit_log.new_trust_level)}
            <strong>{levelName(audit_log.new_trust_level)}</strong>
          </div>
        </DetailField>
      </div>
      {#if audit_log.reason}<DetailField
          label="Reason"
          variant="mutedSpaced"
          class="mb-6"
        >
          <div
            class="whitespace-pre-line rounded-lg bg-darker p-4 text-surface-content"
          >
            {audit_log.reason}
          </div>
        </DetailField>{/if}{#if audit_log.notes}<DetailField
          label="Additional Notes"
          variant="mutedSpaced"
          class="mb-6"
        >
          <div
            class="whitespace-pre-line rounded-lg bg-darker p-4 text-surface-content"
          >
            {audit_log.notes}
          </div>
        </DetailField>{/if}
    </div>
  </div>
</div>
