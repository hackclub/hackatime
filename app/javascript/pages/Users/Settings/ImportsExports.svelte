<script lang="ts">
  import { Deferred, Form, usePoll } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import ImportStatusRow from "./components/ImportStatusRow.svelte";
  import SettingsShell from "./Shell.svelte";
  import type {
    ImportsExportsPageProps,
    HeartbeatImportStatusProps,
  } from "./types";
  import { myHeartbeatImports, myHeartbeats } from "../../../api";

  const PROVIDERS = [
    {
      value: "wakatime_dump",
      label: "WakaTime",
      helper: "Request a one-time heartbeat dump from WakaTime.",
    },
    {
      value: "hackatime_v1_dump",
      label: "Hackatime v1",
      helper: "Request a one-time heartbeat dump from legacy Hackatime.",
    },
  ] as const;

  const OVERLAY_TIMEOUT_MS = 5 * 60 * 1000;

  let {
    active_section,
    page_title,
    heading,
    subheading,
    data_export,
    imports_enabled,
    remote_import_cooldown_until,
    latest_heartbeat_import,
    ui,
    errors,
  }: ImportsExportsPageProps = $props();

  const createHeartbeatImportPath = myHeartbeatImports.create.path();

  let selectedFile = $state<File | null>(null);
  let remoteProvider =
    $state<(typeof PROVIDERS)[number]["value"]>("wakatime_dump");
  let remoteApiKey = $state("");
  let importOverlay = $state<Partial<HeartbeatImportStatusProps> | null>(null);
  let overlayStartTime = $state<number | null>(null);

  const { start: startPolling, stop: stopPolling } = usePoll(
    1000,
    { only: ["latest_heartbeat_import", "remote_import_cooldown_until"] },
    { autoStart: false },
  );

  const isServerTerminal = $derived(
    latest_heartbeat_import?.state === "completed" ||
      latest_heartbeat_import?.state === "failed",
  );
  const isOverlayStale = $derived(
    overlayStartTime != null &&
      Date.now() - overlayStartTime > OVERLAY_TIMEOUT_MS,
  );

  const activeImport = $derived(
    isOverlayStale || (isServerTerminal && importOverlay)
      ? latest_heartbeat_import
      : (importOverlay ?? latest_heartbeat_import),
  );
  const importState = $derived(activeImport?.state ?? "idle");
  const importSourceKind = $derived(activeImport?.source_kind ?? "");

  const importInProgress = $derived(
    [
      "queued",
      "requesting_dump",
      "waiting_for_dump",
      "downloading_dump",
      "importing",
    ].includes(importState),
  );
  const latestImportIsRemote = $derived(
    ["wakatime_dump", "wakatime_download_link", "hackatime_v1_dump"].includes(
      importSourceKind,
    ),
  );
  const latestImportIsDev = $derived(importSourceKind === "dev_upload");

  const effectiveRemoteCooldownUntil = $derived(
    activeImport?.cooldown_until ?? remote_import_cooldown_until ?? null,
  );
  const remoteCooldownActive = $derived(
    effectiveRemoteCooldownUntil
      ? new Date(effectiveRemoteCooldownUntil).getTime() > Date.now()
      : false,
  );

  const hiddenSubsections = $derived(
    ui.show_imports ? undefined : new Set(["user_imports"]),
  );

  $effect(() => {
    if (importInProgress) startPolling();
    else stopPolling();
  });

  $effect(() => {
    if (!importOverlay) return;
    if (isServerTerminal && latest_heartbeat_import != null) {
      importOverlay = null;
      overlayStartTime = null;
      return;
    }
    if (overlayStartTime) {
      const remaining = Math.max(
        0,
        OVERLAY_TIMEOUT_MS - (Date.now() - overlayStartTime),
      );
      const id = setTimeout(() => {
        importOverlay = null;
        overlayStartTime = null;
        stopPolling();
      }, remaining);
      return () => clearTimeout(id);
    }
  });

  const formatCount = (v: number | null | undefined) =>
    v == null ? "—" : v.toLocaleString();

  function formatRelativeTime(value: string | null) {
    if (!value) return "—";
    const diff = new Date(value).getTime() - Date.now();
    if (diff <= 0) return "now";
    const seconds = Math.ceil(diff / 1000);
    return seconds < 60 ? `${seconds}s` : `${Math.ceil(seconds / 60)}m`;
  }

  function providerLabel(sourceKind: string) {
    if (
      sourceKind === "wakatime_dump" ||
      sourceKind === "wakatime_download_link"
    )
      return "WakaTime";
    if (sourceKind === "hackatime_v1_dump") return "Hackatime v1";
    if (sourceKind === "dev_upload") return "Development upload";
    return "Import";
  }

  const completedSummary = $derived(
    importState === "completed"
      ? `${formatCount(activeImport?.imported_count)} imported, ${formatCount(activeImport?.skipped_count)} skipped`
      : null,
  );

  function onImportSuccess(data: HeartbeatImportStatusProps) {
    importOverlay = data;
    overlayStartTime = Date.now();
    startPolling();
  }

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

