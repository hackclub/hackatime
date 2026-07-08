<script lang="ts">
  interface Props {
    code: string;
  }

  let { code }: Props = $props();

  let copied = $state(false);
  let timer: ReturnType<typeof setTimeout>;

  async function copy() {
    await navigator.clipboard.writeText(code);
    copied = true;
    clearTimeout(timer);
    timer = setTimeout(() => (copied = false), 2000);
  }
</script>

<div class="relative rounded-xl border border-surface-300 bg-dark text-left">
  <pre
    class="overflow-x-auto p-4 pr-24 font-mono text-sm break-all whitespace-pre-wrap text-cyan"><code
      >{code}</code
    ></pre>
  <button
    type="button"
    onclick={copy}
    class="absolute top-3 right-3 rounded-lg border border-darkless bg-dark px-3 py-1.5 text-sm font-medium text-secondary hover:text-surface-content"
  >
    {copied ? "Copied!" : "Copy"}
  </button>
</div>
