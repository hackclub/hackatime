<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import type { Snippet } from "svelte";

  let {
    backHref,
    backLabel,
    projectName,
    subtitle,
    actions,
  }: {
    backHref: string;
    backLabel: string;
    projectName: string;
    subtitle?: string | null;
    actions?: Snippet;
  } = $props();
</script>

<div class="mb-6 flex flex-wrap items-start justify-between gap-4">
  <div>
    <Link
      href={backHref}
      class="text-sm text-muted transition-colors hover:text-primary"
    >
      {backLabel}
    </Link>
    <h1 class="mt-1 text-3xl font-bold text-surface-content">
      {projectName}
    </h1>
    {#if subtitle}
      <p class="mt-1 text-sm text-muted">{subtitle}</p>
    {/if}
  </div>
  {#if actions}
    <div class="flex items-center gap-2">
      {@render actions()}
    </div>
  {/if}
</div>
