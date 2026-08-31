<script lang="ts">
  import { Deferred, Form } from "@inertiajs/svelte";
  import Button from "../../../../components/Button.svelte";
  import { myHeartbeats } from "../../../../api";
  import type { DataExport } from "../importsExports";
  import SectionCard from "./SectionCard.svelte";

  let {
    dataExport,
    exportCooldownMinutes,
  }: {
    dataExport?: DataExport;
    exportCooldownMinutes: number;
  } = $props();

  const dateInputClass =
    "rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none";
</script>

{#snippet statTile(label: string, value: string)}
  <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
    <p class="text-xs uppercase tracking-wide text-muted">{label}</p>
    <p class="mt-1 text-lg font-semibold tabular-nums text-surface-content">
      {value}
    </p>
  </div>
{/snippet}

<SectionCard
  id="download_user_data"
  title="Download Data"
  description="Download your coding history as JSON for backups or analysis."
  wide
>
  <Deferred data="data_export">
    {#snippet fallback()}
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {#each Array(3) as _}
          <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
            <div class="h-3 w-24 animate-pulse rounded bg-surface-200"></div>
            <div
              class="mt-3 h-5 w-16 animate-pulse rounded bg-surface-200"
            ></div>
          </div>
        {/each}
      </div>
      <div class="mt-3 h-4 w-64 animate-pulse rounded bg-surface-200"></div>
    {/snippet}

    {#if !dataExport}
      <!-- waiting for deferred data -->
    {:else if dataExport.is_restricted}
      <p
        class="rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red-200"
      >
        Data export is currently restricted for this account.
      </p>
    {:else}
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {@render statTile("Total heartbeats", dataExport.total_heartbeats)}
        {@render statTile("Total coding time", dataExport.total_coding_time)}
        {@render statTile("Last 7 days", dataExport.heartbeats_last_7_days)}
      </div>

      <p class="mt-3 text-sm text-muted">
        Exports are generated in the background and emailed to you. You can
        request one export every {exportCooldownMinutes} minutes.
      </p>

      <div class="mt-4 space-y-3">
        <Form
          method="post"
          action={myHeartbeats.export.path({ query: { all_data: "true" } })}
          options={{ preserveScroll: true }}
        >
          {#snippet children({ processing })}
            <Button type="submit" class="rounded-md" disabled={processing}>
              {processing ? "Exporting..." : "Export all heartbeats"}
            </Button>
          {/snippet}
        </Form>

        <Form
          method="post"
          action={myHeartbeats.export.path()}
          class="grid grid-cols-1 gap-3 rounded-md border border-surface-200 bg-darker p-4 sm:grid-cols-3"
          options={{ preserveScroll: true }}
        >
          {#snippet children({ processing })}
            <input
              type="date"
              name="start_date"
              required
              class={dateInputClass}
            />
            <input
              type="date"
              name="end_date"
              required
              class={dateInputClass}
            />
            <Button
              type="submit"
              variant="surface"
              class="rounded-md"
              disabled={processing}
            >
              {processing ? "Exporting..." : "Export date range"}
            </Button>
          {/snippet}
        </Form>
      </div>
    {/if}
  </Deferred>
</SectionCard>
