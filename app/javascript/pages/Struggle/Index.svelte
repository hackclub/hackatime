<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";

  interface StruggleWindowItem {
    id: number;
    window_start: string;
    raw_seconds: number;
    convertible_seconds: number;
    struggle_points: number;
    effective_multiplier: number;
    verify_multiplier: number;
    provenance_mask: number;
    ai_harness: string;
    signal_counts: Record<string, number>;
    git_head_sha?: string | null;
  }

  interface ProjectGroup {
    project_hash: string;
    project_name: string;
    primary_language: string;
    windows_count: number;
    total_sp: number;
    total_raw_seconds: number;
    convertible_seconds: number;
    avg_multiplier: number;
    windows: StruggleWindowItem[];
  }

  interface ConversionReceipt {
    id: number;
    project_name: string;
    windows_count: number;
    total_sp_converted: number;
    total_raw_seconds: number;
    total_credited_seconds: number;
    converted_at: string;
  }

  interface Props {
    page_title: string;
    conversion_mode: string;
    summary: {
      unconverted_windows_count: number;
      unconverted_sp: number;
      unconverted_raw_seconds: number;
      convertible_seconds: number;
      total_converted_seconds: number;
      total_converted_windows: number;
      avg_multiplier: number;
      badge_url: string;
      badge_markdown: string;
    };
    project_groups: ProjectGroup[];
    conversions: ConversionReceipt[];
  }

  let { page_title, summary, project_groups, conversions }: Props = $props();

  let convertingKey = $state<string | null>(null);
  let expandedProjects = $state<Record<string, boolean>>({});
  let selectedWindowIds = $state<Record<number, boolean>>({});
  let copiedBadge = $state(false);

  const selectedIds = $derived(
    Object.entries(selectedWindowIds)
      .filter(([, checked]) => checked)
      .map(([id]) => Number(id)),
  );

  function formatDuration(seconds: number): string {
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hrs > 0) return `${hrs}h ${mins}m`;
    if (mins > 0) return `${mins}m ${secs}s`;
    return `${secs}s`;
  }

  function provenanceLabels(mask: number): string[] {
    const labels: string[] = [];
    if ((mask & 1) !== 0) labels.push("Tier A (Git/Shell)");
    if ((mask & 2) !== 0) labels.push("Tier B (IDE/CLI)");
    if ((mask & 4) !== 0) labels.push("Tier C (Plugin)");
    return labels;
  }

  function convertAll() {
    convertingKey = "all";
    router.post(
      "/my/struggle/convert",
      {},
      {
        preserveScroll: true,
        onFinish: () => {
          convertingKey = null;
          selectedWindowIds = {};
        },
      },
    );
  }

  function convertProject(projectHash: string) {
    convertingKey = projectHash;
    router.post(
      "/my/struggle/convert",
      { project_hash: projectHash },
      {
        preserveScroll: true,
        onFinish: () => {
          convertingKey = null;
          selectedWindowIds = {};
        },
      },
    );
  }

  function convertSelected() {
    if (selectedIds.length === 0) return;
    convertingKey = "selected";
    router.post(
      "/my/struggle/convert",
      { window_ids: selectedIds },
      {
        preserveScroll: true,
        onFinish: () => {
          convertingKey = null;
          selectedWindowIds = {};
        },
      },
    );
  }

  function toggleExpand(projectHash: string) {
    expandedProjects = {
      ...expandedProjects,
      [projectHash]: !expandedProjects[projectHash],
    };
  }

  async function copyBadgeMarkdown() {
    try {
      await navigator.clipboard.writeText(summary.badge_markdown);
      copiedBadge = true;
      setTimeout(() => {
        copiedBadge = false;
      }, 2000);
    } catch {
      copiedBadge = false;
    }
  }
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-8 px-4 py-8">
  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">Struggle Points (SP) → Verified Hours</h1>
      <p class="mt-1 text-sm text-secondary">
        Your Hackatime AI extension passively tracks 5-minute Productive Struggle Windows. Review
        your SP breakdown below and convert them into verified hours whenever you're ready
        (per-window exact cap: 10 SP = 100% of that 5-minute window, AFK autopilot &lt;2 SP = 0).
      </p>
    </div>

    <div class="flex flex-wrap gap-2">
      {#if selectedIds.length > 0}
        <Button
          disabled={convertingKey !== null}
          onclick={convertSelected}
        >
          {convertingKey === "selected"
            ? "Converting..."
            : `Convert ${selectedIds.length} Selected`}
        </Button>
      {/if}

      <Button
        disabled={convertingKey !== null || summary.unconverted_windows_count === 0}
        onclick={convertAll}
      >
        {convertingKey === "all"
          ? "Converting..."
          : `Convert All (${formatDuration(summary.convertible_seconds)})`}
      </Button>
    </div>
  </div>

  <!-- Top Summary Cards -->
  <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
    <div class="rounded-xl border border-surface-300 bg-surface-100 p-5">
      <div class="text-xs font-semibold uppercase tracking-wider text-secondary">
        Unconverted SP Balance
      </div>
      <div class="mt-2 flex items-baseline gap-2">
        <span class="text-3xl font-bold">{summary.unconverted_sp.toFixed(1)} SP</span>
        <span class="text-sm text-secondary">({summary.unconverted_windows_count} windows)</span>
      </div>
      <div class="mt-2 text-sm">
        Converts to <span class="font-semibold text-emerald-400">{formatDuration(summary.convertible_seconds)}</span>
        <span class="text-secondary">out of {formatDuration(summary.unconverted_raw_seconds)} raw active</span>
      </div>
    </div>

    <div class="rounded-xl border border-surface-300 bg-surface-100 p-5">
      <div class="text-xs font-semibold uppercase tracking-wider text-secondary">
        Verified Struggle Hours Banked
      </div>
      <div class="mt-2 text-3xl font-bold text-emerald-400">
        {formatDuration(summary.total_converted_seconds)}
      </div>
      <div class="mt-2 text-sm text-secondary">
        {summary.total_converted_windows} converted windows · Avg multiplier
        <span class="font-mono font-semibold">{summary.avg_multiplier.toFixed(2)}x</span>
      </div>
    </div>

    <div class="rounded-xl border border-surface-300 bg-surface-100 p-5">
      <div class="text-xs font-semibold uppercase tracking-wider text-secondary">
        README Struggle SVG Badge
      </div>
      <p class="mt-2 truncate font-mono text-xs text-secondary">{summary.badge_url}</p>
      <div class="mt-3">
        <Button onclick={copyBadgeMarkdown}>
          {copiedBadge ? "Copied README Markdown!" : "Copy README Badge Markdown"}
        </Button>
      </div>
    </div>
  </div>

  <!-- Per-Project Unconverted SP Queue -->
  <section class="space-y-4">
    <h2 class="text-lg font-semibold">Ready to Convert by Project</h2>

    {#if project_groups.length === 0}
      <div class="rounded-xl border border-dashed border-surface-300 bg-surface-100/50 p-8 text-center">
        <p class="font-medium">No unconverted Struggle Points waiting right now.</p>
        <p class="mt-1 text-sm text-secondary">
          Keep coding in Antigravity, Cursor, Windsurf, or VS Code with the Hackatime AI extension—your
          signed 5-minute windows will appear here automatically.
        </p>
      </div>
    {:else}
      {#each project_groups as group (group.project_hash)}
        <div class="overflow-hidden rounded-xl border border-surface-300 bg-surface-100">
          <div class="flex flex-col gap-3 p-5 sm:flex-row sm:items-center sm:justify-between">
            <div class="space-y-1">
              <div class="flex items-center gap-2">
                <h3 class="text-base font-bold">{group.project_name}</h3>
                <span class="rounded-full bg-surface-200 px-2.5 py-0.5 text-xs font-medium">
                  {group.primary_language}
                </span>
              </div>
              <p class="text-sm text-secondary">
                <span class="font-mono font-semibold">{group.total_sp.toFixed(1)} SP</span> across
                {group.windows_count} windows · Avg {group.avg_multiplier.toFixed(2)}x →
                <span class="font-semibold text-emerald-400">
                  {formatDuration(group.convertible_seconds)}
                </span>
                (raw {formatDuration(group.total_raw_seconds)})
              </p>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="button"
                class="rounded-lg border border-surface-300 px-3 py-1.5 text-xs font-medium hover:bg-surface-200"
                onclick={() => toggleExpand(group.project_hash)}
              >
                {expandedProjects[group.project_hash] ? "Hide Windows" : "Inspect Windows"}
              </button>

              <Button
                disabled={convertingKey !== null}
                onclick={() => convertProject(group.project_hash)}
              >
                {convertingKey === group.project_hash
                  ? "Converting..."
                  : `Convert ${formatDuration(group.convertible_seconds)}`}
              </Button>
            </div>
          </div>

          {#if expandedProjects[group.project_hash]}
            <div class="overflow-x-auto border-t border-surface-300">
              <table class="w-full text-left text-xs">
                <thead class="bg-surface-200/60 text-secondary">
                  <tr>
                    <th class="px-4 py-2">Select</th>
                    <th class="px-4 py-2">Window (UTC)</th>
                    <th class="px-4 py-2">SP</th>
                    <th class="px-4 py-2">Multiplier</th>
                    <th class="px-4 py-2">Convertible</th>
                    <th class="px-4 py-2">Signals &amp; Provenance</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-surface-300/60">
                  {#each group.windows as win (win.id)}
                    <tr class="hover:bg-surface-200/30">
                      <td class="px-4 py-2">
                        <input
                          type="checkbox"
                          checked={!!selectedWindowIds[win.id]}
                          onchange={(e) => {
                            selectedWindowIds = {
                              ...selectedWindowIds,
                              [win.id]: (e.currentTarget as HTMLInputElement).checked,
                            };
                          }}
                        />
                      </td>
                      <td class="px-4 py-2 font-mono">{win.window_start.replace("T", " ").slice(0, 16)}</td>
                      <td class="px-4 py-2 font-mono font-semibold">{win.struggle_points.toFixed(1)}</td>
                      <td class="px-4 py-2 font-mono">
                        {win.effective_multiplier.toFixed(2)}x
                        {#if win.verify_multiplier < 1}
                          <span class="ml-1 rounded bg-amber-500/20 px-1.5 py-0.5 text-[10px] text-amber-300">
                            unverified AI 0.5x
                          </span>
                        {/if}
                      </td>
                      <td class="px-4 py-2 font-mono text-emerald-400">
                        {formatDuration(win.convertible_seconds)}
                        <span class="text-secondary">/ {formatDuration(win.raw_seconds)}</span>
                      </td>
                      <td class="px-4 py-2">
                        <div class="flex flex-wrap gap-1">
                          {#each Object.entries(win.signal_counts) as [sig, count]}
                            <span class="rounded bg-surface-200 px-1.5 py-0.5 font-mono text-[10px]">
                              {sig.replace("SIG_", "")}×{count}
                            </span>
                          {/each}
                          {#each provenanceLabels(win.provenance_mask) as tier}
                            <span class="rounded border border-surface-300 px-1.5 py-0.5 text-[10px] text-secondary">
                              {tier}
                            </span>
                          {/each}
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
      {/each}
    {/if}
  </section>

  <!-- Auditable Conversion Ledger -->
  <section class="space-y-3">
    <h2 class="text-lg font-semibold">Conversion History Ledger</h2>
    {#if conversions.length === 0}
      <p class="text-sm text-secondary">No conversions yet.</p>
    {:else}
      <div class="overflow-x-auto rounded-xl border border-surface-300 bg-surface-100">
        <table class="w-full text-left text-xs">
          <thead class="bg-surface-200/60 text-secondary">
            <tr>
              <th class="px-4 py-2.5">Receipt</th>
              <th class="px-4 py-2.5">Converted At (UTC)</th>
              <th class="px-4 py-2.5">Project</th>
              <th class="px-4 py-2.5">Windows</th>
              <th class="px-4 py-2.5">SP Converted</th>
              <th class="px-4 py-2.5">Verified Hours Credited</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-surface-300/60">
            {#each conversions as rec (rec.id)}
              <tr>
                <td class="px-4 py-2.5 font-mono">#{rec.id}</td>
                <td class="px-4 py-2.5 font-mono">{rec.converted_at.replace("T", " ").slice(0, 16)}</td>
                <td class="px-4 py-2.5 font-medium">{rec.project_name}</td>
                <td class="px-4 py-2.5 font-mono">{rec.windows_count}</td>
                <td class="px-4 py-2.5 font-mono">{rec.total_sp_converted.toFixed(1)} SP</td>
                <td class="px-4 py-2.5 font-mono font-semibold text-emerald-400">
                  {formatDuration(rec.total_credited_seconds)}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </section>
</div>
