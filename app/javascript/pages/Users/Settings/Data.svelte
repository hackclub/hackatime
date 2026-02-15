<script lang="ts">
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { DataPageProps } from "./types";

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
    errors,
    admin_tools,
  }: DataPageProps = $props();

  let csrfToken = $state("");

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";
  });
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
      <h2 class="text-xl font-semibold text-surface-content">Migration Assistant</h2>
      <p class="mt-1 text-sm text-muted">
        Queue migration of heartbeats and API keys from legacy Hackatime.
      </p>
      <form method="post" action={paths.migrate_heartbeats_path} class="mt-4">
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <Button
          type="submit"
          variant="primary"
        >
          Start migration
        </Button>
      </form>

      {#if migration.jobs.length > 0}
        <div class="mt-4 space-y-2">
          {#each migration.jobs as job}
            <div class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content">
              Job {job.id}: {job.status}
            </div>
          {/each}
        </div>
      {/if}
    </section>

    <section id="download_user_data">
      <h2 class="text-xl font-semibold text-surface-content">Download Data</h2>

      {#if data_export.is_restricted}
        <p class="mt-3 rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-red">
          Data export is currently restricted for this account.
        </p>
      {:else}
        <p class="mt-1 text-sm text-muted">
          Download your coding history as JSON for backups or analysis.
        </p>

        <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
            <p class="text-xs uppercase tracking-wide text-muted">Total heartbeats</p>
            <p class="mt-1 text-lg font-semibold text-surface-content">
              {data_export.total_heartbeats}
            </p>
          </div>
          <div class="rounded-md border border-surface-200 bg-darker px-3 py-3">
            <p class="text-xs uppercase tracking-wide text-muted">Total coding time</p>
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

        <div class="mt-4 space-y-3">
          <Button
            href={paths.export_all_heartbeats_path}
            variant="primary"
          >
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
            <Button
              type="submit"
              variant="surface"
            >
              Export date range
            </Button>
          </form>
        </div>

        {#if ui.show_dev_import}
          <form
            method="post"
            action={paths.import_heartbeats_path}
            enctype="multipart/form-data"
            class="mt-4 rounded-md border border-surface-200 bg-darker p-4"
          >
            <input type="hidden" name="authenticity_token" value={csrfToken} />
            <label class="mb-2 block text-sm text-surface-content" for="heartbeat_file">
              Import heartbeats (development only)
            </label>
            <input
              id="heartbeat_file"
              type="file"
              name="heartbeat_file"
              accept=".json,application/json"
              required
              class="w-full rounded-md border border-surface-200 bg-surface px-3 py-2 text-sm text-surface-content"
            />
            <Button
              type="submit"
              variant="surface"
              class="mt-3"
            >
              Import file
            </Button>
          </form>
        {/if}
      {/if}
    </section>

    <section id="delete_account">
      <h2 class="text-xl font-semibold text-surface-content">Account Deletion</h2>
      {#if user.can_request_deletion}
        <p class="mt-1 text-sm text-muted">
          Request permanent deletion. The account enters a waiting period
          before final removal.
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
          <Button
            type="submit"
            variant="surface"
          >
            Request deletion
          </Button>
        </form>
      {:else}
        <p class="mt-3 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
          Deletion request is unavailable for this account right now.
        </p>
      {/if}
    </section>
  </div>
</SettingsShell>
