<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  interface SubmissionRow {
    id: number;
    username: string;
    project_name: string;
    program_slug: string;
    submitted_hours: number;
    approved_hours: number | null;
    chain_verified: boolean;
    git_push_verified: boolean;
    plugin_share_pct: number;
    anomaly_count: number;
    review_status: string;
    created_at: string;
  }

  let { page_title, submissions }: { page_title: string; submissions: SubmissionRow[] } = $props();
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6 px-4 py-8">
  <div>
    <h1 class="text-2xl font-bold">90-Second Fraud Squad Audit Workbench</h1>
    <p class="mt-1 text-sm text-secondary">
      Cryptographically hash-chained Tier-2 submissions with GitHub push cross-checks and provenance segregation.
    </p>
  </div>

  <div class="overflow-x-auto rounded-xl border border-surface-300 bg-surface-100">
    <table class="w-full text-left text-xs">
      <thead class="bg-surface-200/60 text-secondary">
        <tr>
          <th class="px-4 py-3">ID</th>
          <th class="px-4 py-3">Builder</th>
          <th class="px-4 py-3">Project / Program</th>
          <th class="px-4 py-3">Hours</th>
          <th class="px-4 py-3">Integrity</th>
          <th class="px-4 py-3">Tier-C Share</th>
          <th class="px-4 py-3">Status</th>
          <th class="px-4 py-3">Inspect</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-surface-300/60">
        {#each submissions as sub (sub.id)}
          <tr class="hover:bg-surface-200/30">
            <td class="px-4 py-3 font-mono">#{sub.id}</td>
            <td class="px-4 py-3 font-medium">@{sub.username}</td>
            <td class="px-4 py-3">
              <div class="font-semibold">{sub.project_name}</div>
              <div class="text-secondary">{sub.program_slug}</div>
            </td>
            <td class="px-4 py-3 font-mono">{sub.submitted_hours.toFixed(2)}h</td>
            <td class="px-4 py-3 space-x-1">
              <span class="rounded px-1.5 py-0.5 font-mono {sub.chain_verified ? 'bg-emerald-500/20 text-emerald-300' : 'bg-red-500/20 text-red-300'}">
                {sub.chain_verified ? "CHAIN VALID" : "CHAIN FAIL"}
              </span>
              <span class="rounded px-1.5 py-0.5 font-mono {sub.git_push_verified ? 'bg-emerald-500/20 text-emerald-300' : 'bg-amber-500/20 text-amber-300'}">
                {sub.git_push_verified ? "GIT MATCH" : "GIT CHECK"}
              </span>
              {#if sub.anomaly_count > 0}
                <span class="rounded bg-red-500/20 px-1.5 py-0.5 font-mono text-red-300">
                  {sub.anomaly_count} FLAG(S)
                </span>
              {/if}
            </td>
            <td class="px-4 py-3 font-mono">{sub.plugin_share_pct}%</td>
            <td class="px-4 py-3 uppercase font-semibold">{sub.review_status}</td>
            <td class="px-4 py-3">
              <Link href={`/admin/audit_submissions/${sub.id}`} class="text-primary underline">
                Open Scrubber
              </Link>
            </td>
          </tr>
        {:else}
          <tr>
            <td colspan="8" class="px-4 py-10 text-center text-secondary">
              No audit submissions yet. Submitted <code>.hcaudit</code> proof bundles will appear here for Fraud Squad review.
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>
