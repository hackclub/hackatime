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
  class="flex min-h-32 flex-col items-center justify-center gap-2 rounded-2xl border-2 border-primary bg-primary/5 p-6 shadow-lg shadow-primary/10 transition-[transform,background-color] duration-200 ease-[cubic-bezier(0.34,1.56,0.64,1)] hover:-translate-y-1 hover:bg-primary/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:translate-y-0 active:scale-[0.97] motion-reduce:transition-none motion-reduce:hover:translate-y-0 motion-reduce:active:scale-100 sm:min-h-36 cursor-pointer"
>
  <span class="text-xl font-bold text-balance sm:text-2xl">{label}</span>
  {#if sublabel}
    <span class="max-w-[24ch] text-sm text-balance text-secondary"
      >{sublabel}</span
    >
  {/if}
</button>
