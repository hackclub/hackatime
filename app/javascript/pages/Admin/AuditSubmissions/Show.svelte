<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";

  interface AnomalyFlag {
    severity: string;
    code: string;
    message: string;
  }

  interface TimelineWindow {
    id: number;
    window_start: string;
    raw_seconds: number;
    credited_seconds: number;
    convertible_seconds: number;
    converted: boolean;
    struggle_points: number;
    effective_multiplier: number;
    provenance_mask: number;
    ai_harness: string;
    signal_counts: Record<string, number>;
    git_head_sha?: string | null;
  }

  interface SubmissionDetail {
    id: number;
    username: string;
    project_name: string;
    project_hash: string;
    program_slug: string;
    git_remote_url?: string | null;
    bundle_sha256: string;
    submitted_hours: number;
    approved_hours?: number | null;
    chain_verified: boolean;
    git_push_verified: boolean;
    plugin_share_pct: number;
    anomaly_flags: AnomalyFlag[];
    review_status: string;
    reviewer_notes?: string | null;
  }

  let {
    page_title,
    submission,
    windows,
  }: {
    page_title: string;
    submission: SubmissionDetail;
    windows: TimelineWindow[];
  } = $props();

  let selectedIndex = $state(0);
  let approvedHours = $state("");
  let reviewerNotes = $state("");
  let saving = $state(false);

  $effect(() => {
    approvedHours = String(submission.approved_hours ?? submission.submitted_hours);
    reviewerNotes = submission.reviewer_notes ?? "";
  });

  const selectedWindow = $derived(windows[selectedIndex] ?? null);

  function barColor(w: TimelineWindow): string {
    if ((w.provenance_mask & 4) !== 0 && (w.provenance_mask & 3) === 0) {
      return "bg-purple-400"; // Tier-C only plugin band
    }
    if ((w.signal_counts["SIG_ERROR_LOOP"] ?? 0) > 0) {
      return "bg-amber-400"; // Compiler/test error-to-fix spike
    }
    if (w.effective_multiplier >= 0.8) return "bg-emerald-400";
    if (w.effective_multiplier >= 0.4) return "bg-sky-400";
    return "bg-rose-500/70";
  }

  function submitVerdict(status: "approved" | "deflated" | "rejected") {
    saving = true;
    router.patch(
      `/admin/audit_submissions/${submission.id}`,
      {
        review_status: status,
        approved_hours: status === "rejected" ? 0 : Number(approvedHours),
        reviewer_notes: reviewerNotes,
      },
      {
        onFinish: () => {
          saving = false;
        },
      },
    );
  }
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6 px-4 py-8">
  <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold">
        Audit #{submission.id} — @{submission.username} / {submission.project_name}
      </h1>
      <p class="text-xs font-mono text-secondary">
        Program: {submission.program_slug} · Bundle SHA-256: {submission.bundle_sha256.slice(0, 16)}...
      </p>
    </div>
    <span class="rounded-full border border-surface-300 bg-surface-200 px-3 py-1 text-xs font-bold uppercase">
      {submission.review_status}
    </span>
  </div>

  <!-- Trust Score, Provenance & Anomaly Banner -->
  <div class="grid grid-cols-1 gap-4 md:grid-cols-4">
    <div class="rounded-xl border border-surface-300 bg-surface-100 p-4">
      <div class="text-xs text-secondary">Ed25519 + Nonce Chain</div>
      <div class="mt-1 text-lg font-bold {submission.chain_verified ? 'text-emerald-400' : 'text-rose-400'}">
        {submission.chain_verified ? "VALID" : "FAILED"}
      </div>
    </div>
    <div class="rounded-xl border border-surface-300 bg-surface-100 p-4">
      <div class="text-xs text-secondary">GitHub Commit Cross-Check</div>
      <div class="mt-1 text-lg font-bold {submission.git_push_verified ? 'text-emerald-400' : 'text-amber-300'}">
        {submission.git_push_verified ? "ALIGNED" : "REVIEW NEEDED"}
      </div>
    </div>
    <div class="rounded-xl border border-surface-300 bg-surface-100 p-4">
      <div class="text-xs text-secondary">Tier-C Plugin Share</div>
      <div class="mt-1 text-lg font-bold {submission.plugin_share_pct > 30 ? 'text-rose-400' : 'text-emerald-400'}">
        {submission.plugin_share_pct}%
      </div>
    </div>
    <div class="rounded-xl border border-surface-300 bg-surface-100 p-4">
      <div class="text-xs text-secondary">Submitted Hours</div>
      <div class="mt-1 text-lg font-bold">{submission.submitted_hours.toFixed(2)}h</div>
    </div>
  </div>

  {#if submission.anomaly_flags.length > 0}
    <div class="rounded-xl border border-rose-500/40 bg-rose-950/20 p-4 space-y-2">
      <div class="text-sm font-bold text-rose-300">Automated Anomaly Callouts</div>
      {#each submission.anomaly_flags as flag}
        <div class="text-xs">
          <span class="rounded bg-rose-500/30 px-1.5 py-0.5 font-mono uppercase">{flag.severity}</span>
          <span class="ml-2 font-mono font-semibold">{flag.code}</span> — {flag.message}
        </div>
      {/each}
    </div>
  {/if}

  <!-- Interactive Session Replay Timeline Scrubber -->
  <section class="rounded-xl border border-surface-300 bg-surface-100 p-5 space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-base font-semibold">Interactive 5-Minute Struggle Timeline ({windows.length} windows)</h2>
      <div class="flex gap-3 text-[11px] text-secondary">
        <span><span class="inline-block size-2 rounded-full bg-emerald-400"></span> High Struggle</span>
        <span><span class="inline-block size-2 rounded-full bg-amber-400"></span> Error-to-Fix Spike</span>
        <span><span class="inline-block size-2 rounded-full bg-purple-400"></span> Tier-C Plugin</span>
      </div>
    </div>

    <div class="flex h-28 items-end gap-0.5 overflow-x-auto rounded-lg bg-surface-200/40 p-2">
      {#each windows as w, idx (w.id)}
        <button
          type="button"
          title={`${w.window_start} | ${w.effective_multiplier}x | ${w.struggle_points} SP`}
          class="min-w-[6px] flex-1 rounded-t transition-opacity {barColor(w)} {selectedIndex === idx ? 'ring-2 ring-white opacity-100' : 'opacity-75 hover:opacity-100'}"
          style={`height: ${Math.max(10, Math.round(w.effective_multiplier * 100))}%`}
          onclick={() => (selectedIndex = idx)}
        ></button>
      {/each}
    </div>

    {#if selectedWindow}
      <div class="rounded-lg border border-surface-300 bg-surface-200/30 p-4 text-xs space-y-2">
        <div class="flex flex-wrap justify-between gap-2 font-mono">
          <span>Window: <strong>{selectedWindow.window_start}</strong></span>
          <span>Multiplier: <strong>{selectedWindow.effective_multiplier.toFixed(2)}x</strong> ({selectedWindow.struggle_points} SP)</span>
          <span>Credited: <strong>{selectedWindow.credited_seconds}s</strong> / {selectedWindow.raw_seconds}s</span>
          <span>Harness: <strong>{selectedWindow.ai_harness}</strong></span>
        </div>
        <div class="flex flex-wrap gap-1.5">
          {#each Object.entries(selectedWindow.signal_counts) as [sig, count]}
            <span class="rounded bg-surface-200 px-2 py-0.5 font-mono">{sig}×{count}</span>
          {/each}
          {#if selectedWindow.git_head_sha}
            <span class="rounded border border-emerald-500/40 px-2 py-0.5 font-mono text-emerald-300">
              git:{selectedWindow.git_head_sha.slice(0, 8)}
            </span>
          {/if}
        </div>
      </div>
    {/if}
  </section>

  <!-- Reviewer Decision Controls -->
  <section class="rounded-xl border border-surface-300 bg-surface-100 p-5 space-y-4">
    <h2 class="text-base font-semibold">Fraud Squad Verdict</h2>
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <label class="block text-xs">
        <span class="text-secondary">Approved Hours</span>
        <input
          type="number"
          step="0.05"
          min="0"
          bind:value={approvedHours}
          class="mt-1 w-full rounded-lg border border-surface-300 bg-surface-200 px-3 py-2 text-sm"
        />
      </label>
      <label class="block text-xs sm:col-span-2">
        <span class="text-secondary">Reviewer Notes</span>
        <input
          type="text"
          bind:value={reviewerNotes}
          placeholder="Verified hash chain, incremental commits, and error-to-fix timeline..."
          class="mt-1 w-full rounded-lg border border-surface-300 bg-surface-200 px-3 py-2 text-sm"
        />
      </label>
    </div>

    <div class="flex flex-wrap gap-3">
      <Button disabled={saving} onclick={() => submitVerdict("approved")}>Approve Hours</Button>
      <Button disabled={saving} onclick={() => submitVerdict("deflated")}>Deflate Hours</Button>
      <Button disabled={saving} onclick={() => submitVerdict("rejected")}>Reject Submission</Button>
    </div>
  </section>
</div>
