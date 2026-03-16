<script lang="ts">
  import { Deferred, Form, usePoll } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { DataPageProps, HeartbeatImportStatusProps } from "./types";

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

  // Maximum time to show optimistic overlay before falling back to server state (5 minutes)
  const OVERLAY_TIMEOUT_MS = 5 * 60 * 1000;

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

  let selectedFile = $state<File | null>(null);
  let remoteProvider =
    $state<(typeof PROVIDERS)[number]["value"]>("wakatime_dump");
  let remoteApiKey = $state("");
  // overlay state: set after a successful form submit, cleared when server confirms or timeout
  let importOverlay = $state<Partial<HeartbeatImportStatusProps> | null>(null);
  let overlayStartTime = $state<number | null>(null);

  const { start: startPolling, stop: stopPolling } = usePoll(
    1000,
    { only: ["latest_heartbeat_import", "remote_import_cooldown_until"] },
    { autoStart: false },
  );

  const serverHasImport = $derived(latest_heartbeat_import != null);
  const serverState = $derived(latest_heartbeat_import?.state);
  const isServerTerminal = $derived(
    serverState === "completed" || serverState === "failed",
  );
  const isOverlayStale = $derived(() => {
    if (!overlayStartTime) return false;
    return Date.now() - overlayStartTime > OVERLAY_TIMEOUT_MS;
  });

  const effectiveImport = $derived(() => {
    if (isOverlayStale()) {
      return latest_heartbeat_import;
    }
    if (isServerTerminal && importOverlay) {
      return latest_heartbeat_import;
    }
    return importOverlay ?? latest_heartbeat_import;
  });

  const activeImport = $derived(effectiveImport());
  const importState = $derived(activeImport?.state ?? "idle");
  const importSourceKind = $derived(activeImport?.source_kind ?? "");

  const importInProgress = $derived(
    importState === "queued" ||
      importState === "requesting_dump" ||
      importState === "waiting_for_dump" ||
      importState === "downloading_dump" ||
      importState === "importing",
  );
  const latestImportIsRemote = $derived(
    importSourceKind === "wakatime_dump" ||
      importSourceKind === "wakatime_download_link" ||
      importSourceKind === "hackatime_v1_dump",
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
    if (importInProgress) {
      startPolling();
    } else {
      stopPolling();
    }
  });

  $effect(() => {
    if (!importOverlay) return;

    if (isServerTerminal && serverHasImport) {
      importOverlay = null;
      overlayStartTime = null;
      return;
    }

    if (overlayStartTime) {
      const elapsed = Date.now() - overlayStartTime;
      const remaining = Math.max(0, OVERLAY_TIMEOUT_MS - elapsed);

      const timeoutId = setTimeout(() => {
        importOverlay = null;
        overlayStartTime = null;
        stopPolling();
      }, remaining);

      return () => clearTimeout(timeoutId);
    }
  });

  function formatCount(value: number | null | undefined) {
    if (value == null) return "—";
    return value.toLocaleString();
  }

  function formatRelativeTime(value: string | null) {
    if (!value) return "—";
    const diff = new Date(value).getTime() - Date.now();
    if (diff <= 0) return "now";
    const seconds = Math.ceil(diff / 1000);
    if (seconds < 60) return `${seconds}s`;
    return `${Math.ceil(seconds / 60)}m`;
  }

  function providerLabel(sourceKind: string) {
    switch (sourceKind) {
      case "wakatime_dump":
      case "wakatime_download_link":
        return "WakaTime";
      case "hackatime_v1_dump":
        return "Hackatime v1";
      case "dev_upload":
        return "Development upload";
      default:
        return "Import";
    }
  }

  function prettyStatus(state: string): string {
    switch (state) {
      case "queued":
        return "Queued…";
      case "requesting_dump":
        return "Requesting heartbeats…";
      case "waiting_for_dump":
        return "Waiting for heartbeats…";
      case "downloading_dump":
        return "Downloading heartbeats…";
      case "importing":
        return "Importing heartbeats…";
      case "completed":
        return "Done!";
      case "failed":
        return "Failed";
      default:
        return state;
    }
  }

  function onImportSuccess(data: HeartbeatImportStatusProps) {
    importOverlay = data;
    overlayStartTime = Date.now();
    startPolling();
  }
