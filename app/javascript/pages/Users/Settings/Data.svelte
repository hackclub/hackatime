<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { onMount } from "svelte";
  import { tweened } from "svelte/motion";
  import { cubicOut } from "svelte/easing";
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { DataPageProps, HeartbeatImportStatusProps } from "./types";

  type ImportCreateResponse = {
    import_id?: string;
    status?: HeartbeatImportStatusProps;
    error?: string;
    retry_at?: string;
  };

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

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    user,
    paths,
    data_export,
    imports_enabled,
    remote_import_cooldown_until,
    latest_heartbeat_import,
    ui,
    errors,
  }: DataPageProps = $props();

  let csrfToken = $state("");
  let selectedFile = $state<File | null>(null);
  let remoteProvider =
    $state<(typeof PROVIDERS)[number]["value"]>("wakatime_dump");
  let remoteApiKey = $state("");
  let importId = $state("");
  let importState = $state("idle");
  let importSourceKind = $state("");
  let importMessage = $state("");
  let importErrorMessage = $state("");
  let processedCount = $state<number | null>(null);
  let totalCount = $state<number | null>(null);
  let importedCount = $state<number | null>(null);
  let skippedCount = $state<number | null>(null);
  let errorsCount = $state(0);
  let remoteDumpStatus = $state<string | null>(null);
  let remotePercentComplete = $state<number | null>(null);
  let sourceFilename = $state<string | null>(null);
  let devSubmitError = $state("");
  let remoteSubmitError = $state("");
  let remoteCooldownUntil = $state<string | null>(null);
  let isStartingDevImport = $state(false);
  let isStartingRemoteImport = $state(false);
  let pollingHandle = $state<number | null>(null);
  const tweenedProgress = tweened(0, { duration: 320, easing: cubicOut });

  const importInProgress = $derived(
    importState === "queued" ||
      importState === "requesting_dump" ||
      importState === "waiting_for_dump" ||
      importState === "downloading_dump" ||
      importState === "importing",
  );
  const latestImportIsRemote = $derived(
    importSourceKind === "wakatime_dump" ||
      importSourceKind === "hackatime_v1_dump",
  );
  const latestImportIsDev = $derived(importSourceKind === "dev_upload");
  const remoteCooldownActive = $derived(
    remoteCooldownUntil
      ? new Date(remoteCooldownUntil).getTime() > Date.now()
      : false,
  );

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";

    syncImport(latest_heartbeat_import, true);

    return () => {
      stopPolling();
    };
  });

  $effect(() => {
    if (remote_import_cooldown_until) {
      remoteCooldownUntil = remote_import_cooldown_until;
    }
  });

  $effect(() => {
    syncImport(latest_heartbeat_import);
  });

  function isTerminalImportState(state: string) {
    return state === "completed" || state === "failed";
  }

  function importStatusPath(id: string) {
    return paths.heartbeat_import_path.replace("__IMPORT_ID__", id);
  }

  function stopPolling() {
    if (pollingHandle) {
      window.clearInterval(pollingHandle);
      pollingHandle = null;
    }
  }

  function startPolling() {
    if (!importId || isTerminalImportState(importState) || pollingHandle) {
      return;
    }

    pollingHandle = window.setInterval(() => {
      void pollImportStatus();
    }, 1000);
  }

  async function pollImportStatus() {
    if (!importId) {
      return;
    }

    try {
      const response = await fetch(importStatusPath(importId), {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      });
      const payload = (await response.json()) as HeartbeatImportStatusProps & {
        error?: string;
      };

      if (!response.ok) {
        throw new Error(payload.error || "Import status could not be loaded.");
      }

      syncImport(payload, true);
    } catch (_error) {
      if (importInProgress) {
        importMessage =
          "Connection issue while checking import status. Retrying...";
      } else {
        stopPolling();
      }
    }
  }

  function formatCount(value: number | null) {
    if (value === null || value === undefined) {
      return "—";
    }
    return value.toLocaleString();
  }

  function formatDateTime(value: string | null) {
    if (!value) {
      return "—";
    }

    return new Date(value).toLocaleString();
  }

  function providerLabel(sourceKind: string) {
    if (sourceKind === "wakatime_dump") {
      return "WakaTime";
    }
    if (sourceKind === "hackatime_v1_dump") {
      return "Hackatime v1";
    }
    if (sourceKind === "dev_upload") {
      return "Development upload";
    }
    return "Import";
  }

  function applyImportStatus(status: Partial<HeartbeatImportStatusProps>) {
    const state = status.state || "idle";
    const progress = Number(status.progress_percent ?? 0);
    const normalizedProgress = Number.isFinite(progress)
      ? Math.min(Math.max(progress, 0), 100)
      : 0;

    importId = status.import_id || importId;
    importState = state;
    importSourceKind = status.source_kind || importSourceKind;
    importMessage = status.message || importMessage;
    importErrorMessage = status.error_message || "";
    processedCount = status.processed_count ?? processedCount;
    totalCount = status.total_count ?? totalCount;
    importedCount = status.imported_count ?? importedCount;
    skippedCount = status.skipped_count ?? skippedCount;
    errorsCount = status.errors_count ?? errorsCount;
    remoteDumpStatus = status.remote_dump_status ?? remoteDumpStatus;
    remotePercentComplete =
      status.remote_percent_complete ?? remotePercentComplete;
    sourceFilename = status.source_filename ?? sourceFilename;
    if (status.cooldown_until) {
      remoteCooldownUntil = status.cooldown_until;
    }
    void tweenedProgress.set(normalizedProgress);
  }

  function syncImport(
    serverImport:
      | DataPageProps["latest_heartbeat_import"]
      | HeartbeatImportStatusProps
      | null
      | undefined,
    force = false,
  ) {
    if (!serverImport) {
      return;
    }

    if (!force && importId && serverImport.import_id !== importId) {
      return;
    }

    applyImportStatus(serverImport);

    if (isTerminalImportState(serverImport.state)) {
      stopPolling();
      return;
    }

    startPolling();
  }

  function resetImportState() {
    importState = "queued";
    importMessage = "Queued import.";
    importErrorMessage = "";
    processedCount = 0;
    totalCount = null;
    importedCount = null;
    skippedCount = null;
    errorsCount = 0;
    remoteDumpStatus = null;
    remotePercentComplete = null;
    sourceFilename = null;
    void tweenedProgress.set(0);
  }

  async function startDevImport(event: SubmitEvent) {
    event.preventDefault();
    devSubmitError = "";

    if (!selectedFile) {
      devSubmitError = "Please choose a JSON file to import.";
      return;
    }

    isStartingDevImport = true;
    resetImportState();
    stopPolling();

    const formData = new FormData();
    formData.append("heartbeat_file", selectedFile);

    try {
      const response = await fetch(paths.create_heartbeat_import_path, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: formData,
      });
      const payload = (await response.json()) as ImportCreateResponse;

      if (!response.ok) {
        throw new Error(payload.error || "Unable to start import.");
      }

      if (!payload.status) {
        throw new Error("Unable to start import.");
      }

      syncImport(payload.status, true);
      startPolling();
    } catch (error) {
      importState = "failed";
      importMessage = "Import failed to start.";
      devSubmitError =
        error instanceof Error ? error.message : "Unable to start import.";
    } finally {
      isStartingDevImport = false;
    }
  }

  async function startRemoteImport(event: SubmitEvent) {
    event.preventDefault();
    remoteSubmitError = "";

    if (!remoteApiKey.trim()) {
      remoteSubmitError = "API key is required.";
      return;
    }

    isStartingRemoteImport = true;
    resetImportState();
    stopPolling();

    const formData = new FormData();
    formData.append("heartbeat_import[provider]", remoteProvider);
    formData.append("heartbeat_import[api_key]", remoteApiKey);

    try {
      const response = await fetch(paths.create_heartbeat_import_path, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
        credentials: "same-origin",
        body: formData,
      });
      const payload = (await response.json()) as ImportCreateResponse;

      if (!response.ok) {
        if (payload.retry_at) {
          remoteCooldownUntil = payload.retry_at;
        }
        throw new Error(payload.error || "Unable to start import.");
      }

      if (!payload.status) {
        throw new Error("Unable to start import.");
      }

      remoteApiKey = "";
      syncImport(payload.status, true);
      startPolling();
    } catch (error) {
      importState = "failed";
      importMessage = "Import failed to start.";
      remoteSubmitError =
        error instanceof Error ? error.message : "Unable to start import.";
    } finally {
      isStartingRemoteImport = false;
    }
  }
