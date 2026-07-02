<script lang="ts">
  interface Props {
    label: string;
    sublabel?: string;
    onclick: () => void;
  }

  let { label, sublabel, onclick }: Props = $props();
</script>

<button
  type="button"
  {onclick}
  class="flex min-h-32 flex-col items-center justify-center gap-2 rounded-2xl border border-surface-300 bg-surface-100 p-6 transition-[transform,background-color,border-color] duration-200 ease-[cubic-bezier(0.34,1.56,0.64,1)] hover:border-surface-300 hover:bg-surface-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:scale-[0.97] motion-reduce:transition-none motion-reduce:active:scale-100 sm:min-h-36"
>
  <span class="text-xl font-semibold text-balance sm:text-2xl">{label}</span>
  {#if sublabel}
    <span class="max-w-[24ch] text-sm text-balance text-secondary"
      >{sublabel}</span
    >
  {/if}
</button>
