<script module lang="ts">
  import settingsLayout from "./layout";
  export const layout = settingsLayout;
</script>

<script lang="ts">
  import DataExportCard from "./components/DataExportCard.svelte";
  import ImportsCard from "./components/ImportsCard.svelte";
  import type { DataExport, HeartbeatImportStatus } from "./importsExports";

  type Props = {
    data_export?: DataExport;
    export_cooldown_minutes: number;
    remote_import_cooldown_until?: string | null;
    latest_heartbeat_import?: HeartbeatImportStatus | null;
    show_dev_import: boolean;
  };

  let {
    data_export,
    export_cooldown_minutes,
    remote_import_cooldown_until,
    latest_heartbeat_import,
    show_dev_import,
  }: Props = $props();
</script>

<svelte:head>
  <title>Imports & Exports - Hackatime Settings</title>
</svelte:head>

<ImportsCard
  latestImport={latest_heartbeat_import}
  remoteCooldownUntil={remote_import_cooldown_until}
  showDevImport={show_dev_import}
/>

<DataExportCard
  dataExport={data_export}
  exportCooldownMinutes={export_cooldown_minutes}
/>
