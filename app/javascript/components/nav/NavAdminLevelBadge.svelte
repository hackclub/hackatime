<script lang="ts">
  type AdminLevel = "superadmin" | "admin" | "viewer" | "default";

  let { level }: { level: AdminLevel | null | undefined } = $props();

  const levelConfig: Record<string, { label: string; className: string }> = {
    superadmin: {
      label: "Superadmin",
      className: "text-red-500 font-semibold px-2 superadmin-tool",
    },
    admin: {
      label: "Admin",
      className: "text-yellow-500 font-semibold px-2 admin-tool",
    },
    viewer: {
      label: "Viewer",
      className: "text-blue-500 font-semibold px-2 viewer-tool",
    },
  };
</script>

{#if level && levelConfig[level]}
  <span class={levelConfig[level].className}>{levelConfig[level].label}</span>
{/if}
