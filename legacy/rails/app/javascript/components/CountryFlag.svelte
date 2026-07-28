<script lang="ts">
  import Twemoji from "./Twemoji.svelte";

  let {
    countryCode,
    countryName = null,
    class: className = "inline-block w-5 h-5 align-middle",
  }: {
    countryCode?: string | null;
    countryName?: string | null;
    class?: string;
  } = $props();

  const countryToFlagEmoji = (code?: string | null) => {
    if (!code) return null;

    const normalizedCode = code.trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(normalizedCode)) return null;

    return normalizedCode
      .split("")
      .map((char) =>
        String.fromCodePoint(0x1f1e6 + char.charCodeAt(0) - "A".charCodeAt(0)),
      )
      .join("");
  };

  const flagEmoji = $derived(countryToFlagEmoji(countryCode));
  const title = $derived(countryName || countryCode || "Country flag");
  const alt = $derived(`${countryCode || ""} flag`.trim());
</script>

{#if flagEmoji}
  <Twemoji emoji={flagEmoji} {title} {alt} class={className} />
{/if}