</script>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
>
  {#if ui.show_imports}
    <SectionCard
      id="user_imports"
      title="Imports"
      description="Request a one-time heartbeat dump from WakaTime or legacy Hackatime."
      wide
    >
      {#if remoteCooldownActive && remoteCooldownUntil}
        <p
          class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
        >
          Remote imports can be started again after {formatDateTime(
            remoteCooldownUntil,
          )}.
        </p>
      {/if}

      <form
        id="remote-import-form"
        class="mt-4 space-y-4 rounded-md border border-surface-200 bg-surface p-4"
        onsubmit={startRemoteImport}
      >
        <div class="space-y-3">
          {#each PROVIDERS as provider}
            <label
              class="flex cursor-pointer items-start gap-3 rounded-md border border-surface-200 bg-darker px-3 py-3 text-sm text-surface-content"
            >
              <input
                type="radio"
                name="import_provider"
                value={provider.value}
                checked={remoteProvider === provider.value}
                onchange={() => {
                  remoteProvider = provider.value;
                }}
                class="mt-1 h-4 w-4 border-surface-200 bg-surface text-primary"
              />
              <span class="space-y-1">
                <span class="block font-semibold">{provider.label}</span>
                <span class="block text-xs text-muted">{provider.helper}</span>
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
            type="password"
            bind:value={remoteApiKey}
            class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-surface-content focus:border-primary focus:outline-none"
            disabled={importInProgress || isStartingRemoteImport}
          />
        </div>

        {#if remoteSubmitError}
          <p class="text-sm text-red-300">{remoteSubmitError}</p>
        {/if}

        {#if importState !== "idle" && latestImportIsRemote}
          <div class="rounded-md border border-surface-200 bg-darker p-3">
            <div class="flex items-center justify-between gap-3">
              <div>
                <p class="text-sm font-medium text-surface-content">
                  {providerLabel(importSourceKind)}
                </p>
                <p class="text-xs text-muted">Status: {importState}</p>
              </div>
              <p class="text-sm font-semibold text-primary">
                {Math.round($tweenedProgress)}%
              </p>
            </div>
            <progress
              max="100"
              value={$tweenedProgress}
              class="mt-2 h-2 w-full rounded-full bg-surface-200 accent-primary"
            ></progress>
            {#if remoteDumpStatus}
              <p class="mt-2 text-sm text-muted">
                Remote dump: {remoteDumpStatus}
                {#if remotePercentComplete !== null}
                  ({Math.round(remotePercentComplete)}%)
                {/if}
              </p>
            {/if}
            {#if importErrorMessage}
              <p class="mt-1 text-sm text-red-300">{importErrorMessage}</p>
            {/if}
            {#if importState === "completed"}
              <p class="mt-1 text-sm text-muted">
                Imported: {formatCount(importedCount)}. Skipped {formatCount(
                  skippedCount,
                )} duplicates and {errorsCount.toLocaleString()} errors.
              </p>
            {/if}
          </div>
        {/if}
      </form>

      {#snippet footer()}
        <Button
          type="submit"
          variant="primary"
          form="remote-import-form"
          disabled={!imports_enabled ||
            remoteCooldownActive ||
            !remoteApiKey.trim() ||
            importInProgress ||
            isStartingRemoteImport}
        >
          {#if isStartingRemoteImport}
            Starting remote import...
          {:else if importInProgress && latestImportIsRemote}
            Import in progress...
          {:else}
            Start remote import
          {/if}
        </Button>
      {/snippet}
    </SectionCard>
  {/if}

  <SectionCard
    id="download_user_data"
    title="Download Data"
    description="Download your coding history as JSON for backups or analysis."
    wide
  >
    {#if data_export.is_restricted}
      <p
        class="rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red-200"
      >
        Data export is currently restricted for this account.
      </p>
    {:else}
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
          <p class="text-xs uppercase tracking-wide text-muted">
            Total heartbeats
          </p>
          <p class="mt-1 text-lg font-semibold text-surface-content">
            {data_export.total_heartbeats}
          </p>
        </div>
        <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
          <p class="text-xs uppercase tracking-wide text-muted">
            Total coding time
          </p>
          <p class="mt-1 text-lg font-semibold text-surface-content">
            {data_export.total_coding_time}
          </p>
        </div>
        <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
          <p class="text-xs uppercase tracking-wide text-muted">Last 7 days</p>
          <p class="mt-1 text-lg font-semibold text-surface-content">
            {data_export.heartbeats_last_7_days}
          </p>
        </div>
      </div>

      <p class="mt-3 text-sm text-muted">
        Exports are generated in the background and emailed to you.
      </p>

      <div class="mt-4 space-y-3">
        <Form method="post" action={paths.export_all_heartbeats_path}>
          {#snippet children({ processing })}
            <Button
              type="submit"
              class="rounded-md cursor-default"
              disabled={processing}
            >
              {processing ? "Exporting..." : "Export all heartbeats"}
            </Button>
          {/snippet}
        </Form>

        <Form
          method="post"
          action={paths.export_range_heartbeats_path}
          class="grid grid-cols-1 gap-3 rounded-md border border-surface-200 bg-darker p-4 sm:grid-cols-3"
        >
          {#snippet children({ processing })}
            <input
              type="date"
              name="start_date"
              required
              class="rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
            />
            <input
              type="date"
              name="end_date"
              required
              class="rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
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
        <form
          class="mt-4 rounded-md border border-surface-200 bg-darker p-4"
          onsubmit={startDevImport}
        >
          <label
            class="mb-2 block text-sm text-surface-content"
            for="heartbeat_file"
          >
            Import heartbeats (development only)
          </label>
          <input
            id="heartbeat_file"
            type="file"
            accept=".json,application/json"
            disabled={importInProgress || isStartingDevImport}
            onchange={(event) => {
              const target = event.currentTarget as HTMLInputElement;
              selectedFile = target.files?.[0] ?? null;
            }}
            class="w-full rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content disabled:cursor-not-allowed disabled:opacity-60"
          />

          {#if devSubmitError}
            <p class="mt-2 text-sm text-red-300">{devSubmitError}</p>
          {/if}

          <Button
            type="submit"
            variant="surface"
            class="mt-3 rounded-md"
            disabled={!selectedFile || importInProgress || isStartingDevImport}
          >
            {#if isStartingDevImport}
              Starting import...
            {:else if importInProgress && latestImportIsDev}
              Importing...
            {:else}
              Import file
            {/if}
          </Button>

          {#if importState !== "idle" && latestImportIsDev}
            <div
              class="mt-4 rounded-md border border-surface-200 bg-surface p-3"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-surface-content">
                    {providerLabel(importSourceKind)}
                  </p>
                  <p class="text-xs text-muted">Status: {importState}</p>
                </div>
                <p class="text-sm font-semibold text-primary">
                  {Math.round($tweenedProgress)}%
                </p>
              </div>
              <progress
                max="100"
                value={$tweenedProgress}
                class="mt-2 h-2 w-full rounded-full bg-surface-200 accent-primary"
              ></progress>
              <p class="mt-2 text-sm text-muted">
                {formatCount(processedCount)} / {formatCount(totalCount)} processed
              </p>
              {#if sourceFilename}
                <p class="mt-1 text-sm text-muted">File: {sourceFilename}</p>
              {/if}
              {#if importMessage}
                <p class="mt-1 text-sm text-muted">{importMessage}</p>
              {/if}
              {#if importErrorMessage}
                <p class="mt-1 text-sm text-red-300">{importErrorMessage}</p>
              {/if}
              {#if importState === "completed"}
                <p class="mt-1 text-sm text-muted">
                  Imported: {formatCount(importedCount)}. Skipped {formatCount(
                    skippedCount,
                  )} duplicates and {errorsCount.toLocaleString()} errors.
                </p>
              {/if}
            </div>
          {/if}
        </form>
      {/if}
    {/if}
  </SectionCard>

  {#if user.can_request_deletion}
    <SectionCard
      id="delete_account"
      title="Account Deletion"
      description="Request permanent deletion. The account enters a waiting period before final removal."
      tone="danger"
      hasBody={false}
    >
      {#snippet footer()}
        <form
          method="post"
          action={paths.create_deletion_path}
          class="m-0"
          onsubmit={(event) => {
            if (
              !window.confirm(
                "Submit account deletion request? This action starts the deletion process.",
              )
            ) {
              event.preventDefault();
            }
          }}
        >
          <input type="hidden" name="authenticity_token" value={csrfToken} />
          <Button type="submit" variant="surface" class="rounded-md">
            Request deletion
          </Button>
        </form>
      {/snippet}
    </SectionCard>
  {:else}
    <SectionCard
      id="delete_account"
      title="Account Deletion"
      description="Request permanent deletion. The account enters a waiting period before final removal."
      tone="danger"
    >
      <p
        class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
      >
        Deletion request is unavailable for this account right now.
      </p>
    </SectionCard>
  {/if}
</SettingsShell>