<svelte:head>
  <title>Imports & Exports - Hackatime Settings</title>
</svelte:head>

<SettingsShell
  {active_section}
  {page_title}
  {heading}
  {subheading}
  {errors}
  hidden_subsections={hiddenSubsections}
>
  {#if ui.show_imports}
    <Form
      method="post"
      action={createHeartbeatImportPath}
      resetOnSuccess={["heartbeat_import[api_key]"]}
      options={{ preserveScroll: true }}
      onSuccess={(page) =>
        onImportSuccess(
          page.props.latest_heartbeat_import as HeartbeatImportStatusProps,
        )}
    >
      {#snippet children({ processing, errors: formErrors })}
        <SectionCard
          id="user_imports"
          title="Imports"
          description="Request a one-time heartbeat dump from WakaTime or legacy Hackatime."
          wide
          footerClass=""
        >
          <div class="space-y-4">
            <div class="space-y-3">
              {#each PROVIDERS as provider}
                <label
                  class="flex cursor-pointer items-start gap-3 rounded-md border border-surface-200 bg-surface-100 px-3 py-3 text-sm text-surface-content hover:border-surface-300"
                >
                  <input
                    type="radio"
                    name="heartbeat_import[provider]"
                    value={provider.value}
                    bind:group={remoteProvider}
                    class="mt-1 h-4 w-4 shrink-0 cursor-pointer border-2 border-surface-300 text-primary focus:ring-2 focus:ring-primary focus:ring-offset-2"
                    disabled={importInProgress || processing}
                  />
                  <span class="space-y-1">
                    <span class="block font-semibold">{provider.label}</span>
                    <span class="block text-xs text-muted"
                      >{provider.helper}</span
                    >
                  </span>
                </label>
              {/each}
            </div>

            <div class="max-w-2xl">
              <label
                for="remote_import_api_key"
                class="mb-2 block text-sm text-surface-content"
              >
                API Key
              </label>
              <input
                id="remote_import_api_key"
                name="heartbeat_import[api_key]"
                type="password"
                bind:value={remoteApiKey}
                class="w-full rounded-md border border-surface-200 bg-input px-3 py-2 text-base text-surface-content focus:border-primary focus:outline-none"
                disabled={importInProgress || processing}
              />
            </div>

            {#if formErrors.import}
              <p class="text-sm text-red-300">{formErrors.import}</p>
            {/if}

            {#if importState !== "idle" && latestImportIsRemote}
              <ImportStatusRow
                label={providerLabel(importSourceKind)}
                state={importState}
                inProgress={importInProgress}
                errorMessage={activeImport?.error_message}
                {completedSummary}
              />
            {/if}
          </div>

          {#snippet footer()}
            <div
              class="flex flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:justify-between"
            >
              {#if remoteCooldownActive && effectiveRemoteCooldownUntil}
                <p class="text-sm text-muted sm:mr-auto">
                  Available again in {formatRelativeTime(
                    effectiveRemoteCooldownUntil,
                  )}
                </p>
              {:else}
                <div></div>
              {/if}
              <div class="w-full sm:w-auto">
                <Button
                  type="submit"
                  variant="primary"
                  class="w-full"
                  disabled={!imports_enabled ||
                    remoteCooldownActive ||
                    !remoteApiKey.trim() ||
                    importInProgress ||
                    processing}
                >
                  {#if processing}
                    Starting remote import...
                  {:else if importInProgress && latestImportIsRemote}
                    Import in progress...
                  {:else}
                    Start remote import
                  {/if}
                </Button>
              </div>
            </div>
          {/snippet}
        </SectionCard>
      {/snippet}
    </Form>
  {/if}

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
            <div
              class="rounded-md border border-surface-200 bg-darker px-3 py-3"
            >
              <div class="h-3 w-24 animate-pulse rounded bg-surface-200"></div>
              <div
                class="mt-3 h-5 w-16 animate-pulse rounded bg-surface-200"
              ></div>
            </div>
          {/each}
        </div>
        <div class="mt-3 h-4 w-64 animate-pulse rounded bg-surface-200"></div>
      {/snippet}

      {#if !data_export}
        <!-- waiting for deferred data -->
      {:else if data_export.is_restricted}
        <p
          class="rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red-200"
        >
          Data export is currently restricted for this account.
        </p>
      {:else}
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {@render statTile("Total heartbeats", data_export.total_heartbeats)}
          {@render statTile("Total coding time", data_export.total_coding_time)}
          {@render statTile("Last 7 days", data_export.heartbeats_last_7_days)}
        </div>

        <p class="mt-3 text-sm text-muted">
          Exports are generated in the background and emailed to you.
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

        {#if ui.show_dev_import}
          <Form
            method="post"
            action={createHeartbeatImportPath}
            class="mt-4 rounded-md border border-surface-200 bg-darker p-4"
            resetOnSuccess={["heartbeat_file"]}
            options={{ preserveScroll: true }}
            onSuccess={() => {
              selectedFile = null;
            }}
          >
            {#snippet children({ processing, errors: formErrors })}
              <label
                class="mb-2 block text-sm text-surface-content"
                for="heartbeat_file"
              >
                Import heartbeats (development only)
              </label>
              <input
                id="heartbeat_file"
                name="heartbeat_file"
                type="file"
                accept=".json,application/json"
                required
                disabled={importInProgress || processing}
                onchange={(event) => {
                  selectedFile =
                    (event.currentTarget as HTMLInputElement).files?.[0] ??
                    null;
                }}
                class="w-full rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content disabled:cursor-not-allowed disabled:opacity-60"
              />

              {#if formErrors.import}
                <p class="mt-2 text-sm text-red-300">{formErrors.import}</p>
              {/if}

              <Button
                type="submit"
                variant="surface"
                class="mt-3 rounded-md"
                disabled={!selectedFile || importInProgress || processing}
              >
                {#if processing}
                  Starting import...
                {:else if importInProgress && latestImportIsDev}
                  Importing...
                {:else}
                  Import file
                {/if}
              </Button>

              {#if importState !== "idle" && latestImportIsDev}
                <div class="mt-4">
                  <ImportStatusRow
                    label={activeImport?.source_filename ||
                      providerLabel(importSourceKind)}
                    state={importState}
                    inProgress={importInProgress}
                    errorMessage={activeImport?.error_message}
                    {completedSummary}
                    bgClass="bg-surface"
                  />
                </div>
              {/if}
            {/snippet}
          </Form>
        {/if}
      {/if}
    </Deferred>
  </SectionCard>
</SettingsShell>
