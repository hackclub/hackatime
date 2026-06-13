<script lang="ts">
  interface Props {
    code: string;
    whitespace?: "pre" | "pre-wrap";
  }

  let { code, whitespace = "pre-wrap" }: Props = $props();

  const wsClass = $derived(
    whitespace === "pre" ? "whitespace-pre" : "whitespace-pre-wrap break-all",
  );
</script>

<div class="bg-darker border border-darkless rounded-lg overflow-x-auto">
  <pre class="p-4 pr-20 text-sm font-mono text-cyan {wsClass}"><code
      >{code}</code
    ></pre>
</div>
