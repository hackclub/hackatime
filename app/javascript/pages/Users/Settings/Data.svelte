<script lang="ts">
  import { usePoll } from "@inertiajs/svelte";
  import { onMount } from "svelte";
  import { tweened } from "svelte/motion";
  import { cubicOut } from "svelte/easing";
  import Button from "../../../components/Button.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { DataPageProps } from "./types";

  type ImportStatusPayload = NonNullable<
    DataPageProps["heartbeat_import"]["status"]
  >;
  type ImportCreateResponse = {
    import_id?: string;
    status?: ImportStatusPayload;
    error?: string;
  };

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    user,
    paths,
    migration,
    data_export,
    ui,
    heartbeat_import,
    errors,
    admin_tools,
  }: DataPageProps = $props();

  let csrfToken = $state("");
  let selectedFile = $state<File | null>(null);
  let importId = $state("");
  let importState = $state("idle");
  let importMessage = $state("");
  let submitError = $state("");
  let processedCount = $state<number | null>(null);
  let totalCount = $state<number | null>(null);
  let importedCount = $state<number | null>(null);
  let skippedCount = $state<number | null>(null);
  let errorsCount = $state(0);
  let isStartingImport = $state(false);
  let isPolling = $state(false);
  const importPollParams: { heartbeat_import_id?: string } = {};
  const tweenedProgress = tweened(0, { duration: 320, easing: cubicOut });

  const importInProgress = $derived(
    importState === "queued" ||
      importState === "counting" ||
      importState === "running",
  );

  const { start: startStatusPolling, stop: stopStatusPolling } = usePoll(
    1000,
    {
      only: ["heartbeat_import"],
      data: importPollParams,
      preserveUrl: true,
      onHttpException: () => {
        if (importInProgress) {
          importMessage =
            "Connection issue while checking import status. Retrying...";
        }
      },
      onNetworkError: () => {
        if (importInProgress) {
          importMessage =
            "Connection issue while checking import status. Retrying...";
        }
      },
    },
    { autoStart: false },
  );

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";

    syncImportFromProps(heartbeat_import);
  });

  $effect(() => {
    syncImportFromProps(heartbeat_import);
  });

  function isTerminalImportState(state: string) {
    return state === "completed" || state === "failed";
  }

  function stopPolling() {
    stopStatusPolling();
    delete importPollParams.heartbeat_import_id;
    isPolling = false;
  }

  function startPolling() {
    if (!importId) {
      return;
    }
    if (isPolling && importPollParams.heartbeat_import_id === importId) {
      return;
    }
    stopStatusPolling();
    importPollParams.heartbeat_import_id = importId;
    startStatusPolling();
    isPolling = true;
  }

  function formatCount(value: number | null) {
    if (value === null || value === undefined) {
      return "—";
    }
    return value.toLocaleString();
  }

  function applyImportStatus(status: Partial<ImportStatusPayload>) {
    const state = status.state || "idle";
    const progress = Number(status.progress_percent ?? 0);
    const normalizedProgress = Number.isFinite(progress)
      ? Math.min(Math.max(progress, 0), 100)
      : 0;

    importState = state;
    importMessage = status.message || importMessage;
    processedCount = status.processed_count ?? processedCount;
    totalCount = status.total_count ?? totalCount;
    importedCount = status.imported_count ?? importedCount;
    skippedCount = status.skipped_count ?? skippedCount;
    errorsCount = status.errors_count ?? errorsCount;
    void tweenedProgress.set(normalizedProgress);
  }

  function syncImportFromProps(
    serverImport: DataPageProps["heartbeat_import"],
  ) {
    if (!serverImport) {
      return;
    }

    if (serverImport.import_id) {
      if (importId && serverImport.import_id !== importId) {
        return;
      }
      importId = serverImport.import_id;
    }

    if (serverImport.import_id && !serverImport.status) {
      stopPolling();
      importState = "failed";
      importMessage = "Import status could not be found.";
      return;
    }

    if (!serverImport.status) {
      return;
    }

    applyImportStatus(serverImport.status);
    if (isTerminalImportState(serverImport.status.state)) {
      stopPolling();
      return;
    }

    if (importId) {
      startPolling();
    }
  }

  function resetImportState() {
    importState = "queued";
    importMessage = "Queued import.";
    submitError = "";
    processedCount = 0;
    totalCount = null;
    importedCount = null;
    skippedCount = null;
    errorsCount = 0;
    void tweenedProgress.set(0);
  }

  async function startImport(event: SubmitEvent) {
    event.preventDefault();
    submitError = "";

    if (!selectedFile) {
      submitError = "Please choose a JSON file to import.";
      return;
    }

    isStartingImport = true;
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

      if (!payload.import_id) {
        throw new Error("Unable to start import.");
      }

      importId = payload.import_id;
      if (payload.status) {
        applyImportStatus(payload.status);
      }
      startPolling();
    } catch (error) {
      importState = "failed";
      importMessage = "Import failed to start.";
      submitError =
        error instanceof Error ? error.message : "Unable to start import.";
    } finally {
      isStartingImport = false;
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
  {admin_tools}
>
  <div class="space-y-8">
    <section id="user_migration_assistant">
      <h2 class="text-xl font-semibold text-surface-content">
        Migration Assistant
      </h2>
      <p class="mt-1 text-sm text-muted">
        Queue migration of heartbeats and API keys from legacy Hackatime.
      </p>
      <form method="post" action={paths.migrate_heartbeats_path} class="mt-4">
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <Button type="submit" class="rounded-md">Start migration</Button>
      </form>

      {#if migration.jobs.length > 0}
        <div class="mt-4 space-y-2">
          {#each migration.jobs as job}
            <div
              class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content"
            >
              Job {job.id}: {job.status}
            </div>
          {/each}
        </div>
      {/if}
    </section>

    <section id="download_user_data">
      <h2 class="text-xl font-semibold text-surface-content">Download Data</h2>

      {#if data_export.is_restricted}
        <p
          class="mt-3 rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red-200"
        >
          Data export is currently restricted for this account.
        </p>
      {:else}
        <p class="mt-1 text-sm text-muted">
          Download your coding history as JSON for backups or analysis.
        </p>

        <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
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
            <p class="text-xs uppercase tracking-wide text-muted">
              Last 7 days
            </p>
            <p class="mt-1 text-lg font-semibold text-surface-content">
              {data_export.heartbeats_last_7_days}
            </p>
          </div>
        </div>

        <div class="mt-4 space-y-3">
          <Button href={paths.export_all_heartbeats_path} class="rounded-md">
            Export all heartbeats
          </Button>

          <form
            method="get"
            action={paths.export_range_heartbeats_path}
            class="grid grid-cols-1 gap-3 rounded-md border border-surface-200 bg-darker p-4 sm:grid-cols-3"
          >
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
            <Button type="submit" variant="surface" class="rounded-md">
              Export date range
            </Button>
          </form>
        </div>

        {#if ui.show_dev_import}
          <form
            class="mt-4 rounded-md border border-surface-200 bg-darker p-4"
            onsubmit={startImport}
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
              disabled={importInProgress || isStartingImport}
              onchange={(event) => {
                const target = event.currentTarget as HTMLInputElement;
                selectedFile = target.files?.[0] ?? null;
              }}
              class="w-full rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content disabled:cursor-not-allowed disabled:opacity-60"
            />

            {#if submitError}
              <p class="mt-2 text-sm text-red-300">{submitError}</p>
            {/if}

            <Button
              type="submit"
              variant="surface"
              class="mt-3 rounded-md"
              disabled={!selectedFile || importInProgress || isStartingImport}
            >
              {#if isStartingImport}
                Starting import...
              {:else if importInProgress}
                Importing...
              {:else}
                Import file
              {/if}
            </Button>

            {#if importState !== "idle"}
              <div
                class="mt-4 rounded-md border border-surface-200 bg-surface p-3"
              >
                <div class="flex items-center justify-between">
                  <p class="text-sm font-medium text-surface-content">
                    Status: {importState}
                  </p>
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
                {#if importMessage}
                  <p class="mt-1 text-sm text-muted">{importMessage}</p>
                {/if}
                {#if importState === "completed"}
                  <p class="mt-1 text-sm text-muted">
                    Imported: {formatCount(importedCount)}. Skipped {formatCount(
                      skippedCount,
                    )} duplicates and {errorsCount.toLocaleString()} errors
                  </p>
                {/if}
              </div>
            {/if}
          </form>
        {/if}
      {/if}
    </section>

    <section id="delete_account">
      <h2 class="text-xl font-semibold text-surface-content">
        Account Deletion
      </h2>
      {#if user.can_request_deletion}
        <p class="mt-1 text-sm text-muted">
          Request permanent deletion. The account enters a waiting period before
          final removal.
        </p>
        <form
          method="post"
          action={paths.create_deletion_path}
          class="mt-4"
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
      {:else}
        <p
          class="mt-3 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
        >
          Deletion request is unavailable for this account right now.
        </p>
      {/if}
    </section>
  </div>
</SettingsShell>
