<script lang="ts">
  import { Form, usePoll } from "@inertiajs/svelte";
  import Button from "../../../../components/Button.svelte";
  import { myHeartbeatImports } from "../../../../api";
  import type { HeartbeatImportStatus } from "../importsExports";
  import ImportStatusRow from "./ImportStatusRow.svelte";
  import SectionCard from "./SectionCard.svelte";

  type Props = {
    latestImport?: HeartbeatImportStatus | null;
    remoteCooldownUntil?: string | null;
    showDevImport: boolean;
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

  const IN_PROGRESS_STATES = [
    "queued",
    "requesting_dump",
    "waiting_for_dump",
    "downloading_dump",
    "importing",
  ];
  const REMOTE_SOURCE_KINDS = [
    "wakatime_dump",
    "wakatime_download_link",
    "hackatime_v1_dump",
  ];

  let { latestImport, remoteCooldownUntil, showDevImport }: Props = $props();

  let remoteProvider =
    $state<(typeof PROVIDERS)[number]["value"]>("wakatime_dump");
  let remoteApiKey = $state("");
  let clock = $state(Date.now());

  const importState = $derived(latestImport?.state ?? "idle");
  const importSourceKind = $derived(latestImport?.source_kind ?? "");
  const importInProgress = $derived(IN_PROGRESS_STATES.includes(importState));
  const latestImportIsRemote = $derived(
    REMOTE_SOURCE_KINDS.includes(importSourceKind),
  );
  const latestImportIsDev = $derived(importSourceKind === "dev_upload");
  const effectiveCooldownUntil = $derived(
    latestImport?.cooldown_until ?? remoteCooldownUntil ?? null,
  );
  const cooldownAt = $derived(
    effectiveCooldownUntil ? new Date(effectiveCooldownUntil).getTime() : null,
  );
  const cooldownActive = $derived(cooldownAt != null && cooldownAt > clock);
  const cooldownLabel = $derived.by(() => {
    if (cooldownAt == null) return "";
    const seconds = Math.max(0, Math.ceil((cooldownAt - clock) / 1000));
    if (seconds === 0) return "now";
    return seconds < 60 ? `${seconds}s` : `${Math.ceil(seconds / 60)}m`;
  });
  const completedSummary = $derived(
    importState === "completed"
      ? `${formatCount(latestImport?.imported_count)} imported, ${formatCount(latestImport?.skipped_count)} skipped`
      : null,
  );

  const { start: startPolling, stop: stopPolling } = usePoll(
    1000,
    { only: ["latest_heartbeat_import", "remote_import_cooldown_until"] },
    { autoStart: false },
  );

  $effect(() => {
    if (importInProgress) startPolling();
    else stopPolling();
  });

  $effect(() => {
    if (cooldownAt == null || cooldownAt <= clock) return;
    const timer = setTimeout(
      () => (clock = Date.now()),
      Math.min(1000, cooldownAt - clock),
    );
    return () => clearTimeout(timer);
  });

  function formatCount(value: number | null | undefined) {
    return value == null ? "—" : value.toLocaleString();
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
</script>

<Form
  method="post"
  action={myHeartbeatImports.create.path()}
  resetOnSuccess={["heartbeat_import[api_key]"]}
  options={{ preserveScroll: true }}
  onSuccess={() => (remoteApiKey = "")}
>
  {#snippet children({ processing, errors })}
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
            name="heartbeat_import[api_key]"
            type="password"
            bind:value={remoteApiKey}
            class="w-full rounded-md border border-surface-200 bg-input px-3 py-2 text-base text-surface-content focus:border-primary focus:outline-none"
            disabled={importInProgress || processing}
          />
        </div>

        {#if errors.import}
          <p class="text-sm text-red-300">{errors.import}</p>
        {/if}

        {#if importState !== "idle" && latestImportIsRemote}
          <ImportStatusRow
            label={providerLabel(importSourceKind)}
            state={importState}
            inProgress={importInProgress}
            errorMessage={latestImport?.error_message}
            {completedSummary}
          />
        {/if}
      </div>

      {#snippet footer()}
        <div
          class="flex flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:justify-between"
        >
          {#if cooldownActive}
            <p class="text-sm text-muted sm:mr-auto">
              Available again in {cooldownLabel}
            </p>
          {:else}
            <div></div>
          {/if}
          <div class="w-full sm:w-auto">
            <Button
              type="submit"
              variant="primary"
              class="w-full"
              disabled={cooldownActive ||
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

{#if showDevImport}
  <SectionCard
    id="development_import"
    title="Development Import"
    description="Upload a heartbeat JSON file when testing imports locally."
    wide
  >
    <Form
      method="post"
      action={myHeartbeatImports.create.path()}
      resetOnSuccess={["heartbeat_file"]}
      options={{ preserveScroll: true }}
    >
      {#snippet children({ processing, errors })}
        <label
          class="mb-2 block text-sm text-surface-content"
          for="heartbeat_file"
        >
          Heartbeat JSON file
        </label>
        <input
          id="heartbeat_file"
          name="heartbeat_file"
          type="file"
          accept=".json,application/json"
          required
          disabled={importInProgress || processing}
          class="w-full rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content disabled:cursor-not-allowed disabled:opacity-60"
        />

        {#if errors.import}
          <p class="mt-2 text-sm text-red-300">{errors.import}</p>
        {/if}

        <Button
          type="submit"
          variant="surface"
          class="mt-3 rounded-md"
          disabled={importInProgress || processing}
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
              label={latestImport?.source_filename ||
                providerLabel(importSourceKind)}
              state={importState}
              inProgress={importInProgress}
              errorMessage={latestImport?.error_message}
              {completedSummary}
              bgClass="bg-surface"
            />
          </div>
        {/if}
      {/snippet}
    </Form>
  </SectionCard>
{/if}