</script>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
  hidden_subsections={hiddenSubsections}
>
  {#if ui.show_imports}
    <Form
      method="post"
      action={paths.create_heartbeat_import_path}
      resetOnSuccess={["heartbeat_import[api_key]"]}
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
                    <span class="block text-xs text-muted">
                      {provider.helper}
                    </span>
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
                class="w-full rounded-md border border-surface-200 bg-darker px-3 py-2 text-base text-surface-content focus:border-primary focus:outline-none"
                disabled={importInProgress || processing}
              />
            </div>

            {#if formErrors.import}
              <p class="text-sm text-red-300">{formErrors.import}</p>
            {/if}

            {#if importState !== "idle" && latestImportIsRemote}
              <div
                class="flex flex-wrap items-center gap-2 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm"
              >
                {#if importInProgress}
                  <svg
                    class="h-4 w-4 shrink-0 animate-spin text-primary"
                    viewBox="0 0 24 24"
                    fill="none"
                  >
                    <circle
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="3"
                      class="opacity-25"
                    />
                    <path
                      d="M4 12a8 8 0 018-8"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                    />
                  </svg>
                {/if}
                <span class="text-surface-content">
                  {providerLabel(importSourceKind)}
                </span>
                <span class="text-muted">·</span>
                <span
                  class={importState === "failed"
                    ? "text-red-500 dark:text-red-300"
                    : importState === "completed"
                      ? "text-primary"
                      : "text-muted"}
                >
                  {prettyStatus(importState)}
                </span>
                {#if activeImport?.error_message}
                  <span class="text-red-300">{activeImport.error_message}</span>
                {/if}
                {#if importState === "completed"}
                  <span class="text-muted">
                    {formatCount(activeImport?.imported_count)} imported, {formatCount(
                      activeImport?.skipped_count,
                    )} skipped
                  </span>
                {/if}
              </div>
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

        <p class="mt-3 text-sm text-muted">
          Exports are generated in the background and emailed to you.
        </p>

        <div class="mt-4 space-y-3">
          <Form method="post" action={paths.export_all_heartbeats_path}>
            {#snippet children({ processing })}
              <Button type="submit" class="rounded-md" disabled={processing}>
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
          <Form
            method="post"
            action={paths.create_heartbeat_import_path}
            class="mt-4 rounded-md border border-surface-200 bg-darker p-4"
            resetOnSuccess={["heartbeat_file"]}
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
                  const target = event.currentTarget as HTMLInputElement;
                  selectedFile = target.files?.[0] ?? null;
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
                <div
                  class="mt-4 flex items-center gap-2 rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm"
                >
                  {#if importInProgress}
                    <svg
                      class="h-4 w-4 shrink-0 animate-spin text-primary"
                      viewBox="0 0 24 24"
                      fill="none"
                    >
                      <circle
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="3"
                        class="opacity-25"
                      />
                      <path
                        d="M4 12a8 8 0 018-8"
                        stroke="currentColor"
                        stroke-width="3"
                        stroke-linecap="round"
                      />
                    </svg>
                  {/if}
                  <span class="text-surface-content">
                    {activeImport?.source_filename ||
                      providerLabel(importSourceKind)}
                  </span>
                  <span class="text-muted">·</span>
                  <span
                    class={importState === "failed"
                      ? "text-red-300"
                      : importState === "completed"
                        ? "text-green-300"
                        : "text-muted"}
                  >
                    {prettyStatus(importState)}
                  </span>
                  {#if activeImport?.error_message}
                    <span class="text-red-300"
                      >{activeImport.error_message}</span
                    >
                  {/if}
                  {#if importState === "completed"}
                    <span class="text-muted">
                      {formatCount(activeImport?.imported_count)} imported, {formatCount(
                        activeImport?.skipped_count,
                      )} skipped
                    </span>
                  {/if}
                </div>
              {/if}
            {/snippet}
          </Form>
        {/if}
      {/if}
    </Deferred>
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
        <Form
          method="post"
          action={paths.create_deletion_path}
          class="m-0"
          onBefore={() =>
            window.confirm(
              "Submit account deletion request? This action starts the deletion process.",
            )}
        >
          <Button type="submit" variant="surface" class="rounded-md">
            Request deletion
          </Button>
        </Form>
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
