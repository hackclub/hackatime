<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    icon?: string;
    iconAlt?: string;
    title: string;
    subtitle?: string;
    children: Snippet;
  }

  let { icon, iconAlt, title, subtitle, children }: Props = $props();
</script>

<div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
  <div class="flex items-center gap-4 mb-6">
    {#if icon}
      <img src={icon} alt={iconAlt ?? title} class="w-12 h-12 object-contain" />
    {/if}
    <div>
      <h3 class="text-xl font-semibold">{title}</h3>
      {#if subtitle}<p class="text-secondary text-sm">{subtitle}</p>{/if}
    </div>
  </div>
  {@render children()}
</div>
